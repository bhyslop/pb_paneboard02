// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use std::sync::{Arc, Mutex};

// Clipboard history state
lazy_static::lazy_static! {
    pub static ref CLIPBOARD_HISTORY: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    pub static ref CLIPBOARD_SESSION: Arc<Mutex<ClipboardSession>> = Arc::new(Mutex::new(ClipboardSession::default()));
}

// Swift observer shim functions
extern "C" {
    // Clipboard monitoring functions
    fn pbmso_start_clipboard_monitor(
        callback: extern "C" fn(text: *const std::os::raw::c_char, length: i32),
    );

    fn pbmso_set_clipboard_text(text: *const std::os::raw::c_char);
}

#[derive(Debug, Clone)]
pub struct ClipboardSession {
    pub active: bool,           // Is Ctrl+Shift+V overlay active?
    pub highlight_index: Option<usize>,  // Current highlight position
}

impl Default for ClipboardSession {
    fn default() -> Self {
        Self {
            active: false,
            highlight_index: None,
        }
    }
}

/// Callback from Swift when clipboard changes
extern "C" fn clipboard_change_callback(text_ptr: *const std::os::raw::c_char, length: i32) {
    if text_ptr.is_null() || length == 0 {
        // Non-text content (ignore per spec)
        return;
    }

    unsafe {
        let text = std::ffi::CStr::from_ptr(text_ptr)
            .to_string_lossy()
            .to_string();

        // Store in history (deduplication: don't add if it's the same as the most recent)
        let mut history = CLIPBOARD_HISTORY.lock().unwrap();
        if history.is_empty() || history[0] != text {
            // Insert at front (most recent first)
            history.insert(0, text.clone());

            // Limit history to 50 entries
            if history.len() > 50 {
                history.truncate(50);
            }

            println!("CLIP: captured text | length={}", length);
        }
    }
}

/// Start clipboard monitoring
pub unsafe fn start_clipboard_monitoring() {
    pbmso_start_clipboard_monitor(clipboard_change_callback);
    eprintln!("DEBUG: Clipboard monitoring started");
}

/// Set clipboard text
pub unsafe fn set_clipboard_text(text: &str) {
    let c_text = std::ffi::CString::new(text).unwrap();
    pbmso_set_clipboard_text(c_text.as_ptr());
}

// ============================================================================================
// Clipboard Overlay Functions
// ============================================================================================

use crate::pbmbo_overlay::{
    strings_to_ffi,
    pbmbo_show_clipboard_overlay,
    pbmbo_update_clipboard_highlight,
    pbmbo_hide_clipboard_overlay,
};

/// Show clipboard history overlay with current entries
pub unsafe fn show_clipboard_overlay() {
    let history = CLIPBOARD_HISTORY.lock().unwrap();

    if history.is_empty() {
        println!("CLIP: overlay shown | entries=0");
        // Still show overlay with "(no clipboard history)" message
        let empty_entries: Vec<*const std::os::raw::c_char> = Vec::new();
        pbmbo_show_clipboard_overlay(empty_entries.as_ptr(), 0, 0);
        return;
    }

    // Convert entries to C strings using new helper
    let entries: Vec<String> = history.clone();
    let (_c_strings, c_ptrs) = strings_to_ffi(&entries);

    let mut session = CLIPBOARD_SESSION.lock().unwrap();
    session.active = true;
    session.highlight_index = Some(0); // Start at first entry

    println!("CLIP: overlay shown | entries={}", history.len());

    pbmbo_show_clipboard_overlay(
        c_ptrs.as_ptr(),
        history.len() as i32,
        0,
    );
}

/// Hide clipboard overlay and cleanup session
pub unsafe fn hide_clipboard_overlay() {
    pbmbo_hide_clipboard_overlay();

    let mut session = CLIPBOARD_SESSION.lock().unwrap();
    session.active = false;
    session.highlight_index = None;
}

/// Navigate clipboard history (up/down arrows or Enter to select)
pub unsafe fn handle_clipboard_navigation(keycode: u16) {
    let mut session = CLIPBOARD_SESSION.lock().unwrap();
    let history = CLIPBOARD_HISTORY.lock().unwrap();

    if history.is_empty() {
        return;
    }

    let current_idx = session.highlight_index.unwrap_or(0);

    match keycode {
        126 => { // Up arrow
            if current_idx > 0 {
                session.highlight_index = Some(current_idx - 1);
            }
        }
        125 => { // Down arrow
            if current_idx < history.len() - 1 {
                session.highlight_index = Some(current_idx + 1);
            }
        }
        36 => { // Enter - paste selected entry
            let selected_text = history[current_idx].clone();
            drop(history);
            drop(session);

            // Set clipboard to selected text
            set_clipboard_text(&selected_text);

            println!("CLIP: pasted historic | index={} | length={}", current_idx, selected_text.len());

            // Hide overlay
            hide_clipboard_overlay();
            return;
        }
        53 => { // Escape - cancel
            drop(history);
            drop(session);
            hide_clipboard_overlay();
            return;
        }
        _ => {}
    }

    // Update highlight if index changed
    if let Some(new_idx) = session.highlight_index {
        if new_idx != current_idx {
            // Use new helper for FFI conversion
            let entries: Vec<String> = history.clone();
            let (_c_strings, c_ptrs) = strings_to_ffi(&entries);

            pbmbo_update_clipboard_highlight(
                c_ptrs.as_ptr(),
                history.len() as i32,
                new_idx as i32,
            );
        }
    }
}