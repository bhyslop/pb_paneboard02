// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use objc2::msg_send;
use objc2::encode::{Encode, RefEncode};
use objc2::runtime::AnyObject;
use objc2_foundation::MainThreadMarker;
use objc2_app_kit::{NSScreen, NSApplication};

// Import CGGetActiveDisplayList from pbmba_ax
use crate::pbmba_ax::CGGetActiveDisplayList;

// Rect structure for window dimensions
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64
}

// Point structure (used internally)
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub(crate) struct Pt {
    pub x: f64,
    pub y: f64
}

// Visible frame structure for display dimensions
#[derive(Copy, Clone, Debug)]
pub struct VisibleFrame {
    pub min_x: f64,
    pub min_y: f64,
    pub width: f64,
    pub height: f64
}

// NSRect structure for Objective-C interop
#[repr(C)]
#[derive(Copy, Clone)]
struct NSRect {
    origin: Pt,
    size: Pt,  // reuse Pt for {width, height}
}

// Use objc2::encode to make NSRect encodable
// Note: Must use "CGRect" not "NSRect" - the Objective-C runtime uses CoreGraphics naming
unsafe impl Encode for NSRect {
    const ENCODING: objc2::encode::Encoding = objc2::encode::Encoding::Struct(
        "CGRect",
        &[
            objc2::encode::Encoding::Struct("CGPoint", &[<f64 as Encode>::ENCODING, <f64 as Encode>::ENCODING]),
            objc2::encode::Encoding::Struct("CGSize", &[<f64 as Encode>::ENCODING, <f64 as Encode>::ENCODING]),
        ],
    );
}

unsafe impl RefEncode for NSRect {
    const ENCODING_REF: objc2::encode::Encoding = Self::ENCODING;
}

// Get the visible frame of the main display
#[allow(unexpected_cfgs)]
pub unsafe fn visible_frame_main_display() -> Option<VisibleFrame> {
    // SAFETY: This function is called on the main thread during event handling
    let mtm = unsafe { MainThreadMarker::new_unchecked() };
    let ns_screen = NSScreen::mainScreen(mtm)?;

    let rect: NSRect = msg_send![&ns_screen, visibleFrame];

    Some(VisibleFrame {
        min_x: rect.origin.x,
        min_y: rect.origin.y,
        width: rect.size.x,
        height: rect.size.y,
    })
}

// Note if there are multiple displays
#[allow(dead_code)]
pub fn note_if_multi_display() {
    unsafe {
        let mut count: u32 = 0;
        let _ = CGGetActiveDisplayList(0, std::ptr::null_mut(), &mut count);
        if count > 1 {
            eprintln!("NOTE: {} displays detected.", count);
        }
    }
}

// Get the system menu bar height
// Returns the height in points (typically 25-31 depending on display scaling)
#[allow(unexpected_cfgs)]
pub unsafe fn get_menu_bar_height() -> f64 {
    let mtm = unsafe { MainThreadMarker::new_unchecked() };
    let app = NSApplication::sharedApplication(mtm);

    // Try to get menu bar height from the main menu
    let main_menu: *mut AnyObject = msg_send![&app, mainMenu];
    if !main_menu.is_null() {
        let height: f64 = msg_send![main_menu, menuBarHeight];
        if height > 0.0 {
            return height;
        }
    }

    // Fallback: calculate from main screen's frame vs visibleFrame difference
    if let Some(main_screen) = NSScreen::mainScreen(mtm) {
        let frame: NSRect = msg_send![&main_screen, frame];
        let visible: NSRect = msg_send![&main_screen, visibleFrame];

        // Menu bar height is the difference between frame height and visible height
        // (accounting for both menu bar at top and dock at bottom)
        let top_offset = visible.origin.y - frame.origin.y;
        if top_offset > 0.0 {
            return top_offset;
        }

        // If no offset detected, calculate from height difference
        // This is less reliable but better than nothing
        let height_diff = frame.size.y - visible.size.y;
        if height_diff > 0.0 {
            // Assume menu bar is roughly 25-31 pixels, dock is variable
            // This is a rough heuristic
            return height_diff.min(31.0);
        }
    }

    // Last resort fallback: standard menu bar height
    25.0
}

// Get all screens in NSScreen enumeration order
#[allow(unexpected_cfgs)]
pub unsafe fn get_all_screens() -> Vec<objc2::rc::Retained<objc2_app_kit::NSScreen>> {
    let mtm = unsafe { MainThreadMarker::new_unchecked() };
    let screens = NSScreen::screens(mtm);

    let mut result = Vec::new();
    for i in 0..screens.len() {
        let screen = screens.objectAtIndex(i);
        result.push(screen.clone());
    }
    result
}

// Get visible frame for a specific screen
#[allow(unexpected_cfgs)]
pub unsafe fn visible_frame_for_screen(screen: &NSScreen) -> Option<VisibleFrame> {
    let rect: NSRect = msg_send![screen, visibleFrame];

    Some(VisibleFrame {
        min_x: rect.origin.x,
        min_y: rect.origin.y,
        width: rect.size.x,
        height: rect.size.y,
    })
}

// DisplayInfo for layout configuration system
#[derive(Debug, Clone)]
pub struct DisplayInfo {
    pub index: usize,
    pub width: f64,
    pub height: f64,
    pub name: String,
}

// Gather all display information for layout system initialization
#[allow(unexpected_cfgs)]
pub unsafe fn gather_all_display_info() -> Vec<DisplayInfo> {
    let screens = get_all_screens();
    let mut displays = Vec::new();

    for (idx, screen) in screens.iter().enumerate() {
        if let Some(vf) = visible_frame_for_screen(screen) {
            // Get localized name
            use objc2::msg_send;
            use objc2_foundation::NSString;
            let name_ptr: *const NSString = msg_send![screen, localizedName];
            let name = if !name_ptr.is_null() {
                let name_str = unsafe { &*name_ptr };
                name_str.to_string()
            } else {
                format!("Display {}", idx)
            };

            displays.push(DisplayInfo {
                index: idx,
                width: vf.width,
                height: vf.height,
                name,
            });
        }
    }

    displays
}

// Get full frame (not visible frame) for a specific screen
#[allow(unexpected_cfgs)]
pub unsafe fn full_frame_for_screen(screen: &NSScreen) -> Option<VisibleFrame> {
    let rect: NSRect = msg_send![screen, frame];

    Some(VisibleFrame {
        min_x: rect.origin.x,
        min_y: rect.origin.y,
        width: rect.size.x,
        height: rect.size.y,
    })
}

// Get display info with both visible frame and full frame for validation
// Returns (corrected_visible_frame, full_frame, delta_y)
// Applies menu bar correction when visibleFrame.minY == frame.minY
pub unsafe fn get_display_for_window_with_validation(window_rect: Rect) -> Option<(VisibleFrame, VisibleFrame, f64)> {
    let screens = get_all_screens();
    if screens.is_empty() {
        return None;
    }

    let menu_bar_height = get_menu_bar_height();

    let win_center_x = window_rect.x + window_rect.w / 2.0;
    let win_center_y = window_rect.y + window_rect.h / 2.0;

    // Find which screen contains the window center
    for screen in &screens {
        if let Some(mut vf) = visible_frame_for_screen(screen) {
            if win_center_x >= vf.min_x && win_center_x < vf.min_x + vf.width &&
               win_center_y >= vf.min_y && win_center_y < vf.min_y + vf.height {
                if let Some(ff) = full_frame_for_screen(screen) {
                    let original_delta_y = vf.min_y - ff.min_y;

                    // Apply menu bar correction if visibleFrame claims to start at same y as frame
                    // (macOS bug: visibleFrame doesn't account for reserved menu bar space)
                    if original_delta_y == 0.0 {
                        eprintln!("DEBUG: Applying menu bar correction (height={:.0}px)", menu_bar_height);
                        vf.min_y += menu_bar_height;
                        vf.height -= menu_bar_height;
                    }

                    let corrected_delta_y = vf.min_y - ff.min_y;
                    return Some((vf, ff, corrected_delta_y));
                }
                return None;
            }
        }
    }

    // Fallback to main display
    let mtm = MainThreadMarker::new_unchecked();
    if let Some(main_screen) = NSScreen::mainScreen(mtm) {
        if let (Some(mut vf), Some(ff)) = (visible_frame_for_screen(&main_screen), full_frame_for_screen(&main_screen)) {
            let original_delta_y = vf.min_y - ff.min_y;

            // Apply menu bar correction if needed
            if original_delta_y == 0.0 {
                eprintln!("DEBUG: Applying menu bar correction (height={:.0}px)", menu_bar_height);
                vf.min_y += menu_bar_height;
                vf.height -= menu_bar_height;
            }

            let corrected_delta_y = vf.min_y - ff.min_y;
            return Some((vf, ff, corrected_delta_y));
        }
    }
    None
}

// ===== CGDisplay FFI declarations for detailed display information =====

#[repr(C)]
#[derive(Copy, Clone, Debug)]
struct CGSize {
    width: f64,
    height: f64,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
#[allow(dead_code)]
struct CGRect {
    origin: Pt,
    size: CGSize,
}

#[link(name = "CoreGraphics", kind = "framework")]
extern "C" {
    fn CGMainDisplayID() -> u32;
    fn CGDisplayIsMain(display: u32) -> bool;
    fn CGDisplayIsBuiltin(display: u32) -> bool;
    fn CGDisplayIsActive(display: u32) -> bool;
    fn CGDisplayIsOnline(display: u32) -> bool;
    fn CGDisplayIsAsleep(display: u32) -> bool;
    fn CGDisplaySerialNumber(display: u32) -> u32;
    fn CGDisplayUnitNumber(display: u32) -> u32;
    fn CGDisplayVendorNumber(display: u32) -> u32;
    fn CGDisplayModelNumber(display: u32) -> u32;
    fn CGDisplayRotation(display: u32) -> f64;
    fn CGDisplayScreenSize(display: u32) -> CGSize;
    #[allow(dead_code)]
    fn CGDisplayBounds(display: u32) -> CGRect;
    fn CGDisplayCopyDisplayMode(display: u32) -> *mut std::ffi::c_void;
    fn CGDisplayModeGetWidth(mode: *mut std::ffi::c_void) -> usize;
    fn CGDisplayModeGetHeight(mode: *mut std::ffi::c_void) -> usize;
    fn CGDisplayModeGetPixelWidth(mode: *mut std::ffi::c_void) -> usize;
    fn CGDisplayModeGetPixelHeight(mode: *mut std::ffi::c_void) -> usize;
    fn CGDisplayModeGetRefreshRate(mode: *mut std::ffi::c_void) -> f64;
    fn CGDisplayModeRelease(mode: *mut std::ffi::c_void);
}

// Print comprehensive information about all connected displays
#[allow(unexpected_cfgs)]
pub unsafe fn print_all_display_info() {
    let _mtm = MainThreadMarker::new_unchecked();
    let screens = get_all_screens();

    if screens.is_empty() {
        eprintln!("No displays detected");
        return;
    }

    let _main_display_id = CGMainDisplayID();

    eprintln!("\n========== CONNECTED DISPLAYS ==========");

    for (idx, screen) in screens.iter().enumerate() {
        eprintln!("\n--- Display {} ---", idx);

        // Get localized name (macOS 10.15+)
        {
            use objc2::msg_send;
            use objc2_foundation::NSString;
            let name: *const NSString = msg_send![screen, localizedName];
            if !name.is_null() {
                let name_str = unsafe { &*name };
                eprintln!("  Name: {}", name_str);
            } else {
                eprintln!("  Name: <unavailable>");
            }
        }

        // Get CGDirectDisplayID from device description
        let device_desc = screen.deviceDescription();
        let display_id: u32 = {
            use objc2::msg_send;
            use objc2_foundation::NSNumber;
            let key = objc2_foundation::ns_string!("NSScreenNumber");
            let screen_num: *const NSNumber = msg_send![&device_desc, objectForKey: key];
            if !screen_num.is_null() {
                let num_value: u32 = msg_send![screen_num, unsignedIntValue];
                num_value
            } else {
                0
            }
        };

        eprintln!("  Display ID: {} (0x{:x})", display_id, display_id);

        // Display state flags
        let is_main = CGDisplayIsMain(display_id);
        let is_builtin = CGDisplayIsBuiltin(display_id);
        let is_active = CGDisplayIsActive(display_id);
        let is_online = CGDisplayIsOnline(display_id);
        let is_asleep = CGDisplayIsAsleep(display_id);

        eprintln!("  Main: {}, Built-in: {}, Active: {}, Online: {}, Asleep: {}",
                  is_main, is_builtin, is_active, is_online, is_asleep);

        // Geometry from NSScreen
        let frame: NSRect = msg_send![screen, frame];
        let visible: NSRect = msg_send![screen, visibleFrame];

        eprintln!("  Frame (NSScreen): ({:.0}, {:.0}, {:.0}, {:.0})",
                  frame.origin.x, frame.origin.y, frame.size.x, frame.size.y);
        eprintln!("  Visible Frame: ({:.0}, {:.0}, {:.0}, {:.0})",
                  visible.origin.x, visible.origin.y, visible.size.x, visible.size.y);

        // Backing scale factor (Retina)
        let scale: f64 = msg_send![screen, backingScaleFactor];
        eprintln!("  Backing Scale Factor: {:.1}x", scale);

        // Resolution in points and pixels
        let points_w = frame.size.x;
        let points_h = frame.size.y;
        let pixels_w = points_w * scale;
        let pixels_h = points_h * scale;

        eprintln!("  Resolution: {:.0}x{:.0} points ({:.0}x{:.0} pixels)",
                  points_w, points_h, pixels_w, pixels_h);

        // CGDisplay mode information (more accurate pixel dimensions and refresh rate)
        if display_id != 0 {
            let mode = CGDisplayCopyDisplayMode(display_id);
            if !mode.is_null() {
                let mode_width = CGDisplayModeGetWidth(mode);
                let mode_height = CGDisplayModeGetHeight(mode);
                let pixel_width = CGDisplayModeGetPixelWidth(mode);
                let pixel_height = CGDisplayModeGetPixelHeight(mode);
                let refresh_rate = CGDisplayModeGetRefreshRate(mode);

                eprintln!("  Display Mode: {}x{} points, {}x{} pixels",
                          mode_width, mode_height, pixel_width, pixel_height);

                if refresh_rate > 0.0 {
                    eprintln!("  Refresh Rate: {:.2} Hz", refresh_rate);
                } else {
                    eprintln!("  Refresh Rate: default/adaptive");
                }

                CGDisplayModeRelease(mode);
            }

            // Rotation
            let rotation = CGDisplayRotation(display_id);
            if rotation != 0.0 {
                eprintln!("  Rotation: {:.0}°", rotation);
            } else {
                eprintln!("  Rotation: 0° (normal)");
            }

            // Physical size
            let phys_size = CGDisplayScreenSize(display_id);
            if phys_size.width > 0.0 && phys_size.height > 0.0 {
                eprintln!("  Physical Size: {:.1}mm x {:.1}mm ({:.1}\" diagonal)",
                          phys_size.width, phys_size.height,
                          ((phys_size.width * phys_size.width + phys_size.height * phys_size.height).sqrt() / 25.4));
            } else {
                eprintln!("  Physical Size: <unavailable>");
            }

            // Hardware identifiers
            let serial = CGDisplaySerialNumber(display_id);
            let vendor = CGDisplayVendorNumber(display_id);
            let model = CGDisplayModelNumber(display_id);
            let unit = CGDisplayUnitNumber(display_id);

            eprintln!("  Hardware IDs: Vendor=0x{:x}, Model=0x{:x}, Serial=0x{:x}, Unit={}",
                      vendor, model, serial, unit);

            // Color depth from device description
            {
                use objc2::msg_send;
                use objc2_foundation::NSNumber;
                let key = objc2_foundation::ns_string!("NSDeviceBitsPerSample");
                let bits_per_sample: *const NSNumber = msg_send![&device_desc, objectForKey: key];
                if !bits_per_sample.is_null() {
                    let bits: i64 = msg_send![bits_per_sample, integerValue];
                    eprintln!("  Color Depth: {} bits per sample", bits);
                }
            }

            // Color space
            if let Some(color_space) = screen.colorSpace() {
                if let Some(name) = color_space.localizedName() {
                    eprintln!("  Color Space: {}", name);
                }
            }

            // EDR capabilities (macOS 10.15+)
            let max_edr: f64 = msg_send![screen, maximumPotentialExtendedDynamicRangeColorComponentValue];
            if max_edr > 1.0 {
                eprintln!("  Max EDR: {:.1}x (Extended Dynamic Range capable)", max_edr);
            }
        }
    }

    eprintln!("\n========================================\n");
}