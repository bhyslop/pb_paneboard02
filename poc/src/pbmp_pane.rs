// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use core_foundation::base::{kCFAllocatorDefault, TCFType};
use core_foundation::runloop::kCFRunLoopDefaultMode;
use core_foundation::string::CFString;
use core_foundation_sys::base::CFTypeRef;
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

// Import types and functions from the new modules
use crate::pbmba_ax::{
    AxElement, AxError, FrontmostInfo,
    AXUIElementRef, AXObserverRef,
    KAX_ERROR_SUCCESS, KAX_ERROR_NOT_IMPLEMENTED, KAX_ERROR_CANNOT_COMPLETE,
    AXUIElementCreateApplication, AXUIElementCopyAttributeValue, AXUIElementSetAttributeValue,
    AXUIElementPerformAction, AXObserverCreate, AXObserverAddNotification,
    AXObserverRemoveNotification, AXObserverGetRunLoopSource,
    CFRunLoopGetMain,
    CFRunLoopAddSource, CFRunLoopRemoveSource, CFAbsoluteTimeGetCurrent,
    CFRunLoopTimerCreate, CFRunLoopAddTimer, CFRunLoopTimerContext,
    _AXUIElementGetWindow, CFArrayGetCount, CFArrayGetValueAtIndex,
    kCFBooleanTrue, kCFBooleanFalse,
    ax_attr_title, ax_attr_role, ax_attr_windows, ax_attr_main, ax_attr_minimized, ax_action_raise,
};

use crate::pbmbd_display::{
    VisibleFrame, Rect,
    visible_frame_main_display, visible_frame_for_screen,
    get_all_screens, get_display_for_window_with_validation,
    gather_all_display_info,
};

use crate::pbgf_form::{Form, PixelRect};

// Need to import CFRelease separately as it's used in multiple places
use core_foundation::base::CFRelease;

use lazy_static::lazy_static;

// One-time warning flag for visibleFrame validation
static VISIBLE_FRAME_WARNING_SHOWN: AtomicBool = AtomicBool::new(false);

// Global form configuration (layout system)
lazy_static! {
    static ref FORM: Mutex<Form> = {
        unsafe {
            let displays = gather_all_display_info();
            Mutex::new(Form::load_from_file(&displays))
        }
    };

    // Quirk-adjusted displays cached at startup (caller ownership pattern)
    static ref ADJUSTED_DISPLAYS: Vec<crate::pbmbd_display::DisplayInfo> = {
        unsafe {
            let raw_displays = gather_all_display_info();
            let form = FORM.lock().unwrap();
            form.adjust_displays(&raw_displays)
        }
    };
}

/// Print expected pane sequence for all layout actions at startup
pub unsafe fn print_expected_pane_sequences() {
    eprintln!("\n========== EXPECTED PANE SEQUENCES ==========\n");

    // Iterate ADJUSTED_DISPLAYS first (triggers lazy_static initialization)
    // Then lock FORM only when needed (avoids deadlock)
    for display_info in ADJUSTED_DISPLAYS.iter() {
        eprintln!("Display: {} ({}x{})",
            display_info.name,
            display_info.design_width as u32,
            display_info.design_height as u32);

        let display_props = display_info.as_props();
        let keys = vec!["home", "end", "pageup", "pagedown"];

        for key in keys {
            // Lock FORM for each lookup (don't hold lock during I/O)
            let form = FORM.lock().unwrap();
            let panes_opt = form.panes_for_action(key, &display_props);
            drop(form);

            if let Some(panes) = panes_opt {
                eprintln!("  key='{}' → {} panes:", key, panes.len());
                for (idx, pane) in panes.iter().take(10).enumerate() {
                    let pixel_x = (pane.x * display_info.design_width) as u32;
                    let pixel_y = (pane.y * display_info.design_height) as u32;
                    let pixel_w = (pane.width * display_info.design_width) as u32;
                    let pixel_h = (pane.height * display_info.design_height) as u32;
                    eprintln!("    [{}] ({},{}) {}x{}", idx, pixel_x, pixel_y, pixel_w, pixel_h);
                }
                if panes.len() > 10 {
                    eprintln!("    ... {} more panes", panes.len() - 10);
                }
            }
        }
        eprintln!();
    }

    eprintln!("=============================================\n");
}

// Helper function to get visible frame with quirks applied
// Gets DisplayInfo directly and uses its live_viewport method
unsafe fn visible_frame_with_quirks_for_index(screen: &objc2_app_kit::NSScreen, display_index: usize) -> Option<VisibleFrame> {
    if let Some(display_info) = ADJUSTED_DISPLAYS.get(display_index) {
        return display_info.live_viewport(screen);
    }
    // Fallback: return raw visible frame if lookup fails
    visible_frame_for_screen(screen)
}

// Frontmost app info captured at chord time
// Tiling job with frontmost context
#[derive(Clone, Debug)]
pub struct TilingJob {
    pub frontmost: FrontmostInfo,
    pub attempt: u32, // 0 = first attempt, 1-3 = retries
    pub key_name: Option<String>, // Key name for layout action
}

// Observer context for timeout and job tracking
pub struct ObserverContext {
    pub job: TilingJob,
    pub observer: AXObserverRef,
    pub runloop_source: *mut c_void,
    pub active: bool, // flag to prevent double cleanup
}

/// Window metadata from enumeration (used during prepopulation)
/// Note: Does not store AXUIElementRef to avoid dangling pointer issues
#[derive(Debug, Clone)]
pub struct EnumeratedWindow {
    pub window_id: u32,
    pub title: String,
}

/// Reset layout session state (called on modifier release)
pub fn reset_layout_session() {
    let mut form = FORM.lock().unwrap();
    form.reset_layout_session();
    form.reset_display_move_session();
}

/// Handle any key configured in Form XML (LayoutAction or DisplayMove)
/// Returns true if the key was handled, false if no binding exists
pub fn handle_configured_key(key: &str, frontmost: FrontmostInfo) -> bool {
    // Check Form for bindings (order: LayoutAction first, then DisplayMove)
    let form = FORM.lock().unwrap();
    let has_layout = form.has_layout_action(key);
    let has_display_move = form.has_display_move(key);
    drop(form);

    if has_layout {
        // Create TilingJob for Form-driven layout
        let job = TilingJob {
            frontmost,
            attempt: 0,
            key_name: Some(key.to_string()),
        };
        tile_window_quadrant(job);
        true
    } else if has_display_move {
        execute_display_move_for_key(key, frontmost.pid, &frontmost.bundle_id)
    } else {
        false
    }
}

/// Execute a DisplayMove for the given key (checks Form configuration)
/// Returns true if move was executed, false if no binding or out of range
pub fn execute_display_move_for_key(key: &str, pid: u32, bundle_id: &str) -> bool {
    unsafe {
        let screens = get_all_screens();
        if screens.is_empty() {
            eprintln!("DISPLAYMOVE: key={} | FAILED reason=no_screens", key);
            return false;
        }

        // Get focused window
        let win = match get_focused_window_by_pid(pid) {
            Ok(w) => w,
            Err(reason) => {
                eprintln!("DISPLAYMOVE: key={} | FAILED reason={}", key, reason);
                return false;
            }
        };

        // Get current window rect
        let current_rect = match win.get_current_rect() {
            Some(r) => r,
            None => {
                eprintln!("DISPLAYMOVE: key={} | FAILED reason=cannot_get_current_rect", key);
                return false;
            }
        };

        // Determine current display index
        let current_display_index = get_display_index_for_window(current_rect);

        // Look up target display from Form
        let form = FORM.lock().unwrap();
        let target_display_index = match form.execute_display_move(key, current_display_index, screens.len()) {
            Some(idx) => idx,
            None => {
                // No binding or out of range (already logged)
                return false;
            }
        };
        drop(form); // Release lock before AX operations

        // If already on target display, no-op
        if target_display_index == current_display_index {
            eprintln!("DISPLAYMOVE: Already on target display {}", target_display_index);
            return false;
        }

        // Get target visible frame
        let target_vf = match visible_frame_with_quirks_for_index(&screens[target_display_index], target_display_index) {
            Some(vf) => vf,
            None => {
                eprintln!("DISPLAYMOVE: key={} | FAILED reason=no_visible_frame", key);
                return false;
            }
        };

        // Get current visible frame for offset calculation
        let current_vf = visible_frame_with_quirks_for_index(&screens[current_display_index], current_display_index).unwrap();

        // Calculate offset within current screen
        let offset_x = current_rect.x - current_vf.min_x;
        let offset_y = current_rect.y - current_vf.min_y;

        // Apply same offset to target screen to preserve relative position
        let new_x = target_vf.min_x + offset_x;
        let new_y = target_vf.min_y + offset_y;

        // Move window to new position (size unchanged)
        match win.set_position(new_x, new_y) {
            Ok(()) => {
                println!(
                    "DISPLAYMOVE: SUCCESS key={} | app=\"{}\" from_display={} to_display={} frame=({:.0},{:.0},{:.0},{:.0})",
                    key, bundle_id, current_display_index, target_display_index, new_x, new_y, current_rect.w, current_rect.h
                );
                true
            }
            Err(e) => {
                let reason = match e {
                    AxError::Permission => "ax_permission_missing_or_revoked",
                    AxError::Platform(code) => {
                        eprintln!("DEBUG: set_position failed with code {}", code);
                        "ax_error"
                    }
                    _ => "ax_error",
                };
                eprintln!("DISPLAYMOVE: key={} | FAILED reason={}", key, reason);
                false
            }
        }
    }
}

/// Focus a specific window by window ID using AX APIs
/// Returns true on success, false on failure
pub unsafe fn focus_window_by_id(pid: u32, window_id: u32) -> bool {
    eprintln!("DEBUG: Focusing window_id={} for pid={}", window_id, pid);

    // Create app element
    let app_element = AXUIElementCreateApplication(pid);
    if app_element.is_null() {
        eprintln!("DEBUG: Failed to create app element for pid={}", pid);
        return false;
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
        eprintln!("DEBUG: AXWindows query failed for pid={}, error={}", pid, rc);
        CFRelease(app_element as CFTypeRef);
        return false;
    }

    // Iterate through CFArray to find target window
    let count = CFArrayGetCount(windows_array);
    let mut target_element: AXUIElementRef = std::ptr::null();
    let mut found = false;

    for i in 0..count {
        let window_element = CFArrayGetValueAtIndex(windows_array, i) as AXUIElementRef;
        if window_element.is_null() {
            continue;
        }

        // Get window ID
        let mut wid: u32 = 0;
        let wid_rc = _AXUIElementGetWindow(window_element, &mut wid);
        if wid_rc == 0 && wid == window_id {
            target_element = window_element;
            found = true;
            break;
        }
    }

    if !found {
        eprintln!("DEBUG: Window with window_id={} not found in enumeration", window_id);
        CFRelease(windows_array);
        CFRelease(app_element as CFTypeRef);
        return false;
    }

    // Now we have a valid element reference - use it immediately before releasing the array

    // Check if window is minimized and restore it if needed
    let minimized_attr = ax_attr_minimized();
    let mut minimized_ref: CFTypeRef = std::ptr::null();
    let minimized_rc = AXUIElementCopyAttributeValue(
        target_element,
        minimized_attr.as_concrete_TypeRef() as CFTypeRef,
        &mut minimized_ref,
    );

    if minimized_rc == KAX_ERROR_SUCCESS && !minimized_ref.is_null() {
        let is_minimized = minimized_ref as usize == 1; // Simplified CFBoolean check
        CFRelease(minimized_ref);

        if is_minimized {
            // Restore the window (set AXMinimized to false)
            let restore_rc = AXUIElementSetAttributeValue(
                target_element,
                minimized_attr.as_concrete_TypeRef() as CFTypeRef,
                kCFBooleanFalse,
            );

            if restore_rc == KAX_ERROR_SUCCESS {
                println!("SWITCHER: restored minimized window before focus");
            } else {
                eprintln!("SWITCHER: failed to restore minimized window (code={})", restore_rc);
            }
        }
    }

    // Set AXMain attribute to true
    let main_attr = ax_attr_main();
    let set_main_rc = AXUIElementSetAttributeValue(
        target_element,
        main_attr.as_concrete_TypeRef() as CFTypeRef,
        kCFBooleanTrue,
    );

    if set_main_rc != KAX_ERROR_SUCCESS {
        eprintln!("DEBUG: AXMain set failed with code {}", set_main_rc);
    }

    // Perform AXRaise action
    let raise_action = ax_action_raise();
    let raise_rc = AXUIElementPerformAction(
        target_element,
        raise_action.as_concrete_TypeRef() as CFTypeRef,
    );

    // Cleanup
    CFRelease(windows_array);
    CFRelease(app_element as CFTypeRef);

    if raise_rc != KAX_ERROR_SUCCESS {
        eprintln!("DEBUG: AXRaise failed with code {}", raise_rc);
        return false;
    }

    eprintln!("DEBUG: Window focus succeeded (window_id={})", window_id);
    true
}

/// Enumerate all windows for a given app PID
/// Queries kAXWindowsAttribute and filters by role
/// Returns Vec of window metadata (empty on failure or no windows)
pub unsafe fn enumerate_app_windows(pid: u32) -> Vec<EnumeratedWindow> {
    let mut result = Vec::new();

    // Create app element
    let app_element = AXUIElementCreateApplication(pid);
    if app_element.is_null() {
        eprintln!("DEBUG: [enumerate_app_windows] Failed to create app element for pid={}", pid);
        return result;
    }

    // Query kAXWindowsAttribute
    let windows_attr = ax_attr_windows();
    let mut windows_array: CFTypeRef = std::ptr::null();
    let rc = AXUIElementCopyAttributeValue(
        app_element,
        windows_attr.as_concrete_TypeRef() as CFTypeRef,
        &mut windows_array,
    );

    if rc != KAX_ERROR_SUCCESS {
        eprintln!("DEBUG: [enumerate_app_windows] AXWindows query failed for pid={}, error={}", pid, rc);
        CFRelease(app_element as CFTypeRef);
        return result;
    }

    if windows_array.is_null() {
        eprintln!("DEBUG: [enumerate_app_windows] AXWindows returned null for pid={}", pid);
        CFRelease(app_element as CFTypeRef);
        return result;
    }

    // Iterate through CFArray
    let count = CFArrayGetCount(windows_array);
    eprintln!("DEBUG: [enumerate_app_windows] Found {} window(s) for pid={}", count, pid);

    for i in 0..count {
        let window_element = CFArrayGetValueAtIndex(windows_array, i) as AXUIElementRef;
        if window_element.is_null() {
            continue;
        }

        // Check role - only accept "AXWindow"
        let role_attr = ax_attr_role();
        let mut role_value: CFTypeRef = std::ptr::null();
        let role_rc = AXUIElementCopyAttributeValue(
            window_element,
            role_attr.as_concrete_TypeRef() as CFTypeRef,
            &mut role_value,
        );

        let role_str = if role_rc == KAX_ERROR_SUCCESS && !role_value.is_null() {
            let cf_str = CFString::wrap_under_get_rule(role_value as *const core_foundation::string::__CFString);
            let role = cf_str.to_string();
            CFRelease(role_value);
            Some(role)
        } else {
            None
        };

        // Filter: only include AXWindow role
        if role_str.as_deref() != Some("AXWindow") {
            eprintln!("DEBUG: [enumerate_app_windows] Skipping window with role={:?}", role_str);
            continue;
        }

        // Get window ID
        let mut window_id: u32 = 0;
        let wid_rc = _AXUIElementGetWindow(window_element, &mut window_id);
        if wid_rc != 0 || window_id == 0 {
            eprintln!("DEBUG: [enumerate_app_windows] Failed to get window ID (rc={}), skipping", wid_rc);
            continue;
        }

        // Get title (best effort)
        let title_attr = ax_attr_title();
        let mut title_value: CFTypeRef = std::ptr::null();
        let title_rc = AXUIElementCopyAttributeValue(
            window_element,
            title_attr.as_concrete_TypeRef() as CFTypeRef,
            &mut title_value,
        );

        let title = if title_rc == KAX_ERROR_SUCCESS && !title_value.is_null() {
            let cf_str = CFString::wrap_under_get_rule(title_value as *const core_foundation::string::__CFString);
            let t = cf_str.to_string();
            CFRelease(title_value);
            if t.is_empty() {
                format!("<win:{}>", window_id)
            } else {
                t
            }
        } else {
            format!("<win:{}>", window_id)
        };

        eprintln!("DEBUG: [enumerate_app_windows] Found window: window_id={} title=\"{}\"", window_id, title);

        result.push(EnumeratedWindow {
            window_id,
            title,
        });
    }

    // Cleanup
    CFRelease(windows_array);
    CFRelease(app_element as CFTypeRef);

    result
}

// Get focused window using PID-targeted approach
pub unsafe fn get_focused_window_by_pid(pid: u32) -> Result<AxElement, String> {
    eprintln!("DEBUG: get_focused_window_by_pid({}) starting...", pid);

    let app = AxElement::from_pid(pid).map_err(|e| {
        eprintln!("DEBUG: AXUIElementCreateApplication(pid={}) failed: {:?}", pid, e);
        format!("ax_create_app_pid_failed(pid={})", pid)
    })?;

    let win = app.focused_window().map_err(|e| {
        let msg = match e {
            AxError::Permission => {
                eprintln!("DEBUG: AXFocusedWindow failed: Permission denied (code -25204)");
                "ax_permission_missing_or_revoked".to_string()
            }
            AxError::Platform(code) => {
                if code == KAX_ERROR_NOT_IMPLEMENTED {
                    eprintln!("DEBUG: AXFocusedWindow failed (code=-25212, not ready yet)");
                    "ax_not_ready_retry_needed".to_string()
                } else if code == KAX_ERROR_CANNOT_COMPLETE {
                    eprintln!("DEBUG: AXFocusedWindow failed (code=-25205, cannot complete)");
                    "ax_cannot_complete_retry_needed".to_string()
                } else {
                    eprintln!("DEBUG: AXFocusedWindow failed: AX error code {}", code);
                    format!("ax_focused_window_failed(code={})", code)
                }
            }
            _ => {
                eprintln!("DEBUG: AXFocusedWindow failed: {:?}", e);
                "no_focused_window".to_string()
            }
        };
        msg
    })?;

    // Get window title for debugging
    let win_title = win.get_title().unwrap_or_else(|| "<no window title>".to_string());
    eprintln!("DEBUG: Focused window: \"{}\"", win_title);

    Ok(win)
}

// Check if error should trigger AXObserver approach
pub fn should_use_observer_on_error(error_msg: &str) -> bool {
    error_msg.contains("ax_not_ready_retry_needed") ||
    error_msg.contains("ax_cannot_complete_retry_needed")
}

/// Convert PixelRect to Rect (passthrough - coordinates already absolute)
///
/// PixelRect coordinates are produced by DisplayInfo::realize_panes() which:
/// 1. Calls live_viewport() to get quirk-corrected viewport at runtime
/// 2. Converts fractions to absolute screen coordinates: vf.min_x + f.x * vf.width
///
/// Therefore PixelRect already contains absolute screen coordinates ready for AX API.
/// No additional offset or quirk correction should be applied here.
fn pixel_rect_to_rect(pr: &PixelRect, _vf: &VisibleFrame) -> Rect {
    Rect {
        x: pr.x,
        y: pr.y,
        w: pr.width,
        h: pr.height,
    }
}

/// Determine which display index contains the given window rect (by center point)
unsafe fn get_display_index_for_window(window_rect: Rect) -> usize {
    let screens = get_all_screens();
    let win_center_x = window_rect.x + window_rect.w / 2.0;
    let win_center_y = window_rect.y + window_rect.h / 2.0;

    for (idx, screen) in screens.iter().enumerate() {
        if let Some(vf) = visible_frame_for_screen(screen) {
            if win_center_x >= vf.min_x && win_center_x < vf.min_x + vf.width &&
               win_center_y >= vf.min_y && win_center_y < vf.min_y + vf.height {
                return idx;
            }
        }
    }

    0 // Fallback to main display
}

// Safe wrapper to set window rect using RAII and Position → Size policy with debug logging
pub fn set_window_rect_safe(win: &AxElement, r: Rect) -> Result<(), String> {
    unsafe {
        eprintln!("DEBUG: Using Position→Size policy (global experiment)");
        eprintln!("DEBUG: set_window_rect_safe() target: ({:.0},{:.0},{:.0},{:.0})", r.x, r.y, r.w, r.h);

        // Get current rect before any changes
        if let Some(before_rect) = win.get_current_rect() {
            eprintln!("DEBUG: Before resize - current rect: ({:.0},{:.0},{:.0},{:.0})",
                     before_rect.x, before_rect.y, before_rect.w, before_rect.h);
        } else {
            eprintln!("DEBUG: Before resize - could not get current rect");
        }

        // Policy: Position first, then size (Chrome-safe practice)
        eprintln!("DEBUG: Setting position to ({:.0},{:.0})", r.x, r.y);
        win.set_position(r.x, r.y).map_err(|e| {
            let msg = match e {
                AxError::Permission => {
                    eprintln!("DEBUG: AXPosition failed: Permission denied (code -25204)");
                    "ax_permission_missing_or_revoked".to_string()
                }
                AxError::Platform(code) => {
                    eprintln!("DEBUG: AXPosition failed: AX error code {}", code);
                    format!("ax_error(code={}, op=AXPosition)", code)
                }
                _ => {
                    eprintln!("DEBUG: AXPosition failed: {:?}", e);
                    "ax_error(code=-1, op=AXPosition)".to_string()
                }
            };
            msg
        })?;

        // Check rect after position change
        if let Some(after_pos_rect) = win.get_current_rect() {
            eprintln!("DEBUG: After position change - current rect: ({:.0},{:.0},{:.0},{:.0})",
                     after_pos_rect.x, after_pos_rect.y, after_pos_rect.w, after_pos_rect.h);
        } else {
            eprintln!("DEBUG: After position change - could not get current rect");
        }

        eprintln!("DEBUG: Setting size to ({:.0},{:.0})", r.w, r.h);
        win.set_size(r.w, r.h).map_err(|e| {
            let msg = match e {
                AxError::Permission => {
                    eprintln!("DEBUG: AXSize failed: Permission denied (code -25204)");
                    "ax_permission_missing_or_revoked".to_string()
                }
                AxError::Constrained => {
                    eprintln!("DEBUG: AXSize failed: Size constrained or window is fullscreen");
                    "size_constrained_or_fullscreen".to_string()
                }
                AxError::Platform(code) => {
                    eprintln!("DEBUG: AXSize failed: AX error code {}", code);
                    format!("ax_error(code={}, op=AXSize)", code)
                }
            };
            msg
        })?;

        // Get final rect after both changes
        if let Some(final_rect) = win.get_current_rect() {
            eprintln!("DEBUG: Final rect after size change: ({:.0},{:.0},{:.0},{:.0})",
                     final_rect.x, final_rect.y, final_rect.w, final_rect.h);

            // Check if the final rect matches what we requested
            let pos_matches = (final_rect.x - r.x).abs() < 1.0 && (final_rect.y - r.y).abs() < 1.0;
            let size_matches = (final_rect.w - r.w).abs() < 1.0 && (final_rect.h - r.h).abs() < 1.0;

            if !pos_matches || !size_matches {
                eprintln!("DEBUG: Final rect does not exactly match target (app constraints likely)");
            } else {
                eprintln!("DEBUG: SUCCESS - Final rect matches target");
            }
        } else {
            eprintln!("DEBUG: Final rect - could not get current rect");
        }

        Ok(())
    }
}

// Cleanup helper for observer resources
pub unsafe fn cleanup_locked(ctx: &mut ObserverContext) {
    // Remove notifications before releasing observer
    let focused = CFString::from_static_string("AXFocusedWindowChanged");
    let app_element = AXUIElementCreateApplication(ctx.job.frontmost.pid);
    AXObserverRemoveNotification(ctx.observer, app_element, focused.as_concrete_TypeRef() as CFTypeRef);
    CFRelease(app_element as CFTypeRef);

    // Remove and release runloop source
    CFRunLoopRemoveSource(CFRunLoopGetMain(), ctx.runloop_source, kCFRunLoopDefaultMode as *mut c_void);
    CFRelease(ctx.runloop_source as CFTypeRef);

    // Release observer
    CFRelease(ctx.observer as CFTypeRef);
}

// Timer callback for observer timeout
pub extern "C" fn observer_timeout_callback(_timer: *mut c_void, info: *mut c_void) {
    unsafe {
        if !info.is_null() {
            let ctx_arc = Arc::from_raw(info as *const Mutex<ObserverContext>);
            let mut guard = match ctx_arc.lock() {
                Ok(guard) => guard,
                Err(_) => return,
            };

            if guard.active {
                let tag = guard.job.key_name.clone().unwrap_or_else(|| "UNKNOWN".to_string());
                guard.active = false;
                cleanup_locked(&mut *guard);
                println!("TILE: {tag} | FAILED reason=not_ready_timeout");
            }
        }
    }
}

// AXObserver callback - called when focus changes
pub extern "C" fn ax_observer_callback(
    _observer: AXObserverRef,
    element: AXUIElementRef,
    _notif: CFTypeRef,
    refcon: *mut c_void,
) {
    if refcon.is_null() {
        return;
    }

    let arc = unsafe { Arc::from_raw(refcon as *const Mutex<ObserverContext>) };
    let ctx = arc.clone();
    std::mem::forget(arc); // keep raw pointer valid

    let mut guard = match ctx.lock() {
        Ok(g) => g,
        Err(_) => return,
    };

    if !guard.active {
        return; // already handled or timeout
    }

    unsafe {
        let tag = guard.job.key_name.as_deref().unwrap_or("UNKNOWN");

        // Get the display frame for the window
        let win_elem = AxElement(element);
        let current_rect = win_elem.get_current_rect();
        std::mem::forget(win_elem); // prevent CFRelease

        let (vf, display_index) = if let Some(rect) = current_rect {
            let disp_idx = get_display_index_for_window(rect);
            let screens = get_all_screens();
            let visible = if disp_idx < screens.len() {
                visible_frame_with_quirks_for_index(&screens[disp_idx], disp_idx).unwrap_or_else(|| {
                    visible_frame_main_display().expect("Main display should exist")
                })
            } else {
                visible_frame_main_display().expect("Main display should exist")
            };
            (visible, disp_idx)
        } else {
            let screens = get_all_screens();
            let visible = if !screens.is_empty() {
                visible_frame_with_quirks_for_index(&screens[0], 0).expect("Main display should exist")
            } else {
                visible_frame_main_display().expect("Main display should exist")
            };
            (visible, 0)
        };

        // Look up pane from Form and convert to pixels
        let key = guard.job.key_name.as_deref().unwrap_or("UNKNOWN");

        if let Some(display_info) = ADJUSTED_DISPLAYS.get(display_index) {
            let display_props = display_info.as_props();
            let mut form = FORM.lock().unwrap();
            let pane_result = form.get_next_pane(key, &display_props);
            drop(form);

            if let Some((frac_pane, pane_idx)) = pane_result {
                // Convert fractional pane to pixels and filter small panes
                let pixel_rects = display_info.realize_panes(&[frac_pane]);
                let filtered = crate::pbmbd_display::DisplayInfo::filter_small(&pixel_rects);
                if let Some(pixel_rect) = filtered.first() {
                    let r = pixel_rect_to_rect(pixel_rect, &vf);
                    let win = AxElement(element);
                    match set_window_rect_safe(&win, r) {
                        Ok(()) => println!("TILE: {tag} | SUCCESS after_observer=yes | key={} pane={} app=\"{}\"", key, pane_idx, guard.job.frontmost.bundle_id),
                        Err(e) => println!("TILE: {tag} | FAILED reason={}", e),
                    }
                    std::mem::forget(win); // prevent CFRelease
                } else {
                    println!("TILE: {tag} | FAILED reason=pane_too_small key={}", key);
                }
            } else {
                println!("TILE: {tag} | FAILED reason=no_pane_for_key key={}", key);
            }
        } else {
            println!("TILE: {tag} | FAILED reason=no_display_info");
        }

        guard.active = false;
        cleanup_locked(&mut *guard);
    }
}

// Tile window using job struct
pub fn tile_window_quadrant(job: TilingJob) {
    let tag = job.key_name.as_deref().unwrap_or("UNKNOWN");

    eprintln!("DEBUG: tile_window_quadrant(key={}) for pid={}, app=\"{}\"", tag, job.frontmost.pid, job.frontmost.bundle_id);

    // Get focused window using PID-targeted approach
    let win = match unsafe { get_focused_window_by_pid(job.frontmost.pid) } {
        Ok(w) => w,
        Err(reason) => {
            // Check if we should use observer approach
            if should_use_observer_on_error(&reason) && job.attempt == 0 {
                eprintln!("DEBUG: Will use AXObserver approach due to: {}", reason);
                unsafe { tile_window_with_observer(job) };
            } else {
                println!("TILE: {} | FAILED reason={}", tag, reason);
            }
            return;
        }
    };

    unsafe {
        // Get the display frame for the window with validation
        let current_rect = win.get_current_rect();
        let (vf, display_index) = if let Some(rect) = current_rect {
            // Determine display index first
            let disp_idx = get_display_index_for_window(rect);

            // Use validation version to get both visible and full frames
            if let Some((mut visible, _full, delta_y)) = get_display_for_window_with_validation(rect) {
                // One-time warning if delta_y != 0
                if delta_y != 0.0 && !VISIBLE_FRAME_WARNING_SHOWN.swap(true, Ordering::Relaxed) {
                    eprintln!("NOTE: visibleFrame correction applied (menu bar height: {:.0}px)", delta_y);
                }

                // Apply quirks via DisplayInfo
                let screens = get_all_screens();
                if disp_idx < screens.len() {
                    if let Some(display_info) = ADJUSTED_DISPLAYS.get(disp_idx) {
                        // Replace visible frame with quirk-adjusted version from DisplayInfo
                        if let Some(quirked_vf) = display_info.live_viewport(&screens[disp_idx]) {
                            visible = quirked_vf;
                        }
                    }
                }

                (visible, disp_idx)
            } else {
                let screens = get_all_screens();
                let visible = if !screens.is_empty() {
                    visible_frame_with_quirks_for_index(&screens[0], 0).unwrap_or_else(|| {
                        visible_frame_main_display().expect("Main display should exist")
                    })
                } else {
                    visible_frame_main_display().expect("Main display should exist")
                };
                (visible, 0)
            }
        } else {
            let screens = get_all_screens();
            let visible = if !screens.is_empty() {
                visible_frame_with_quirks_for_index(&screens[0], 0).unwrap_or_else(|| {
                    visible_frame_main_display().expect("Main display should exist")
                })
            } else {
                visible_frame_main_display().expect("Main display should exist")
            };
            (visible, 0)
        };

        // Look up pane from Form and convert to pixels
        let key = job.key_name.as_deref().unwrap_or("UNKNOWN");

        if let Some(display_info) = ADJUSTED_DISPLAYS.get(display_index) {
            let display_props = display_info.as_props();
            let mut form = FORM.lock().unwrap();
            let pane_result = form.get_next_pane(key, &display_props);
            drop(form);

            if let Some((frac_pane, pane_idx)) = pane_result {
                // Convert fractional pane to pixels and filter small panes
                let pixel_rects = display_info.realize_panes(&[frac_pane]);
                let filtered = crate::pbmbd_display::DisplayInfo::filter_small(&pixel_rects);
                if let Some(pixel_rect) = filtered.first() {
                    let r = pixel_rect_to_rect(pixel_rect, &vf);
                    match set_window_rect_safe(&win, r) {
                        Ok(()) => println!("TILE: {} | SUCCESS | key={} pane={} app=\"{}\"", tag, key, pane_idx, job.frontmost.bundle_id),
                        Err(reason) => {
                            // Check if we should retry with observer
                            if reason.contains("not_ready") || reason.contains("cannot_complete") {
                                if job.attempt == 0 {
                                    eprintln!("DEBUG: Will use AXObserver approach due to: {}", reason);
                                    tile_window_with_observer(job);
                                } else {
                                    println!("TILE: {} | FAILED reason={}", tag, reason);
                                }
                            } else {
                                println!("TILE: {} | FAILED reason={}", tag, reason);
                            }
                        }
                    }
                } else {
                    println!("TILE: {} | FAILED reason=pane_too_small", tag);
                }
            } else {
                eprintln!("LAYOUT: no panes available for key={} on display={}", key, display_index);
                println!("TILE: {} | FAILED reason=no_pane_for_key", tag);
            }
        } else {
            println!("TILE: {} | FAILED reason=no_display_info", tag);
        }
    }
}

// Tile window using AXObserver approach
unsafe fn tile_window_with_observer(job: TilingJob) {
    eprintln!("DEBUG: tile_window_with_observer() starting for app={}", job.frontmost.bundle_id);

    let tag = job.key_name.as_deref().unwrap_or("UNKNOWN");

    // Create observer for the app
    let mut observer: AXObserverRef = std::ptr::null();
    let rc = AXObserverCreate(
        job.frontmost.pid as i32,
        ax_observer_callback,
        &mut observer,
    );

    if rc != KAX_ERROR_SUCCESS || observer.is_null() {
        eprintln!("DEBUG: AXObserverCreate failed with code {}", rc);
        println!("TILE: {} | FAILED reason=observer_create_failed", tag);
        return;
    }

    // Add notification for focused window changes
    let app_element = AXUIElementCreateApplication(job.frontmost.pid);
    let notification = CFString::from_static_string("AXFocusedWindowChanged");

    // Create context with timeout tracking
    let ctx = ObserverContext {
        job: job.clone(),
        observer,
        runloop_source: AXObserverGetRunLoopSource(observer),
        active: true,
    };

    let ctx_arc = Arc::new(Mutex::new(ctx));
    let ctx_ptr = Arc::into_raw(ctx_arc.clone());

    let rc = AXObserverAddNotification(
        observer,
        app_element,
        notification.as_concrete_TypeRef() as CFTypeRef,
        ctx_ptr as *mut c_void,
    );

    if rc != KAX_ERROR_SUCCESS {
        eprintln!("DEBUG: AXObserverAddNotification failed with code {}", rc);
        CFRelease(app_element as CFTypeRef);
        CFRelease(observer as CFTypeRef);

        // Clean up the Arc
        let _ = Arc::from_raw(ctx_ptr);

        println!("TILE: {} | FAILED reason=observer_notification_failed", tag);
        return;
    }

    // Add observer to runloop
    let runloop_source = AXObserverGetRunLoopSource(observer);
    CFRunLoopAddSource(
        CFRunLoopGetMain(),
        runloop_source,
        kCFRunLoopDefaultMode as *mut c_void,
    );

    // Set up timeout timer
    let timer_ctx = CFRunLoopTimerContext {
        version: 0,
        info: ctx_ptr as *mut c_void,
        retain: None,
        release: None,
        copy_description: None,
    };

    let timer = CFRunLoopTimerCreate(
        kCFAllocatorDefault,
        CFAbsoluteTimeGetCurrent() + 0.5,
        0.0,
        0,
        0,
        observer_timeout_callback,
        &timer_ctx,
    );

    CFRunLoopAddTimer(
        CFRunLoopGetMain(),
        timer,
        kCFRunLoopDefaultMode as *mut c_void,
    );

    // Clean up app element
    CFRelease(app_element as CFTypeRef);

    eprintln!("DEBUG: AXObserver installed for PID {}, waiting for focus change", job.frontmost.pid);
}