// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use core_foundation::base::{CFRelease, TCFType};
use core_foundation::runloop::kCFRunLoopDefaultMode;
use core_foundation::string::CFString;
use core_foundation_sys::base::CFTypeRef;
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use crate::pbmba_ax::{
    get_focused_window_info, AXUIElementRef, AXObserverRef, AXObserverCallback,
    AXUIElementCreateApplication, AXObserverCreate,
    AXObserverAddNotification,
    AXObserverGetRunLoopSource, CFRunLoopAddSource, CFRunLoopRemoveSource,
    CFRunLoopGetCurrent,
};
use crate::pbmp_pane::{enumerate_app_windows};
use crate::pbmsm_mru::{
    update_mru_with_focus, add_enumerated_window_to_mru,
    add_app_to_mru_as_guess, MRU_STACK, ActivationState,
};

const KAX_ERROR_SUCCESS: i32 = 0;

// Swift observer shim (compiled by build.rs)
extern "C" {
    fn pbmso_register_observer(
        activation_callback: extern "C" fn(pid: i32, bundle: *const std::os::raw::c_char, name: *const std::os::raw::c_char),
        termination_callback: extern "C" fn(pid: i32),
    );

    fn pbmso_prepopulate_mru(
        prepopulation_callback: extern "C" fn(pid: i32, bundle: *const std::os::raw::c_char, name: *const std::os::raw::c_char, is_known: bool),
    );
}

// Wrapper for AXObserverRef that implements Send (unsafe but necessary for cross-thread storage)
struct SendObserver(AXObserverRef);
unsafe impl Send for SendObserver {}

// Track active per-app AXObservers (PID → AXObserverRef)
lazy_static::lazy_static! {
    static ref ACTIVE_OBSERVERS: Arc<Mutex<std::collections::HashMap<u32, SendObserver>>> =
        Arc::new(Mutex::new(std::collections::HashMap::new()));

    // Track PID → bundle_id mappings for observer callbacks
    static ref PID_TO_BUNDLE: Arc<Mutex<std::collections::HashMap<u32, String>>> =
        Arc::new(Mutex::new(std::collections::HashMap::new()));
}

// Global system-wide observer for MRU tracking
static MRU_OBSERVER: AtomicBool = AtomicBool::new(false);

// Per-app AXObserver callback for window-level focus changes
extern "C" fn window_focus_callback(
    _observer: AXObserverRef,
    _element: AXUIElementRef,
    _notification: CFTypeRef,
    refcon: *mut c_void,
) {
    unsafe {
        // refcon contains the PID
        let pid = refcon as u32;

        // Get bundle ID from our mapping
        let bundle_id = {
            let bundle_map = PID_TO_BUNDLE.lock().unwrap();
            bundle_map.get(&pid).cloned().unwrap_or_else(|| format!("<pid:{}>", pid))
        };

        eprintln!("DEBUG: [AXFocusedWindow] Window focus changed in app pid={} ({})", pid, bundle_id);

        // Update MRU with the focused window
        // The element passed is the window element that received focus
        update_mru_with_focus(pid, bundle_id);
    }
}

/// Create AXObserver for a specific app to track window focus changes
pub unsafe fn create_observer_for_app(pid: u32, bundle_id: String) -> Result<(), String> {
    // Check if we already have an observer for this PID
    {
        let observers = ACTIVE_OBSERVERS.lock().unwrap();
        if observers.contains_key(&pid) {
            eprintln!("DEBUG: [AXObserver] Observer already exists for pid={}", pid);
            return Ok(());
        }
    }

    // Create AXObserver for this app
    let mut observer: AXObserverRef = std::ptr::null();
    let callback: AXObserverCallback = window_focus_callback;
    let create_rc = AXObserverCreate(pid as i32, callback, &mut observer);

    if create_rc != KAX_ERROR_SUCCESS {
        return Err(format!("Failed to create AXObserver for pid={}: error={}", pid, create_rc));
    }

    // Get the app element
    let app_element = AXUIElementCreateApplication(pid);
    if app_element.is_null() {
        return Err(format!("Failed to create app element for pid={}", pid));
    }

    // Register for AXFocusedWindowChanged notification
    let notif_name = CFString::from_static_string("AXFocusedWindowChanged");
    let add_rc = AXObserverAddNotification(
        observer,
        app_element,
        notif_name.as_concrete_TypeRef() as CFTypeRef,
        pid as *mut c_void, // Pass PID as refcon
    );

    CFRelease(app_element as CFTypeRef);

    if add_rc != KAX_ERROR_SUCCESS {
        CFRelease(observer as CFTypeRef);
        return Err(format!("Failed to add notification for pid={}: error={}", pid, add_rc));
    }

    // Add observer to runloop
    let runloop_source = AXObserverGetRunLoopSource(observer);
    if runloop_source.is_null() {
        CFRelease(observer as CFTypeRef);
        return Err(format!("Failed to get runloop source for pid={}", pid));
    }

    CFRunLoopAddSource(
        CFRunLoopGetCurrent(),
        runloop_source,
        kCFRunLoopDefaultMode as *mut c_void,
    );

    // Store observer
    {
        let mut observers = ACTIVE_OBSERVERS.lock().unwrap();
        observers.insert(pid, SendObserver(observer));
    }

    // Store bundle_id mapping
    {
        let mut bundle_map = PID_TO_BUNDLE.lock().unwrap();
        bundle_map.insert(pid, bundle_id.clone());
    }

    eprintln!("DEBUG: [AXObserver] Created observer for pid={} ({})", pid, bundle_id);

    Ok(())
}

/// Remove AXObserver for an app that terminated
pub unsafe fn remove_observer_for_app(pid: u32) {
    let mut observers = ACTIVE_OBSERVERS.lock().unwrap();

    if let Some(SendObserver(observer)) = observers.remove(&pid) {
        // Remove from runloop
        let runloop_source = AXObserverGetRunLoopSource(observer);
        if !runloop_source.is_null() {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                runloop_source,
                kCFRunLoopDefaultMode as CFTypeRef,
            );
        }

        // Release observer
        CFRelease(observer as CFTypeRef);

        eprintln!("DEBUG: [AXObserver] Removed observer for pid={}", pid);
    }

    // Remove bundle_id mapping
    {
        let mut bundle_map = PID_TO_BUNDLE.lock().unwrap();
        bundle_map.remove(&pid);
    }
}

/// Setup system-wide AXObserver for MRU tracking
/// This subscribes to focus changes across all apps
pub unsafe fn setup_mru_observer() -> Result<(), String> {
    if MRU_OBSERVER.swap(true, Ordering::SeqCst) {
        return Ok(()); // Already setup
    }

    eprintln!("DEBUG: Setting up system-wide MRU observer");
    eprintln!("DEBUG: Prepopulating MRU with running applications...");

    // Prepopulate MRU with currently running apps
    pbmso_prepopulate_mru(prepopulation_callback);

    eprintln!("DEBUG: Prepopulation complete, MRU stack size={}", MRU_STACK.lock().unwrap().len());

    Ok(())
}

// C callback invoked by Swift shim on app activation
extern "C" fn focus_change_callback(pid: i32, bundle: *const std::os::raw::c_char, name: *const std::os::raw::c_char) {
    unsafe {
        use std::ffi::CStr;

        // Convert C strings to Rust strings
        let bundle_id = if bundle.is_null() {
            String::from("<no_bundle_id>")
        } else {
            CStr::from_ptr(bundle).to_string_lossy().into_owned()
        };

        let app_name = if name.is_null() {
            String::from("<no_name>")
        } else {
            CStr::from_ptr(name).to_string_lossy().into_owned()
        };

        eprintln!("DEBUG: [NSWorkspace] App activated: {} (pid={}, name={})", bundle_id, pid, app_name);

        // Update MRU stack with current window
        update_mru_with_focus(pid as u32, bundle_id.clone());

        // Create AXObserver for this app to track window-level focus changes
        if let Err(e) = create_observer_for_app(pid as u32, bundle_id) {
            eprintln!("DEBUG: [AXObserver] Failed to create observer: {}", e);
        }
    }
}

// C callback invoked by Swift shim on app termination
extern "C" fn app_terminated_callback(pid: i32) {
    unsafe {
        eprintln!("DEBUG: [NSWorkspace] App terminated: pid={}", pid);

        // Remove from MRU stack (regardless of KNOWN/GUESS state)
        let mut stack = MRU_STACK.lock().unwrap();
        let before_len = stack.len();
        stack.retain(|e| e.identity.pid != pid as u32);
        let after_len = stack.len();

        if before_len != after_len {
            eprintln!("DEBUG: [MRU] Removed entry for pid={} from MRU stack", pid);
        }

        // Remove AXObserver if any
        remove_observer_for_app(pid as u32);
    }
}

// C callback invoked during prepopulation
extern "C" fn prepopulation_callback(pid: i32, bundle: *const std::os::raw::c_char, name: *const std::os::raw::c_char, is_known: bool) {
    unsafe {
        use std::ffi::CStr;

        // Convert C strings to Rust strings
        let bundle_id = if bundle.is_null() {
            String::from("<no_bundle_id>")
        } else {
            CStr::from_ptr(bundle).to_string_lossy().into_owned()
        };

        let app_name = if name.is_null() {
            String::from("<no_name>")
        } else {
            CStr::from_ptr(name).to_string_lossy().into_owned()
        };

        eprintln!("DEBUG: [Prepopulation] {} {} (pid={}, name={})",
                  if is_known { "KNOWN:" } else { "GUESS:" }, bundle_id, pid, app_name);

        // Enumerate all windows for this app
        let windows = enumerate_app_windows(pid as u32);

        if windows.is_empty() {
            // No windows found - add placeholder entry with window_id=0
            eprintln!("DEBUG: [Prepopulation] No windows enumerated for {} (pid={}), adding placeholder",
                     bundle_id, pid);
            add_app_to_mru_as_guess(pid as u32, bundle_id.clone(), app_name);
        } else {
            // Windows found - add each to MRU
            if is_known {
                // Frontmost app: enumerate all windows, mark focused window as KNOWN
                // First, try to get the focused window ID using shared helper
                let focused_window_id = get_focused_window_info(pid as u32)
                    .ok()
                    .map(|info| info.window_id);

                // Add all windows, marking the focused one as KNOWN
                for enumerated_win in windows {
                    if Some(enumerated_win.window_id) == focused_window_id {
                        // This is the focused window - add as KNOWN
                        use crate::pbmsm_mru::{WindowIdentity, MruWindowEntry};

                        let identity = WindowIdentity {
                            pid: pid as u32,
                            window_id: enumerated_win.window_id,
                        };

                        let entry = MruWindowEntry {
                            identity: identity.clone(),
                            bundle_id: bundle_id.clone(),
                            title: enumerated_win.title.clone(),
                            activation_state: ActivationState::Known,
                        };

                        let mut stack = MRU_STACK.lock().unwrap();
                        stack.insert(0, entry);
                        eprintln!("DEBUG: Added KNOWN window entry for {} (pid={}, window_id={})",
                                 bundle_id, pid, enumerated_win.window_id);
                    } else {
                        // Other windows - add as GUESS
                        add_enumerated_window_to_mru(pid as u32, bundle_id.clone(), &enumerated_win);
                    }
                }
            } else {
                // Non-frontmost app: add all windows as GUESS
                for enumerated_win in windows {
                    add_enumerated_window_to_mru(pid as u32, bundle_id.clone(), &enumerated_win);
                }
            }
        }

        // Create AXObserver for this app to track window-level focus changes
        if let Err(e) = create_observer_for_app(pid as u32, bundle_id) {
            eprintln!("DEBUG: [AXObserver] Failed to create observer during prepopulation: {}", e);
        }
    }
}

/// Setup NSWorkspace notification for app activation/termination
/// This is called from main after runloop setup
pub unsafe fn setup_workspace_observer() {
    eprintln!("DEBUG: Registering Swift-based observer...");
    pbmso_register_observer(focus_change_callback, app_terminated_callback);
    eprintln!("DEBUG: Observer registered successfully");
}