// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

use std::sync::{Arc, Mutex};
use crate::pbmba_ax::{get_focused_window_info, get_frontmost_app_info};
use crate::pbmbd_display::Rect;

// MRU window tracking
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct WindowIdentity {
    pub pid: u32,
    pub window_id: u32, // CGWindowNumber or synthesized ID
}

// Activation state for MRU entries
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ActivationState {
    Known,  // Confirmed by activation event
    Guess,  // Discovered during prepopulation, not yet confirmed
}

#[derive(Clone, Debug)]
pub struct MruWindowEntry {
    pub identity: WindowIdentity,
    pub bundle_id: String,
    pub title: String,
    pub role: Option<String>,
    pub subrole: Option<String>,
    pub rect: Option<Rect>,
    pub is_fullscreen: bool,
    pub is_minimized: bool,
    pub activation_state: ActivationState,
}

// Global MRU stack (most recent at front)
lazy_static::lazy_static! {
    pub static ref MRU_STACK: Arc<Mutex<Vec<MruWindowEntry>>> = Arc::new(Mutex::new(Vec::new()));
}

/// Update MRU stack with focused window
/// Called whenever focus changes
pub unsafe fn update_mru_with_focus(pid: u32, bundle_id: String) {
    // Get focused window info using shared helper
    let win_info = match get_focused_window_info(pid) {
        Ok(info) => info,
        Err(_) => return, // No focused window or not AXWindow
    };

    let identity = WindowIdentity { pid, window_id: win_info.window_id };

    let entry = MruWindowEntry {
        identity: identity.clone(),
        bundle_id: bundle_id.clone(),
        title: win_info.title,
        role: win_info.role,
        subrole: win_info.subrole,
        rect: win_info.rect,
        is_fullscreen: win_info.is_fullscreen,
        is_minimized: win_info.is_minimized,
        activation_state: ActivationState::Known,
    };

    // Update MRU stack: check if we're flipping GUESS → KNOWN
    let mut stack = MRU_STACK.lock().unwrap();

    // Check if there's a GUESS placeholder entry for this PID (window_id=0)
    let had_guess_placeholder = stack.iter().any(|e| {
        e.identity.pid == pid && e.identity.window_id == 0 && e.activation_state == ActivationState::Guess
    });

    if had_guess_placeholder {
        eprintln!("DEBUG: [MRU] Flipping GUESS placeholder → KNOWN for {} window_id={} (pid={})",
                  bundle_id, win_info.window_id, pid);
    }

    // Remove placeholder entries (window_id=0) for this PID - these are from prepopulation
    stack.retain(|e| !(e.identity.pid == pid && e.identity.window_id == 0));

    // Remove any existing entry for this specific window
    stack.retain(|e| e.identity != identity);

    // Insert new KNOWN entry at front
    stack.insert(0, entry);

    eprintln!("DEBUG: MRU updated, stack size={}", stack.len());
}

/// Get current MRU snapshot
pub fn get_mru_snapshot() -> Vec<MruWindowEntry> {
    let stack = MRU_STACK.lock().unwrap();
    stack.clone()
}

/// Add enumerated window to MRU as GUESS (used during prepopulation)
pub unsafe fn add_enumerated_window_to_mru(
    pid: u32,
    bundle_id: String,
    enumerated_win: &crate::pbmp_pane::EnumeratedWindow,
) {
    let identity = WindowIdentity {
        pid,
        window_id: enumerated_win.window_id,
    };

    let entry = MruWindowEntry {
        identity: identity.clone(),
        bundle_id: bundle_id.clone(),
        title: enumerated_win.title.clone(),
        role: enumerated_win.role.clone(),
        subrole: None,
        rect: None,
        is_fullscreen: false,
        is_minimized: false,
        activation_state: ActivationState::Guess,
    };

    let mut stack = MRU_STACK.lock().unwrap();
    // Don't add if this entry already exists (avoid duplicates)
    if !stack.iter().any(|e| e.identity == identity) {
        stack.push(entry);
        eprintln!("DEBUG: Added GUESS window entry for {} (pid={}, window_id={})",
                  bundle_id, pid, enumerated_win.window_id);
    }
}

/// Add app to MRU without checking for window (used during prepopulation)
/// This creates a synthetic entry marked as GUESS until confirmed by activation
pub unsafe fn add_app_to_mru_as_guess(pid: u32, bundle_id: String, name: String) {
    // Create a synthetic entry with window_id=0 (will be replaced on first real activation)
    let identity = WindowIdentity { pid, window_id: 0 };

    let entry = MruWindowEntry {
        identity: identity.clone(),
        bundle_id: bundle_id.clone(),
        title: name,
        role: None,
        subrole: None,
        rect: None,
        is_fullscreen: false,
        is_minimized: false,
        activation_state: ActivationState::Guess,
    };

    let mut stack = MRU_STACK.lock().unwrap();
    // Don't add if this placeholder entry already exists (avoid duplicates)
    if !stack.iter().any(|e| e.identity == identity) {
        stack.push(entry);
        eprintln!("DEBUG: Added GUESS placeholder entry for {} (pid={}, window_id=0)", bundle_id, pid);
    }
}

/// Add app to MRU as KNOWN (used for frontmost during prepopulation)
pub unsafe fn add_app_to_mru_as_known(pid: u32, bundle_id: String, name: String) {
    // Try to get the actual focused window using shared helper
    if let Ok(win_info) = get_focused_window_info(pid) {
        let identity = WindowIdentity { pid, window_id: win_info.window_id };

        let entry = MruWindowEntry {
            identity: identity.clone(),
            bundle_id: bundle_id.clone(),
            title: win_info.title,
            role: win_info.role,
            subrole: win_info.subrole,
            rect: win_info.rect,
            is_fullscreen: win_info.is_fullscreen,
            is_minimized: win_info.is_minimized,
            activation_state: ActivationState::Known,
        };

        let mut stack = MRU_STACK.lock().unwrap();
        stack.insert(0, entry);
        eprintln!("DEBUG: Added KNOWN entry for {} (pid={})", bundle_id, pid);
        return;
    }

    // Fallback: add as GUESS if we can't get window info
    add_app_to_mru_as_guess(pid, bundle_id, name);
}

/// Seed MRU with currently focused window at startup
pub unsafe fn seed_mru_with_current_focus() {
    if let Some(frontmost) = get_frontmost_app_info() {
        update_mru_with_focus(frontmost.pid, frontmost.bundle_id);
    }
}

/// Prune stale MRU entries at Alt-Tab session start
/// Validates each (pid, window_id) pair and removes entries that no longer exist
/// Returns count of pruned entries
pub unsafe fn prune_stale_mru_entries() -> usize {
    use crate::pbmba_ax::validate_window_exists;

    let mut stack = MRU_STACK.lock().unwrap();
    let initial_count = stack.len();

    // Retain only entries that still correspond to live windows
    stack.retain(|entry| {
        validate_window_exists(entry.identity.pid, entry.identity.window_id)
    });

    let pruned_count = initial_count - stack.len();
    pruned_count
}