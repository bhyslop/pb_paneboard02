// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use std::sync::{Arc, Mutex};
use std::ffi::c_void;
use core_foundation_sys::base::CFTypeRef;
use crate::pbmsm_mru::{get_mru_snapshot, MruWindowEntry, ActivationState};
use crate::pbmba_ax::{
    AxElement, get_frontmost_app_info,
    AXUIElementCreateApplication, AXUIElementCopyAttributeValue,
    _AXUIElementGetWindow, CFArrayGetCount, CFArrayGetValueAtIndex,
    ax_attr_windows, KAX_ERROR_SUCCESS,
};
use crate::pbmp_pane::focus_window_by_id;
use core_foundation::base::{CFRelease, TCFType};
use crate::pbmbo_overlay::{
    strings_to_ffi,
    pbmbo_show_alt_tab_overlay,
    pbmbo_update_alt_tab_highlight,
    pbmbo_hide_alt_tab_overlay,
    pbmbo_show_highlight_border,
    pbmbo_hide_highlight_border,
};

// Alt-Tab session state
lazy_static::lazy_static! {
    pub static ref ALT_TAB_SESSION: Arc<Mutex<AltTabSession>> = Arc::new(Mutex::new(AltTabSession::default()));
}

#[derive(Debug, Clone)]
pub struct AltTabSession {
    pub active: bool,           // Is Alt currently held?
    pub popup_shown: bool,      // Has popup been displayed this session?
    pub highlight_index: Option<usize>,  // Current highlight position (None = not navigating)
}

impl Default for AltTabSession {
    fn default() -> Self {
        Self {
            active: false,
            popup_shown: false,
            highlight_index: None,
        }
    }
}

/// Helper to get window rect via AX enumeration
/// Returns None if window not found or AX query fails
unsafe fn get_window_rect(pid: u32, window_id: u32) -> Option<crate::pbmbd_display::Rect> {
    // Create app element
    let app_element = AXUIElementCreateApplication(pid);
    if app_element.is_null() {
        return None;
    }

    // Query kAXWindowsAttribute
    let windows_attr = ax_attr_windows();
    let mut windows_array: CFTypeRef = std::ptr::null();
    let rc = AXUIElementCopyAttributeValue(
        app_element,
        windows_attr.as_concrete_TypeRef() as CFTypeRef,
        &mut windows_array,
    );

    if rc != KAX_ERROR_SUCCESS || windows_array.is_null() {
        CFRelease(app_element as CFTypeRef);
        return None;
    }

    // Iterate through CFArray to find target window
    let count = CFArrayGetCount(windows_array);
    let mut result = None;

    for i in 0..count {
        let window_element = CFArrayGetValueAtIndex(windows_array, i) as crate::pbmba_ax::AXUIElementRef;
        if window_element.is_null() {
            continue;
        }

        // Get window ID
        let mut wid: u32 = 0;
        let wid_rc = _AXUIElementGetWindow(window_element, &mut wid);
        if wid_rc == 0 && wid == window_id {
            // Found the window - wrap in AxElement and get rect
            let ax_win = AxElement(window_element);
            result = ax_win.get_current_rect();
            // Prevent drop from releasing the element (it's owned by the array)
            std::mem::forget(ax_win);
            break;
        }
    }

    // Cleanup
    CFRelease(windows_array);
    CFRelease(app_element as CFTypeRef);

    result
}

/// Helper to show Alt-Tab overlay with MRU entries
/// Defers to main runloop for thread safety
pub unsafe fn show_alt_tab_overlay(highlight_index: usize) {
    use std::rc::Rc;
    use block2::StackBlock;

    let snapshot = get_mru_snapshot();

    // Convert to FFI-compatible format (separate arrays) using new helper
    let bundle_ids: Vec<String> = snapshot.iter().map(|e| e.bundle_id.clone()).collect();
    let titles: Vec<String> = snapshot.iter().map(|e| e.title.clone()).collect();
    let activation_states: Vec<String> = snapshot.iter().map(|e| match e.activation_state {
        ActivationState::Known => "KNOWN".to_string(),
        ActivationState::Guess => "GUESS".to_string(),
    }).collect();

    let (c_bundle_ids, bundle_id_ptrs) = strings_to_ffi(&bundle_ids);
    let (c_titles, title_ptrs) = strings_to_ffi(&titles);
    let (c_activation_states, activation_state_ptrs) = strings_to_ffi(&activation_states);

    let count = bundle_ids.len() as i32;
    let data = Rc::new((bundle_id_ptrs, title_ptrs, activation_state_ptrs, c_bundle_ids, c_titles, c_activation_states, snapshot, highlight_index));

    // Create block that calls Swift function
    let block = StackBlock::new(move || {
        let (ref bundle_id_ptrs, ref title_ptrs, ref activation_state_ptrs, _, _, _, ref snapshot, highlight_index) = *data;
        pbmbo_show_alt_tab_overlay(
            bundle_id_ptrs.as_ptr(),
            title_ptrs.as_ptr(),
            activation_state_ptrs.as_ptr(),
            count,
            highlight_index as i32,
        );

        // Show highlight border for the selected window
        // Convert AX coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
        // so Swift NSWindow positioning is correct
        if highlight_index < snapshot.len() {
            let entry = &snapshot[highlight_index];
            if entry.identity.window_id != 0 {
                if let Some(rect) = get_window_rect(entry.identity.pid, entry.identity.window_id) {
                    let primary_h = crate::pbmbd_display::get_primary_display_height();
                    let cocoa_y = primary_h - rect.y - rect.h;
                    pbmbo_show_highlight_border(rect.x, cocoa_y, rect.w, rect.h, 1.0, 0.647, 0.0);
                } else {
                    pbmbo_hide_highlight_border();
                }
            } else {
                pbmbo_hide_highlight_border();
            }
        }
    });

    // Schedule on main runloop
    let main_runloop = crate::pbmba_ax::CFRunLoopGetMain();
    crate::pbmba_ax::CFRunLoopPerformBlock(
        main_runloop,
        core_foundation::runloop::kCFRunLoopDefaultMode as CFTypeRef,
        &*block as *const _ as *const c_void,
    );
    crate::pbmba_ax::CFRunLoopWakeUp(main_runloop);
}

/// Helper to update Alt-Tab overlay highlight
/// Defers to main runloop for thread safety
pub unsafe fn update_alt_tab_highlight(highlight_index: usize) {
    use std::rc::Rc;
    use block2::StackBlock;

    let snapshot = get_mru_snapshot();

    // Convert to FFI-compatible format (separate arrays) using new helper
    let bundle_ids: Vec<String> = snapshot.iter().map(|e| e.bundle_id.clone()).collect();
    let titles: Vec<String> = snapshot.iter().map(|e| e.title.clone()).collect();
    let activation_states: Vec<String> = snapshot.iter().map(|e| match e.activation_state {
        ActivationState::Known => "KNOWN".to_string(),
        ActivationState::Guess => "GUESS".to_string(),
    }).collect();

    let (c_bundle_ids, bundle_id_ptrs) = strings_to_ffi(&bundle_ids);
    let (c_titles, title_ptrs) = strings_to_ffi(&titles);
    let (c_activation_states, activation_state_ptrs) = strings_to_ffi(&activation_states);

    let count = bundle_ids.len() as i32;
    let data = Rc::new((bundle_id_ptrs, title_ptrs, activation_state_ptrs, c_bundle_ids, c_titles, c_activation_states, snapshot, highlight_index));

    // Create block that calls Swift function
    let block = StackBlock::new(move || {
        let (ref bundle_id_ptrs, ref title_ptrs, ref activation_state_ptrs, _, _, _, ref snapshot, highlight_index) = *data;
        pbmbo_update_alt_tab_highlight(
            bundle_id_ptrs.as_ptr(),
            title_ptrs.as_ptr(),
            activation_state_ptrs.as_ptr(),
            count,
            highlight_index as i32,
        );

        // Update highlight border for the selected window
        // Convert AX coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
        if highlight_index < snapshot.len() {
            let entry = &snapshot[highlight_index];
            if entry.identity.window_id != 0 {
                if let Some(rect) = get_window_rect(entry.identity.pid, entry.identity.window_id) {
                    let primary_h = crate::pbmbd_display::get_primary_display_height();
                    let cocoa_y = primary_h - rect.y - rect.h;
                    pbmbo_show_highlight_border(rect.x, cocoa_y, rect.w, rect.h, 1.0, 0.647, 0.0);
                } else {
                    pbmbo_hide_highlight_border();
                }
            } else {
                pbmbo_hide_highlight_border();
            }
        }
    });

    // Schedule on main runloop
    let main_runloop = crate::pbmba_ax::CFRunLoopGetMain();
    crate::pbmba_ax::CFRunLoopPerformBlock(
        main_runloop,
        core_foundation::runloop::kCFRunLoopDefaultMode as CFTypeRef,
        &*block as *const _ as *const c_void,
    );
    crate::pbmba_ax::CFRunLoopWakeUp(main_runloop);
}

/// Helper to hide Alt-Tab overlay and reset session state
/// Defers to main runloop for thread safety
pub unsafe fn hide_alt_tab_overlay_and_cleanup() {
    use block2::StackBlock;

    // Create block that calls Swift function
    let block = StackBlock::new(|| {
        pbmbo_hide_alt_tab_overlay();
        pbmbo_hide_highlight_border();
    });

    // Schedule on main runloop
    let main_runloop = crate::pbmba_ax::CFRunLoopGetMain();
    crate::pbmba_ax::CFRunLoopPerformBlock(
        main_runloop,
        core_foundation::runloop::kCFRunLoopDefaultMode as CFTypeRef,
        &*block as *const _ as *const c_void,
    );
    crate::pbmba_ax::CFRunLoopWakeUp(main_runloop);

    // Reset session state (can do this immediately)
    let mut session = ALT_TAB_SESSION.lock().unwrap();
    *session = AltTabSession::default();

    println!("SWITCHER: cleanup | overlays hidden, state reset");
}

/// Cancel Alt-Tab session without performing focus switch
/// Called when mouse click occurs during active session
pub unsafe fn cancel_alt_tab_session() {
    use block2::StackBlock;

    // Create block that calls Swift function to hide overlay
    let block = StackBlock::new(|| {
        pbmbo_hide_alt_tab_overlay();
        pbmbo_hide_highlight_border();
    });

    // Schedule on main runloop
    let main_runloop = crate::pbmba_ax::CFRunLoopGetMain();
    crate::pbmba_ax::CFRunLoopPerformBlock(
        main_runloop,
        core_foundation::runloop::kCFRunLoopDefaultMode as CFTypeRef,
        &*block as *const _ as *const c_void,
    );
    crate::pbmba_ax::CFRunLoopWakeUp(main_runloop);

    // Reset session state (can do this immediately)
    let mut session = ALT_TAB_SESSION.lock().unwrap();
    *session = AltTabSession::default();

    println!("SWITCHER: cancelled | reason=mouse_click");
}

/// Defer Alt-Tab switch commit to main runloop for thread safety
/// Called when Alt key is released during an active session
pub unsafe fn defer_alt_tab_commit(target_entry: MruWindowEntry) {
    use std::rc::Rc;
    use block2::StackBlock;

    let entry_rc = Rc::new(target_entry);

    let block = StackBlock::new(move || {
        commit_alt_tab_switch(&*entry_rc);
    });

    // Schedule on main runloop
    let main_runloop = crate::pbmba_ax::CFRunLoopGetMain();
    crate::pbmba_ax::CFRunLoopPerformBlock(
        main_runloop,
        core_foundation::runloop::kCFRunLoopDefaultMode as CFTypeRef,
        &*block as *const _ as *const c_void,
    );
    crate::pbmba_ax::CFRunLoopWakeUp(main_runloop);
}

/// Commit Alt-Tab switch by focusing the currently highlighted window
/// Must be called on main thread
pub unsafe fn commit_alt_tab_switch(target_entry: &MruWindowEntry) -> bool {
    use objc2::msg_send;
    use objc2::runtime::{AnyObject, Bool};

    // Check AX permissions first
    if !crate::pbmba_ax::check_ax_permissions() {
        eprintln!("SWITCHER: switch | FAILED reason=ax_permission_missing");
        return false;
    }

    let target_pid = target_entry.identity.pid;
    let bundle_id = &target_entry.bundle_id;
    let window_title = &target_entry.title;
    let target_window_id = target_entry.identity.window_id;

    // Get current frontmost app to determine if this is a cross-app or intra-app switch
    let current_frontmost = get_frontmost_app_info();
    let is_cross_app_switch = match current_frontmost {
        Some(ref info) => info.pid != target_pid,
        None => true, // Treat unknown as cross-app
    };

    eprintln!("DEBUG: [ALT_TAB] Switch type: {} (target_pid={}, target_window_id={})",
             if is_cross_app_switch { "cross-app" } else { "intra-app" },
             target_pid, target_window_id);

    // For cross-app switches: activate the app first
    if is_cross_app_switch {
        let ns_running_app: *mut AnyObject = msg_send![
            objc2::class!(NSRunningApplication),
            runningApplicationWithProcessIdentifier: target_pid as i32
        ];

        if ns_running_app.is_null() {
            eprintln!("SWITCHER: switch | FAILED reason=nsrunningapp_not_found app=\"{}\" pid={}", bundle_id, target_pid);
            return false;
        }

        // Activate with NSApplicationActivateIgnoringOtherApps option
        // NSApplicationActivateIgnoringOtherApps = 1 << 1 = 2
        let activated: Bool = msg_send![ns_running_app, activateWithOptions: 2u64];

        if !activated.as_bool() {
            eprintln!("SWITCHER: switch | FAILED reason=activation_failed app=\"{}\" win=\"{}\"", bundle_id, window_title);
            return false;
        }

        eprintln!("DEBUG: [ALT_TAB] Cross-app activation succeeded for pid={}", target_pid);
    }

    // For intra-app switches OR if we have a specific window to focus: use AX to focus the specific window
    if target_window_id != 0 {
        // Check if we need to focus a different window (intra-app switch)
        let needs_window_focus = if !is_cross_app_switch {
            // Intra-app: check if the focused window matches our target
            if let Ok(app) = AxElement::from_pid(target_pid) {
                if let Ok(win) = app.focused_window() {
                    if let Some(current_window_id) = win.get_window_id() {
                        current_window_id != target_window_id
                    } else {
                        true // Can't determine, try to focus
                    }
                } else {
                    true // Can't get focused window, try to focus
                }
            } else {
                true // Can't get app element, try to focus
            }
        } else {
            // Cross-app: after app activation, also focus the specific window if not window_id=0
            true
        };

        if needs_window_focus {
            eprintln!("DEBUG: [ALT_TAB] Focusing specific window_id={}", target_window_id);
            let focus_success = focus_window_by_id(target_pid, target_window_id);

            if !focus_success {
                eprintln!("SWITCHER: switch | WARNING failed to focus window_id={}", target_window_id);
                // Don't return false - app activation may have succeeded
            } else {
                eprintln!("DEBUG: [ALT_TAB] Window focus succeeded");
            }
        } else {
            eprintln!("DEBUG: [ALT_TAB] Target window already focused, no action needed");
        }
    }

    println!("SWITCHER: switch | SUCCESS app=\"{}\" win=\"{}\"", bundle_id, window_title);
    true
}