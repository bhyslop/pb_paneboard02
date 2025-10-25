// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use core_foundation::base::{kCFAllocatorDefault, CFRelease};
use core_foundation::runloop::kCFRunLoopDefaultMode;
use core_foundation_sys::base::CFTypeRef;
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::pbmbk_keymap::*;
use crate::pbgk_keylog::{KEY_LOGGING_ENABLED, update_key_state};
use crate::pbmsm_mru::{get_mru_snapshot, update_mru_with_focus};
use crate::pbmsa_alttab::{
    ALT_TAB_SESSION,
    show_alt_tab_overlay, update_alt_tab_highlight,
    hide_alt_tab_overlay_and_cleanup, defer_alt_tab_commit,
    cancel_alt_tab_session,
};
use crate::pbmcl_clipboard::{
    CLIPBOARD_SESSION, start_clipboard_monitoring,
    show_clipboard_overlay, handle_clipboard_navigation,
};
use crate::pbmbo_observer::{setup_mru_observer, setup_workspace_observer};
use crate::pbmsb_browser::is_chromium_based;
use crate::pbmp_pane::{
    TilingJob, tile_window_quadrant,
    execute_display_move_for_key,
    reset_layout_session,
};
use crate::pbmbd_display::{print_all_display_info};
use crate::pbmba_ax::{
    ax_trusted_or_die, get_frontmost_app_info,
    CFRunLoopGetCurrent, CFRunLoopRun, CFRunLoopAddSource,
    CGEventTapCreate, CGEventTapEnable, CGEventGetIntegerValueField,
    CGEventGetFlags, CGEventSetFlags, CGEventCreateKeyboardEvent, CGEventPost,
    CFMachPortCreateRunLoopSource,
};

// Global state for unknown keycode warning
static WARNED_UNKNOWN_ONCE: AtomicBool = AtomicBool::new(false);

// Global tap pointer for health check timer
static EVENT_TAP_PTR: std::sync::atomic::AtomicPtr<c_void> = std::sync::atomic::AtomicPtr::new(std::ptr::null_mut());

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

        // ===== MOUSE CLICK: Cancel Alt-Tab session if active =====
        // Check for any mouse button down event during active Alt-Tab session
        let is_mouse_down = matches!(event_type,
            K_CG_EVENT_LEFT_MOUSE_DOWN | K_CG_EVENT_RIGHT_MOUSE_DOWN | K_CG_EVENT_OTHER_MOUSE_DOWN
        );

        if is_mouse_down {
            let session_active = {
                let session = ALT_TAB_SESSION.lock().unwrap();
                session.active
            };

            if session_active {
                // Mouse click during Alt-Tab session - cancel immediately
                cancel_alt_tab_session();
                // Consume the click to prevent conflicting activation
                return std::ptr::null_mut();
            }
        }

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
                // eprintln!("SWITCHER: session check: active={}", session.active);
                session.active
            };

            if session_active {
                eprintln!("SWITCHER: checking flags: event_type={} keycode={} has_cmd={} has_shift={}",
                         event_type, keycode, has_cmd, has_shift);

                // If Command is no longer held, commit switch and cleanup
                if !has_cmd {
                    eprintln!("SWITCHER: Command released (detected via flags)");

                    // Defensive bounds check: verify MRU snapshot is non-empty
                    if snapshot.is_empty() {
                        eprintln!("SWITCHER: switch | SKIPPED reason=empty_mru");
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
                                eprintln!("SWITCHER: switch | SKIPPED reason=index_out_of_bounds idx={} len={}", idx, snapshot.len());
                                None
                            }
                        } else {
                            // No highlight set - should not happen in normal flow
                            eprintln!("SWITCHER: switch | SKIPPED reason=no_highlight_index");
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
                eprintln!("SWITCHER: Ignoring Tab auto-repeat");
                return std::ptr::null_mut(); // Discard auto-repeat event
            }

            let mut session = ALT_TAB_SESSION.lock().unwrap();

            // Start session on first Tab press
            let is_new_session = !session.active;
            if is_new_session {
                session.active = true;
                drop(session); // Release lock before calling prune (which locks MRU_STACK)

                println!("SWITCHER: session start");

                // Prune stale MRU entries at session start
                let pruned = crate::pbmsm_mru::prune_stale_mru_entries();
                if pruned > 0 {
                    println!("MRU: pruned {} stale entries (pre-session validation)", pruned);
                }

                // Re-acquire session lock
                session = ALT_TAB_SESSION.lock().unwrap();
            }

            // Get fresh snapshot after pruning (if new session)
            let (snapshot, mru_count) = if is_new_session {
                let fresh_snapshot = get_mru_snapshot();
                let fresh_count = fresh_snapshot.len();
                (fresh_snapshot, fresh_count)
            } else {
                (snapshot, mru_count)
            };

            if mru_count == 0 {
                // No windows to show - reset session state
                session.active = false;
                session.popup_shown = false;
                session.highlight_index = None;
                drop(session);
                eprintln!("SWITCHER: no windows available");
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
                    println!("SWITCHER: backward step -> index={} app={} win=\"{}\"",
                             initial_idx, entry.bundle_id, entry.title);
                    println!("BLOCKED: cmd+shift+tab");
                } else {
                    println!("SWITCHER: forward step -> index={} app={} win=\"{}\"",
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
                println!("SWITCHER: backward step -> index={} app={} win=\"{}\"",
                         new_idx, entry.bundle_id, entry.title);
                println!("BLOCKED: cmd+shift+tab");
            } else {
                println!("SWITCHER: forward step -> index={} app={} win=\"{}\"",
                         new_idx, entry.bundle_id, entry.title);
                println!("BLOCKED: cmd+tab");
            }

            return std::ptr::null_mut(); // Block the event
        }

        // ===== CTRL+SHIFT+OPTION Release: Reset Layout Sequence Indices =====
        // Track when Ctrl+Shift+Option chord is released to reset all sequence indices per spec
        static CTRL_SHIFT_OPT_WAS_HELD: AtomicBool = AtomicBool::new(false);

        if event_type == K_CG_EVENT_FLAGS_CHANGED {
            let ctrl_shift_opt_held = has_ctrl && has_shift && has_opt;
            let was_held = CTRL_SHIFT_OPT_WAS_HELD.load(Ordering::Acquire);

            if was_held && !ctrl_shift_opt_held {
                // Ctrl+Shift+Option released - reset all sequence indices
                reset_layout_session();
            }

            CTRL_SHIFT_OPT_WAS_HELD.store(ctrl_shift_opt_held, Ordering::Release);
        }

        // Early exit for non-keydown events (chord interception only acts on keydown)
        // This check comes AFTER Alt-Tab handling since we need to track Alt keyup/flags_changed for session cleanup
        if event_type != K_CG_EVENT_KEY_DOWN { return event; }

        // Ignore autorepeat
        let is_repeat = CGEventGetIntegerValueField(event, K_CG_KEYBOARD_EVENT_AUTOREPEAT) != 0;
        if is_repeat { return event; }

        // ===== CTRL+SHIFT+OPTION: Quadrant Tiling =====
        // Require ctrl+shift+option held, reject cmd to prevent ambiguity with app shortcuts
        let need = K_CG_EVENT_FLAG_MASK_CONTROL | K_CG_EVENT_FLAG_MASK_SHIFT | K_CG_EVENT_FLAG_MASK_ALTERNATE;
        let reject = K_CG_EVENT_FLAG_MASK_COMMAND;

        // Debug logging for modifier flags
        if has_ctrl || has_shift || has_opt {
            eprintln!("DEBUG: flags=0x{:08x}, ctrl={}, shift={}, cmd={}, opt={}, need=0x{:08x}", flags, has_ctrl, has_shift, has_cmd, has_opt, need);
        }

        if (flags & need) != need { return event; }
        if (flags & reject) != 0 { return event; }

        // Always log ctrl+shift+option keypresses to help diagnose keycode issues
        eprintln!("DEBUG: ctrl+shift+option+keycode=0x{:02x}", keycode);

        // Check for unknown keycode warning
        if !known_poc_key(keycode) && !WARNED_UNKNOWN_ONCE.swap(true, Ordering::AcqRel) {
            eprintln!("NOTE: ctrl+shift+option on unrecognized keycode=0x{:02x}. On some PC keyboards, Insert may not map to 0x72.", keycode);
            return event;
        }

        // Handle PageUp/PageDown for display moves (via Form configuration)
        if keycode == KVK_PAGE_UP || keycode == KVK_PAGE_DOWN {
            let key_name = if keycode == KVK_PAGE_UP { "pageup" } else { "pagedown" };

            // Capture frontmost app info at chord time
            if let Some(frontmost) = get_frontmost_app_info() {
                let chromium_tag = if is_chromium_based(&frontmost.bundle_id) { " [chromium]" } else { "" };
                eprintln!("DEBUG: Frontmost at tap: {} (pid={}){}",
                         frontmost.bundle_id, frontmost.pid, chromium_tag);

                // Consume the chord
                println!("BLOCKED: ctrl+shift+option+{}", key_name);

                // Execute display move via Form (checks configuration)
                execute_display_move_for_key(key_name, frontmost.pid, &frontmost.bundle_id);

                std::ptr::null_mut() // <- swallow the event
            } else {
                eprintln!("DEBUG: Failed to get frontmost app info, ignoring chord");
                event
            }
        } else if let Some(q) = chord_to_quad(keycode) {
            let key_name = match keycode {
                KVK_HELP_INSERT => "insert",
                KVK_FWD_DELETE => "delete",
                KVK_HOME => "home",
                KVK_END => "end",
                _ => "unknown",
            };

            // Capture frontmost app info at chord time
            if let Some(frontmost) = get_frontmost_app_info() {
                let chromium_tag = if is_chromium_based(&frontmost.bundle_id) { " [chromium]" } else { "" };
                eprintln!("DEBUG: Frontmost at tap: {} (pid={}){}",
                         frontmost.bundle_id, frontmost.pid, chromium_tag);

                // Update MRU with this window
                update_mru_with_focus(frontmost.pid, frontmost.bundle_id.clone());

                // Consume the chord and enqueue the tiling job for main runloop processing
                println!("BLOCKED: ctrl+shift+option+{}", key_name);

                // Create tiling job with frontmost context and key name
                let job = TilingJob {
                    quad: q,
                    frontmost,
                    attempt: 0, // First attempt
                    key_name: Some(key_name.to_string()),
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

// Timer callback to check event tap health and switcher state
extern "C" fn tap_health_check_timer(_timer: *mut c_void, _info: *mut c_void) {
    unsafe {
        let tap = EVENT_TAP_PTR.load(std::sync::atomic::Ordering::Acquire);
        if tap.is_null() {
            return; // Not initialized yet
        }

        // Check if the tap is still enabled
        let is_enabled = crate::pbmba_ax::CGEventTapIsEnabled(tap);

        if !is_enabled {
            // TAP WAS DISABLED BY macOS - this is abnormal!
            eprintln!("⚠️  WARNING: CGEventTap was DISABLED by macOS (likely due to slow callback)");
            eprintln!("⚠️  RECOVERY: Re-enabling event tap automatically");

            crate::pbmba_ax::CGEventTapEnable(tap, true);

            // Verify it was re-enabled
            let now_enabled = crate::pbmba_ax::CGEventTapIsEnabled(tap);
            if now_enabled {
                eprintln!("✓  SUCCESS: Event tap re-enabled");
            } else {
                eprintln!("✗  FAILED: Could not re-enable event tap - hotkeys may not work!");
            }
        }

        // Check for stuck switcher overlay (Option not held but session active)
        let session = ALT_TAB_SESSION.lock().unwrap();
        if session.active {
            // Check if Option is actually held by querying current event flags
            // We can't directly query key state here, but we can check if the session
            // has been active for an unreasonable amount of time without events
            // For now, just log if session is active (this will help diagnose stuck states)
            drop(session);

            // Note: A more robust check would query CGEventSourceKeyState for the Option key,
            // but that requires creating an event source. For this PoC, the user can press
            // Option again to recover, and the console warning helps diagnose the issue.
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
    eprintln!("Ctrl+Shift+Option+Insert/Delete/Home/End to tile focused window");
    eprintln!("Command+Tab to show MRU window list");
    eprintln!("Ctrl+C/X/V for copy/cut/paste, Ctrl+Shift+V for clipboard history");

    // Print comprehensive display information
    print_all_display_info();

    // Deploy fresh default config at startup (before lazy Form initialization)
    crate::pbgf_form::ensure_fresh_default_config();

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

    // Create event tap with tighter unsafe scopes (includes keyboard + mouse events)
    let tap = CGEventTapCreate(
        K_CG_SESSION_EVENT_TAP,
        K_CG_HEAD_INSERT_EVENT_TAP,
        K_CG_EVENT_TAP_OPTION_DEFAULT,
        CG_EVENT_MASK_ALL,
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

    // Store tap pointer for health check timer
    EVENT_TAP_PTR.store(tap, std::sync::atomic::Ordering::Release);

    // Create timer to check tap health every 500ms
    // This detects if macOS silently disables the tap and auto-recovers
    use crate::pbmba_ax::{CFAbsoluteTimeGetCurrent, CFRunLoopTimerCreate, CFRunLoopAddTimer, CFRunLoopTimerContext};

    let timer_context = CFRunLoopTimerContext {
        version: 0,
        info: std::ptr::null_mut(),
        retain: None,
        release: None,
        copy_description: None,
    };

    let now = CFAbsoluteTimeGetCurrent();
    let health_check_timer = CFRunLoopTimerCreate(
        kCFAllocatorDefault,
        now + 0.5,                    // First fire after 500ms
        0.5,                          // Repeat every 500ms
        0,                            // flags
        0,                            // order
        tap_health_check_timer,       // callback
        &timer_context as *const _,
    );

    if !health_check_timer.is_null() {
        CFRunLoopAddTimer(
            CFRunLoopGetCurrent(),
            health_check_timer,
            kCFRunLoopDefaultMode as *mut c_void,
        );
        eprintln!("DEBUG: Event tap health monitoring enabled (500ms interval)");
    } else {
        eprintln!("WARNING: Failed to create health check timer - tap auto-recovery disabled");
    }

    eprintln!("DEBUG: Using CFRunLoopPerformBlock for deferred AX operations (Chrome compatibility)");

    CFRunLoopRun();
    std::process::exit(0);
}