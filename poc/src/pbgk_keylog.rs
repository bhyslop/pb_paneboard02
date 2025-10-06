// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};
use crate::pbgc_core::KeyState;

// Optional key logging state (for diagnostic visibility)
pub static KEY_STATE: Mutex<Option<KeyState>> = Mutex::new(None);
pub static KEY_LOGGING_ENABLED: AtomicBool = AtomicBool::new(false);

/// Update key state for diagnostic logging
/// Returns true if state changed
pub fn update_key_state(usage: u32, is_pressed: bool) -> bool {
    let mut state_guard = KEY_STATE.lock().unwrap();
    let state = state_guard.get_or_insert_with(KeyState::default);

    let mut changed = false;

    // Handle modifiers and regular keys
    match usage {
        0xE0 => { // Left Control
            if state.left_control != is_pressed {
                state.left_control = is_pressed;
                changed = true;
            }
        }
        0xE1 => { // Left Shift
            if state.left_shift != is_pressed {
                state.left_shift = is_pressed;
                changed = true;
            }
        }
        0xE2 => { // Left Alt/Option
            if state.left_alt != is_pressed {
                state.left_alt = is_pressed;
                changed = true;
            }
        }
        0xE3 => { // Left Command
            if state.left_cmd != is_pressed {
                state.left_cmd = is_pressed;
                changed = true;
            }
        }
        0xE4 => { // Right Control
            if state.right_control != is_pressed {
                state.right_control = is_pressed;
                changed = true;
            }
        }
        0xE5 => { // Right Shift
            if state.right_shift != is_pressed {
                state.right_shift = is_pressed;
                changed = true;
            }
        }
        0xE6 => { // Right Alt/Option
            if state.right_alt != is_pressed {
                state.right_alt = is_pressed;
                changed = true;
            }
        }
        0xE7 => { // Right Command
            if state.right_cmd != is_pressed {
                state.right_cmd = is_pressed;
                changed = true;
            }
        }
        _ => { // Regular keys (non-modifiers)
            if is_pressed {
                if state.pressed_set.insert(usage) {
                    state.pressed_order.push(usage);
                    changed = true;
                }
            } else if state.pressed_set.remove(&usage) {
                state.pressed_order.retain(|&u| u != usage);
                changed = true;
            }
        }
    }

    if changed && KEY_LOGGING_ENABLED.load(Ordering::Acquire) {
        println!("{}", state.format_output());
    }

    changed
}