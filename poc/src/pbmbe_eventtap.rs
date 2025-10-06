// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use core_foundation::base::{kCFAllocatorDefault, CFRelease};
use core_foundation::runloop::kCFRunLoopDefaultMode;
use core_foundation_sys::base::CFTypeRef;
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;

use crate::pbmbk_keymap::*;
use crate::pbgk_keylog::{KEY_LOGGING_ENABLED, update_key_state};
use crate::pbmsm_mru::{get_mru_snapshot, update_mru_with_focus};
use crate::pbmsa_alttab::{
    ALT_TAB_SESSION,
    show_alt_tab_overlay, update_alt_tab_highlight,
    hide_alt_tab_overlay_and_cleanup, defer_alt_tab_commit,
};
use crate::pbmcl_clipboard::{
    CLIPBOARD_SESSION, start_clipboard_monitoring,
    show_clipboard_overlay, handle_clipboard_navigation,
};
use crate::pbmbo_observer::{setup_mru_observer, setup_workspace_observer};
use crate::pbmsb_browser::is_chromium_based;
use crate::pbmp_pane::{
    TilingJob, tile_window_quadrant,
    move_window_to_prev_display, move_window_to_next_display,
    get_next_combo_for_key, reset_all_sequence_indices,
};
use crate::pbmbd_display::{note_if_multi_display};
use crate::pbmba_ax::{
    ax_trusted_or_die, get_frontmost_app_info,
    CFRunLoopGetCurrent, CFRunLoopRun, CFRunLoopAddSource,
    CGEventTapCreate, CGEventTapEnable, CGEventGetIntegerValueField,
    CGEventGetFlags, CGEventSetFlags, CGEventCreateKeyboardEvent, CGEventPost,
    CFMachPortCreateRunLoopSource,
};

// Global state for unknown keycode warning
static WARNED_UNKNOWN_ONCE: AtomicBool = AtomicBool::new(false);

extern "C" fn tap_cb(_proxy: *mut c_void, event_type: u32, event: *mut c_void, _user: *mut c_void) -> *mut c_void {
    unsafe {
        // Get modifier flags and keycode early (needed for both logging and chord detection)
        let flags = CGEventGetFlags(event);
        let keycode = CGEventGetIntegerValueField(event, K_CG_KEYCODE_FIELD_KEYCODE) as u16;

        // Debug: log ALL keyup and flags changed events (disabled - too noisy)
        // if event_type == K_CG_EVENT_KEY_UP {
        //     eprintln!("DEBUG: [tap_cb] keyup event_type={} keycode={} flags=0x{:08x}",
        //              event_type, keycode, flags);
        // }
        // if event_type == K_CG_EVENT_FLAGS_CHANGED {
        //     eprintln!("DEBUG: [tap_cb] flags_changed event_type={} keycode={} flags=0x{:08x}",
        //              event_type, keycode, flags);
        // }

        // Optional key logging (for diagnostic visibility)
        if KEY_LOGGING_ENABLED.load(Ordering::Acquire) {
            // Track both keydown and keyup for complete state visibility
            if event_type == K_CG_EVENT_KEY_DOWN || event_type == K_CG_EVENT_KEY_UP {
                // Convert virtual keycode to HID usage code
                if let Some(usage) = vk_to_hid_usage(keycode) {
                    let is_pressed = event_type == K_CG_EVENT_KEY_DOWN;
                    update_key_state(usage, is_pressed);
                }
            }
        }

        // Extract modifier flags early (needed by multiple sections)
        let has_ctrl = (flags & K_CG_EVENT_FLAG_MASK_CONTROL) != 0;
        let has_shift = (flags & K_CG_EVENT_FLAG_MASK_SHIFT) != 0;
        let has_cmd = (flags & K_CG_EVENT_FLAG_MASK_COMMAND) != 0;
        let has_opt = (flags & K_CG_EVENT_FLAG_MASK_ALTERNATE) != 0;

        // ===== CLIPBOARD: Ctrl chord forwarding & Ctrl+Shift+V =====
        // Handle clipboard overlay navigation if active
        {
            let session = CLIPBOARD_SESSION.lock().unwrap();
            if session.active {
                drop(session);
                // If clipboard overlay is active, handle navigation keys
                if event_type == K_CG_EVENT_KEY_DOWN {
                    handle_clipboard_navigation(keycode);
                    return std::ptr::null_mut(); // Block all keys during clipboard session
                }
                return event; // Pass through other events during session
            }
        }

        // Ctrl+Shift+V: Show clipboard history overlay
        if event_type == K_CG_EVENT_KEY_DOWN && has_ctrl && has_shift && !has_cmd && !has_opt && keycode == VK_V {
            show_clipboard_overlay();
            return std::ptr::null_mut(); // Block the event
        }

        // Ctrl+C/X/V (without Shift): Mirror to Cmd+C/X/V (duplicate, don't block)
        if event_type == K_CG_EVENT_KEY_DOWN && has_ctrl && !has_shift && !has_cmd && !has_opt {
            if keycode == VK_C || keycode == VK_X || keycode == VK_V {
                // Create synthetic Cmd+C/X/V event
                let synth_event = CGEventCreateKeyboardEvent(std::ptr::null_mut(), keycode, true);
                // Set Command flag on synthetic event
                CGEventSetFlags(synth_event, K_CG_EVENT_FLAG_MASK_COMMAND);
                CGEventPost(K_CG_SESSION_EVENT_TAP, synth_event);
                CFRelease(synth_event as CFTypeRef);

                // Debug logging
                let key_name = match keycode {
                    VK_C => "c",
                    VK_X => "x",
                    VK_V => "v",
                    _ => "?",
                };
                eprintln!("CLIP: mirror issued cmd+{}", key_name);

                // Let original Ctrl event pass through
                return event;
            }
        }

        // Also mirror Ctrl+C/X/V keyup events
        if event_type == K_CG_EVENT_KEY_UP && has_ctrl && !has_cmd && !has_opt {
            if keycode == VK_C || keycode == VK_X || keycode == VK_V {
                let synth_event = CGEventCreateKeyboardEvent(std::ptr::null_mut(), keycode, false);
                CGEventSetFlags(synth_event, K_CG_EVENT_FLAG_MASK_COMMAND);
                CGEventPost(K_CG_SESSION_EVENT_TAP, synth_event);
                CFRelease(synth_event as CFTypeRef);

                // Let original Ctrl keyup pass through
                return event;
            }
        }

        // ===== COMMAND+TAB: Alt-Tab Session Management =====
        // Must come BEFORE early return for non-keydown events

        // Check for Command key state changes and Tab navigation
        let snapshot = get_mru_snapshot();
        let mru_count = snapshot.len();

        // Check for Command release via flags changed or keyup events
        if event_type == K_CG_EVENT_FLAGS_CHANGED || event_type == K_CG_EVENT_KEY_UP {
            let session_active = {
                let session = ALT_TAB_SESSION.lock().unwrap();
                // eprintln!("DEBUG: [ALT_TAB] session check: active={}", session.active);
                session.active
            };

            if session_active {
                eprintln!("DEBUG: [ALT_TAB] checking flags: event_type={} keycode={} has_cmd={} has_shift={}",
                         event_type, keycode, has_cmd, has_shift);

                // If Command is no longer held, commit switch and cleanup
                if !has_cmd {
                    eprintln!("DEBUG: [ALT_TAB] Command released (detected via flags)");

                    // Defensive bounds check: verify MRU snapshot is non-empty
                    if snapshot.is_empty() {
                        eprintln!("ALT_TAB: switch | SKIPPED reason=empty_mru");
                        hide_alt_tab_overlay_and_cleanup();
                        return event;
                    }

                    // Get the currently highlighted entry to switch to
                    let target_entry = {
                        let session = ALT_TAB_SESSION.lock().unwrap();
                        if let Some(idx) = session.highlight_index {
                            if idx < snapshot.len() {
                                Some(snapshot[idx].clone())
                            } else {
                                // Bounds check failed - highlight_index exceeds array
                                eprintln!("ALT_TAB: switch | SKIPPED reason=index_out_of_bounds idx={} len={}", idx, snapshot.len());
                                None
                            }
                        } else {
                            // No highlight set - should not happen in normal flow
                            eprintln!("ALT_TAB: switch | SKIPPED reason=no_highlight_index");
                            None
                        }
                    };

                    // Attempt to switch focus if we have a valid target
                    // Defer to main runloop for thread safety (AX APIs must be on main thread)
                    if let Some(entry) = target_entry {
                        defer_alt_tab_commit(entry);
                    }

                    // Always cleanup overlays and session state
                    hide_alt_tab_overlay_and_cleanup();
                    return event; // Don't block flags changed events
                }
            }
        }

        // Block Tab keyup during active session
        if event_type == K_CG_EVENT_KEY_UP && keycode == 48 {
            let session_active = {
                let session = ALT_TAB_SESSION.lock().unwrap();
                session.active
            };

            if session_active {
                // Block Tab keyup during session
                return std::ptr::null_mut();
            }
            return event;
        }

        // Check for Tab key (48) while Command is held (only on keydown)
        if event_type == K_CG_EVENT_KEY_DOWN && keycode == 48 && has_cmd && !has_opt && !has_ctrl {
            // Ignore auto-repeat to prevent uncontrolled cycling
            let is_repeat = CGEventGetIntegerValueField(event, K_CG_KEYBOARD_EVENT_AUTOREPEAT) != 0;
            if is_repeat {
                eprintln!("DEBUG: [ALT_TAB] Ignoring Tab auto-repeat");
                return std::ptr::null_mut(); // Discard auto-repeat event
            }

            let mut session = ALT_TAB_SESSION.lock().unwrap();

            // Start session on first Tab press
            if !session.active {
                session.active = true;
                println!("ALT_TAB: session start");
            }

            if mru_count == 0 {
                // No windows to show - reset session state
                session.active = false;
                session.popup_shown = false;
                session.highlight_index = None;
                drop(session);
                eprintln!("ALT_TAB: no windows available");
                println!("BLOCKED: cmd+tab (no windows)");
                return std::ptr::null_mut();
            }

            if !session.popup_shown {
                // First Tab press - immediately advance to next MRU entry
                // Forward (Tab): start at index 1 (skip current window at index 0)
                // Backward (Shift+Tab): start at last index (wrap around)
                session.popup_shown = true;
                let initial_idx = if has_shift {
                    // Shift+Tab: go to last entry
                    mru_count - 1
                } else {
                    // Tab: skip current window (index 0), go to index 1
                    // Handle edge case: if only 1 window, stay at 0
                    if mru_count > 1 { 1 } else { 0 }
                };
                session.highlight_index = Some(initial_idx);
                drop(session); // Release lock before calling FFI

                show_alt_tab_overlay(initial_idx);

                let entry = &snapshot[initial_idx];
                if has_shift {
                    println!("ALT_TAB: backward step -> index={} app={} win=\"{}\"",
                             initial_idx, entry.bundle_id, entry.title);
                    println!("BLOCKED: cmd+shift+tab");
                } else {
                    println!("ALT_TAB: forward step -> index={} app={} win=\"{}\"",
                             initial_idx, entry.bundle_id, entry.title);
                    println!("BLOCKED: cmd+tab");
                }
                return std::ptr::null_mut();
            }

            // Navigate forward or backward based on Shift
            let current_idx = session.highlight_index.unwrap_or(0);
            let new_idx = if has_shift {
                // Shift+Tab = backward
                if current_idx == 0 {
                    mru_count - 1 // Wrap to end
                } else {
                    current_idx - 1
                }
            } else {
                // Tab = forward
                (current_idx + 1) % mru_count
            };

            session.highlight_index = Some(new_idx);
            drop(session); // Release lock before calling FFI

            update_alt_tab_highlight(new_idx);

            let entry = &snapshot[new_idx];
            if has_shift {
                println!("ALT_TAB: backward step -> index={} app={} win=\"{}\"",
                         new_idx, entry.bundle_id, entry.title);
                println!("BLOCKED: cmd+shift+tab");
            } else {
                println!("ALT_TAB: forward step -> index={} app={} win=\"{}\"",
                         new_idx, entry.bundle_id, entry.title);
                println!("BLOCKED: cmd+tab");
            }

            return std::ptr::null_mut(); // Block the event
        }

        // ===== CTRL+SHIFT Release: Reset Layout Sequence Indices =====
        // Track when Ctrl+Shift chord is released to reset all sequence indices per spec
        static CTRL_SHIFT_WAS_HELD: AtomicBool = AtomicBool::new(false);

        if event_type == K_CG_EVENT_FLAGS_CHANGED {
            let ctrl_shift_held = has_ctrl && has_shift;
            let was_held = CTRL_SHIFT_WAS_HELD.load(Ordering::Acquire);

            if was_held && !ctrl_shift_held {
                // Ctrl+Shift released - reset all sequence indices
                reset_all_sequence_indices();
            }

            CTRL_SHIFT_WAS_HELD.store(ctrl_shift_held, Ordering::Release);
        }

        // Early exit for non-keydown events (chord interception only acts on keydown)
        // This check comes AFTER Alt-Tab handling since we need to track Alt keyup/flags_changed for session cleanup
        if event_type != K_CG_EVENT_KEY_DOWN { return event; }

        // Ignore autorepeat
        let is_repeat = CGEventGetIntegerValueField(event, K_CG_KEYBOARD_EVENT_AUTOREPEAT) != 0;
        if is_repeat { return event; }

        // ===== CTRL+SHIFT: Quadrant Tiling =====
        // Require ctrl+shift held, reject cmd/opt to prevent ambiguity with app shortcuts
        let need = K_CG_EVENT_FLAG_MASK_CONTROL | K_CG_EVENT_FLAG_MASK_SHIFT;
        let reject = K_CG_EVENT_FLAG_MASK_COMMAND | K_CG_EVENT_FLAG_MASK_ALTERNATE;

        // Debug logging for modifier flags
        if has_ctrl || has_shift {
            eprintln!("DEBUG: flags=0x{:08x}, ctrl={}, shift={}, cmd={}, opt={}, need=0x{:08x}", flags, has_ctrl, has_shift, has_cmd, has_opt, need);
        }

        if (flags & need) != need { return event; }
        if (flags & reject) != 0 { return event; }

        // Always log ctrl+shift keypresses to help diagnose keycode issues
        eprintln!("DEBUG: ctrl+shift+keycode=0x{:02x}", keycode);

        // Check for unknown keycode warning
        if !known_poc_key(keycode) && !WARNED_UNKNOWN_ONCE.swap(true, Ordering::AcqRel) {
            eprintln!("NOTE: ctrl+shift on unrecognized keycode=0x{:02x}. On some PC keyboards, Insert may not map to 0x72.", keycode);
            return event;
        }

        // Handle PageUp/PageDown for display moves
        if keycode == KVK_PAGE_UP || keycode == KVK_PAGE_DOWN {
            let key_name = if keycode == KVK_PAGE_UP { "PageUp" } else { "PageDown" };

            // Capture frontmost app info at chord time
            if let Some(frontmost) = get_frontmost_app_info() {
                let chromium_tag = if is_chromium_based(&frontmost.bundle_id) { " [chromium]" } else { "" };
                eprintln!("DEBUG: Frontmost at tap: {} (pid={}){}",
                         frontmost.bundle_id, frontmost.pid, chromium_tag);

                // Consume the chord
                println!("BLOCKED: ctrl+shift+{}", key_name);

                // Execute display move directly (no deferred job needed for simple moves)
                if keycode == KVK_PAGE_UP {
                    move_window_to_prev_display(frontmost.pid, &frontmost.bundle_id);
                } else {
                    move_window_to_next_display(frontmost.pid, &frontmost.bundle_id);
                }

                std::ptr::null_mut() // <- swallow the event
            } else {
                eprintln!("DEBUG: Failed to get frontmost app info, ignoring chord");
                event
            }
        } else if let Some(q) = chord_to_quad(keycode) {
            let key_name = match keycode {
                KVK_HELP_INSERT => "Insert",
                KVK_FWD_DELETE => "Delete",
                KVK_HOME => "Home",
                KVK_END => "End",
                _ => "Unknown",
            };

            // Capture frontmost app info at chord time
            if let Some(frontmost) = get_frontmost_app_info() {
                let chromium_tag = if is_chromium_based(&frontmost.bundle_id) { " [chromium]" } else { "" };
                eprintln!("DEBUG: Frontmost at tap: {} (pid={}){}",
                         frontmost.bundle_id, frontmost.pid, chromium_tag);

                // Update MRU with this window
                update_mru_with_focus(frontmost.pid, frontmost.bundle_id.clone());

                // Look up layout sequence and get next combo
                let (custom_combo, combo_index) = match get_next_combo_for_key(key_name) {
                    Some((combo, index)) => {
                        eprintln!("DEBUG: [LAYOUT] Using combo {} for key {}", index, key_name);
                        (Some(combo), Some(index))
                    }
                    None => {
                        eprintln!("DEBUG: [LAYOUT] No sequence found for key {}, using default quad", key_name);
                        (None, None)
                    }
                };

                // Consume the chord and enqueue the tiling job for main runloop processing
                let log_msg = if let Some(idx) = combo_index {
                    format!("ctrl+shift+{} (combo={})", key_name, idx)
                } else {
                    format!("ctrl+shift+{}", key_name)
                };
                println!("BLOCKED: {}", log_msg);

                // Create tiling job with frontmost context and layout info
                let job = TilingJob {
                    quad: q,
                    frontmost,
                    attempt: 0, // First attempt
                    start_time: Some(Instant::now()),
                    key_name: Some(key_name.to_string()),
                    combo_index,
                    custom_combo,
                };

                // Defer job to main runloop instead of doing AX work here (Chrome compatibility)
                tile_window_quadrant(job);

                std::ptr::null_mut() // <- swallow the event
            } else {
                eprintln!("DEBUG: Failed to get frontmost app info, ignoring chord");
                event
            }
        } else {
            event
        }
    }
}

pub unsafe fn run_quadrant_poc() -> ! {
    // Check AX permissions first
    ax_trusted_or_die();

    // Check for key logging toggle (environment variable)
    // Set PANEBOARD_LOG_KEYS=1 to enable diagnostic key logging
    let logging_enabled = if let Ok(val) = std::env::var("PANEBOARD_LOG_KEYS") {
        if val == "1" || val.to_lowercase() == "true" {
            KEY_LOGGING_ENABLED.store(true, Ordering::Release);
            eprintln!("DEBUG: Key logging enabled (PANEBOARD_LOG_KEYS={})", val);
            true
        } else {
            false
        }
    } else {
        false
    };

    eprintln!("PaneBoard Quadrant Tiling + Alt-Tab MRU + Clipboard Memory PoC");
    eprintln!("Ctrl+Shift+Insert/Delete/Home/End to tile focused window");
    eprintln!("Command+Tab to show MRU window list");
    eprintln!("Ctrl+C/X/V for copy/cut/paste, Ctrl+Shift+V for clipboard history");

    // Multi-display notice right after banner (before setup chatter)
    note_if_multi_display();

    // Setup MRU tracking
    eprintln!("DEBUG: Initializing MRU tracker...");
    if let Err(e) = setup_mru_observer() {
        eprintln!("WARNING: MRU observer setup failed: {}", e);
    }

    // Setup NSWorkspace observer for app activation
    setup_workspace_observer();

    // Setup clipboard monitoring
    start_clipboard_monitoring();

    // Print key logging header if enabled
    if logging_enabled {
        println!();
        println!("LSH RSH LCT RCT LAL RAL LME RME || Keys:");
    }

    eprintln!("Ctrl-C to quit...");

    // Create event tap with tighter unsafe scopes
    let tap = CGEventTapCreate(
        K_CG_SESSION_EVENT_TAP,
        K_CG_HEAD_INSERT_EVENT_TAP,
        K_CG_EVENT_TAP_OPTION_DEFAULT,
        CG_EVENT_MASK_KEYBOARD,
        tap_cb,
        std::ptr::null_mut(),
    );
    if tap.is_null() {
        eprintln!("CGEventTap: FAILED to create");
        std::process::exit(1);
    }

    CGEventTapEnable(tap, true);
    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopDefaultMode as *mut c_void);

    eprintln!("DEBUG: Using CFRunLoopPerformBlock for deferred AX operations (Chrome compatibility)");

    CFRunLoopRun();
    std::process::exit(0);
}