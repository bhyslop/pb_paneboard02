// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use core_foundation::base::{CFRelease, TCFType};
use core_foundation::string::CFString;
use core_foundation_sys::base::CFTypeRef;
use std::ffi::c_void;

use objc2::runtime::Bool;
use objc2::msg_send;
use objc2_app_kit::NSWorkspace;

// Frontmost app information structure
#[derive(Clone, Debug)]
pub struct FrontmostInfo {
    pub pid: u32,
    pub bundle_id: String,
    #[allow(dead_code)]
    pub name: String,
}

// Focused window information structure
#[derive(Clone, Debug)]
pub struct FocusedWindowInfo {
    pub window_id: u32,
    pub title: String,
}

// AX types
#[repr(C)]
pub struct __AXUIElement(std::ffi::c_void);
pub type AXUIElementRef = *const __AXUIElement;

#[repr(C)]
pub struct __AXValue(std::ffi::c_void);
pub type AXValueRef = *const __AXValue;

#[repr(C)]
pub struct __AXObserver(std::ffi::c_void);
pub type AXObserverRef = *const __AXObserver;

pub type AXObserverCallback = extern "C" fn(
    observer: AXObserverRef,
    element: AXUIElementRef,
    notification: CFTypeRef,
    refcon: *mut c_void,
);

// ApplicationServices linking
#[link(name = "ApplicationServices", kind = "framework")]
#[link(name = "System", kind = "dylib")]
extern "C" {
    // AX trust check
    fn AXIsProcessTrustedWithOptions(options: CFTypeRef) -> Bool;

    // AX basics
    pub fn AXUIElementCreateApplication(pid: u32) -> AXUIElementRef;
    pub fn AXUIElementCopyAttributeValue(element: AXUIElementRef, attr: CFTypeRef, out: *mut CFTypeRef) -> i32;
    pub fn AXUIElementSetAttributeValue(element: AXUIElementRef, attr: CFTypeRef, value: CFTypeRef) -> i32;
    pub fn AXUIElementPerformAction(element: AXUIElementRef, action: CFTypeRef) -> i32;

    // AXValue
    pub(crate) fn AXValueCreate(theType: i32, valuePtr: *const std::ffi::c_void) -> AXValueRef;
    pub(crate) fn AXValueGetValue(value: AXValueRef, theType: i32, valuePtr: *mut std::ffi::c_void) -> bool;

    // CFRunLoop functions
    pub fn CFRunLoopGetCurrent() -> *mut std::ffi::c_void;
    pub fn CFRunLoopRun();
    pub fn CFRunLoopGetMain() -> *mut c_void;
    pub fn CFRunLoopPerformBlock(rl: *mut c_void, mode: CFTypeRef, block: *const c_void);
    pub fn CFRunLoopWakeUp(rl: *mut c_void);

    // AXObserver
    pub fn AXObserverCreate(application: i32, callback: AXObserverCallback, observer: *mut AXObserverRef) -> i32;
    pub fn AXObserverAddNotification(observer: AXObserverRef, element: AXUIElementRef, notification: CFTypeRef, refcon: *mut c_void) -> i32;
    pub fn AXObserverRemoveNotification(observer: AXObserverRef, element: AXUIElementRef, notification: CFTypeRef) -> i32;
    pub fn CFRunLoopAddSource(rl: *mut c_void, source: *mut c_void, mode: CFTypeRef);
    pub fn CFRunLoopRemoveSource(rl: *mut c_void, source: *mut c_void, mode: CFTypeRef);
    pub fn AXObserverGetRunLoopSource(observer: AXObserverRef) -> *mut c_void;

    // CFAbsoluteTime
    pub fn CFAbsoluteTimeGetCurrent() -> f64;

    // CFRunLoopTimer
    pub fn CFRunLoopTimerCreate(
        allocator: *const c_void,
        fireDate: f64,
        interval: f64,
        flags: u32,
        order: i32,
        callout: extern "C" fn(*mut c_void, *mut c_void),
        context: *const CFRunLoopTimerContext,
    ) -> *mut c_void;
    pub fn CFRunLoopAddTimer(rl: *mut c_void, timer: *mut c_void, mode: CFTypeRef);

    // Display detection
    pub(crate) fn CGGetActiveDisplayList(max: u32, active: *mut u32, count: *mut u32) -> i32;

    // Window ID extraction
    pub fn _AXUIElementGetWindow(element: AXUIElementRef, out: *mut u32) -> i32;

    // CFArray functions for window enumeration
    pub fn CFArrayGetCount(theArray: CFTypeRef) -> i64;
    pub fn CFArrayGetValueAtIndex(theArray: CFTypeRef, idx: i64) -> *const c_void;

    // CFBoolean constants
    pub static kCFBooleanTrue: CFTypeRef;
    pub static kCFBooleanFalse: CFTypeRef;

    // Event tap functions
    pub fn CGEventTapCreate(
        tap: u32,
        place: u32,
        options: u32,
        events_of_interest: u64,
        callback: extern "C" fn(proxy: *mut c_void, event_type: u32, event: *mut c_void, context: *mut c_void) -> *mut c_void,
        context: *mut c_void,
    ) -> *mut c_void;
    pub fn CGEventTapEnable(tap: *mut c_void, enable: bool);
    pub fn CGEventTapIsEnabled(tap: *mut c_void) -> bool;
    pub fn CGEventGetIntegerValueField(event: *mut c_void, field: u32) -> i64;
    pub fn CGEventGetFlags(event: *mut c_void) -> u64;
    pub fn CGEventSetFlags(event: *mut c_void, flags: u64);
    pub fn CGEventCreateKeyboardEvent(source: *mut c_void, keycode: u16, key_down: bool) -> *mut c_void;
    pub fn CGEventPost(tap_location: u32, event: *mut c_void);
    pub fn CFMachPortCreateRunLoopSource(allocator: *const c_void, port: *const c_void, order: i32) -> *mut c_void;
}

// AppKit linking
#[link(name = "AppKit", kind = "framework")]
extern "C" {}

// AX constants
pub const KAX_ERROR_SUCCESS: i32 = 0;
#[allow(dead_code)]
pub const KAX_ERROR_PERMISSION_DENIED: i32 = -25204;
pub const KAX_ERROR_CANNOT_COMPLETE: i32 = -25205;
pub const KAX_ERROR_NOT_IMPLEMENTED: i32 = -25212;
pub(crate) const KAX_VALUE_TYPE_CGPOINT: i32 = 1;
pub(crate) const KAX_VALUE_TYPE_CGSIZE: i32 = 2;

// CFRunLoopTimerContext structure for timeout timer
#[repr(C)]
pub struct CFRunLoopTimerContext {
    pub version: i32,
    pub info: *mut c_void,
    pub retain: Option<extern "C" fn(*const c_void) -> *const c_void>,
    pub release: Option<extern "C" fn(*const c_void)>,
    pub copy_description: Option<extern "C" fn(*const c_void) -> *mut c_void>,
}

// Point structure used for both position and size in AX APIs
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub(crate) struct Pt { pub x: f64, pub y: f64 }

#[derive(Debug)]
pub enum AxError {
    Permission,
    Constrained,
    Platform(i32),
}

// RAII wrapper for AXUIElement
pub struct AxElement(pub AXUIElementRef);

impl AxElement {
    pub unsafe fn from_pid(pid: u32) -> Result<Self, AxError> {
        let app = AXUIElementCreateApplication(pid);
        if app.is_null() {
            Err(AxError::Platform(-1))
        } else {
            Ok(AxElement(app))
        }
    }

    pub unsafe fn focused_window(&self) -> Result<Self, AxError> {
        let mut win_ref: CFTypeRef = std::ptr::null();
        let attr = ax_attr_focused_window();
        let rc = AXUIElementCopyAttributeValue(self.0, attr.as_concrete_TypeRef() as CFTypeRef, &mut win_ref);
        if rc != KAX_ERROR_SUCCESS || win_ref.is_null() {
            Err(if rc == -25204 { AxError::Permission } else { AxError::Platform(rc) })
        } else {
            Ok(AxElement(win_ref as AXUIElementRef))
        }
    }

    pub unsafe fn set_size(&self, w: f64, h: f64) -> Result<(), AxError> {
        let size = Pt { x: w, y: h };
        let size_val = AXValueCreate(KAX_VALUE_TYPE_CGSIZE, &size as *const _ as *const _);
        if size_val.is_null() {
            return Err(AxError::Platform(-1));
        }

        let attr = ax_attr_size();
        let rc = AXUIElementSetAttributeValue(self.0, attr.as_concrete_TypeRef() as CFTypeRef, size_val as CFTypeRef);
        CFRelease(size_val as CFTypeRef);

        if rc != KAX_ERROR_SUCCESS {
            Err(if rc == -25204 { AxError::Permission } else { AxError::Constrained })
        } else {
            Ok(())
        }
    }

    pub unsafe fn set_position(&self, x: f64, y: f64) -> Result<(), AxError> {
        let pos = Pt { x, y };
        let pos_val = AXValueCreate(KAX_VALUE_TYPE_CGPOINT, &pos as *const _ as *const _);
        if pos_val.is_null() {
            return Err(AxError::Platform(-1));
        }

        let attr = ax_attr_position();
        let rc = AXUIElementSetAttributeValue(self.0, attr.as_concrete_TypeRef() as CFTypeRef, pos_val as CFTypeRef);
        CFRelease(pos_val as CFTypeRef);

        if rc != KAX_ERROR_SUCCESS {
            Err(if rc == -25204 { AxError::Permission } else { AxError::Platform(rc) })
        } else {
            Ok(())
        }
    }

    pub unsafe fn get_title(&self) -> Option<String> {
        let mut title_ref: CFTypeRef = std::ptr::null();
        let attr = ax_attr_title();
        let rc = AXUIElementCopyAttributeValue(self.0, attr.as_concrete_TypeRef() as CFTypeRef, &mut title_ref);

        if rc == KAX_ERROR_SUCCESS && !title_ref.is_null() {
            let cf_string = CFString::wrap_under_create_rule(title_ref as *const _);
            Some(cf_string.to_string())
        } else {
            None
        }
    }

    pub unsafe fn get_current_rect(&self) -> Option<crate::pbmbd_display::Rect> {
        // Get current position
        let mut pos_ref: CFTypeRef = std::ptr::null();
        let pos_attr = ax_attr_position();
        let pos_rc = AXUIElementCopyAttributeValue(self.0, pos_attr.as_concrete_TypeRef() as CFTypeRef, &mut pos_ref);

        // Get current size
        let mut size_ref: CFTypeRef = std::ptr::null();
        let size_attr = ax_attr_size();
        let size_rc = AXUIElementCopyAttributeValue(self.0, size_attr.as_concrete_TypeRef() as CFTypeRef, &mut size_ref);

        if pos_rc == KAX_ERROR_SUCCESS && size_rc == KAX_ERROR_SUCCESS && !pos_ref.is_null() && !size_ref.is_null() {
            // Extract position from AXValue
            let mut pos = Pt { x: 0.0, y: 0.0 };
            let pos_val = pos_ref as AXValueRef;
            let pos_ok = AXValueGetValue(pos_val, KAX_VALUE_TYPE_CGPOINT, &mut pos as *mut _ as *mut _);

            // Extract size from AXValue
            let mut size = Pt { x: 0.0, y: 0.0 };
            let size_val = size_ref as AXValueRef;
            let size_ok = AXValueGetValue(size_val, KAX_VALUE_TYPE_CGSIZE, &mut size as *mut _ as *mut _);

            CFRelease(pos_ref);
            CFRelease(size_ref);

            if pos_ok && size_ok {
                Some(crate::pbmbd_display::Rect { x: pos.x, y: pos.y, w: size.x, h: size.y })
            } else {
                None
            }
        } else {
            if !pos_ref.is_null() { CFRelease(pos_ref); }
            if !size_ref.is_null() { CFRelease(size_ref); }
            None
        }
    }

    pub unsafe fn get_role(&self) -> Option<String> {
        let mut role_ref: CFTypeRef = std::ptr::null();
        let attr = ax_attr_role();
        let rc = AXUIElementCopyAttributeValue(self.0, attr.as_concrete_TypeRef() as CFTypeRef, &mut role_ref);

        if rc == KAX_ERROR_SUCCESS && !role_ref.is_null() {
            let cf_string = CFString::wrap_under_create_rule(role_ref as *const _);
            Some(cf_string.to_string())
        } else {
            None
        }
    }

    pub unsafe fn get_window_id(&self) -> Option<u32> {
        let mut window_id: u32 = 0;
        let rc = _AXUIElementGetWindow(self.0, &mut window_id);
        if rc == KAX_ERROR_SUCCESS {
            Some(window_id)
        } else {
            None
        }
    }

}

impl Drop for AxElement {
    fn drop(&mut self) {
        unsafe {
            if !self.0.is_null() {
                CFRelease(self.0 as CFTypeRef);
            }
        }
    }
}

// CFString helpers - create on demand to avoid static initialization issues
pub unsafe fn ax_attr_focused_window() -> CFString {
    CFString::from_static_string("AXFocusedWindow")
}

pub unsafe fn ax_attr_position() -> CFString {
    CFString::from_static_string("AXPosition")
}

pub unsafe fn ax_attr_size() -> CFString {
    CFString::from_static_string("AXSize")
}

pub unsafe fn ax_attr_title() -> CFString {
    CFString::from_static_string("AXTitle")
}

pub unsafe fn ax_attr_role() -> CFString {
    CFString::from_static_string("AXRole")
}

pub unsafe fn ax_attr_windows() -> CFString {
    CFString::from_static_string("AXWindows")
}

pub unsafe fn ax_attr_minimized() -> CFString {
    CFString::from_static_string("AXMinimized")
}

pub unsafe fn ax_attr_main() -> CFString {
    CFString::from_static_string("AXMain")
}

pub unsafe fn ax_action_raise() -> CFString {
    CFString::from_static_string("AXRaise")
}

// Get complete frontmost app info (PID, bundle ID, name) via NSWorkspace
pub unsafe fn get_frontmost_app_info() -> Option<FrontmostInfo> {
    let workspace = NSWorkspace::sharedWorkspace();

    let frontmost_app = workspace.frontmostApplication()?;

    // Get PID - processIdentifier returns pid_t which is i32 on macOS
    // Note: Use i32 explicitly, not NSInteger which is i64 on 64-bit platforms
    let pid: i32 = msg_send![&frontmost_app, processIdentifier];
    if pid <= 0 {
        return None;
    }

    // Get bundle ID
    let bundle_id = match frontmost_app.bundleIdentifier() {
        Some(ns_str) => ns_str.to_string(),
        None => "<no_bundle_id>".to_string(),
    };

    // Get localized name
    let name = match frontmost_app.localizedName() {
        Some(ns_str) => ns_str.to_string(),
        None => "<no_app_name>".to_string(),
    };

    Some(FrontmostInfo {
        pid: pid as u32,
        bundle_id,
        name,
    })
}

// Get focused window information for a given PID
// Returns None if no focused window or if window is not AXWindow role
pub unsafe fn get_focused_window_info(pid: u32) -> Result<FocusedWindowInfo, AxError> {
    // Get app element
    let app = AxElement::from_pid(pid)?;

    // Get focused window
    let win = app.focused_window()?;

    // Check role - only accept AXWindow
    let role = win.get_role();
    if role.as_deref() != Some("AXWindow") {
        return Err(AxError::Platform(-1)); // Not a standard window
    }

    // Get window ID (required)
    let window_id = win.get_window_id().ok_or(AxError::Platform(-1))?;
    if window_id == 0 {
        return Err(AxError::Platform(-1)); // Invalid window ID
    }

    // Get window properties
    let title = win.get_title().unwrap_or_else(|| String::from("<no title>"));

    Ok(FocusedWindowInfo {
        window_id,
        title,
    })
}

pub fn check_ax_permissions() -> bool {
    unsafe {
        AXIsProcessTrustedWithOptions(std::ptr::null()).as_bool()
    }
}

pub unsafe fn ax_trusted_or_die() {
    if !check_ax_permissions() {
        eprintln!("Accessibility permission required. Grant it in System Settings → Privacy & Security → Accessibility, then restart.");
        std::process::exit(1);
    }
}

/// Validate that a window still exists and has AXWindow role
/// Used for MRU pruning to remove stale entries
/// Returns true if window exists and is a valid AXWindow, false otherwise
pub unsafe fn validate_window_exists(pid: u32, window_id: u32) -> bool {
    // Skip validation for placeholder entries (window_id=0)
    if window_id == 0 {
        return true;
    }

    // Create app element
    let app_element = AXUIElementCreateApplication(pid);
    if app_element.is_null() {
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
        CFRelease(app_element as CFTypeRef);
        return false;
    }

    // Iterate through CFArray to find target window
    let count = CFArrayGetCount(windows_array);
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
            // Found the window - now check its role
            let role_attr = ax_attr_role();
            let mut role_value: CFTypeRef = std::ptr::null();
            let role_rc = AXUIElementCopyAttributeValue(
                window_element,
                role_attr.as_concrete_TypeRef() as CFTypeRef,
                &mut role_value,
            );

            if role_rc == KAX_ERROR_SUCCESS && !role_value.is_null() {
                let role_cfstr = CFString::wrap_under_get_rule(role_value as *const _);
                let role_str = role_cfstr.to_string();
                found = role_str == "AXWindow";
                CFRelease(role_value);
            }
            break;
        }
    }

    // Cleanup
    CFRelease(windows_array);
    CFRelease(app_element as CFTypeRef);

    found
}