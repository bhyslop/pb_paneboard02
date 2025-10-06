// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

use std::collections::HashSet;

// State mask bits for atomic sharing
pub const STATE_LEFT_ALT: u32 = 1 << 0;
pub const STATE_RIGHT_ALT: u32 = 1 << 1;
pub const STATE_LEFT_SHIFT: u32 = 1 << 2;
pub const STATE_RIGHT_SHIFT: u32 = 1 << 3;
pub const STATE_LEFT_CMD: u32 = 1 << 4;
pub const STATE_RIGHT_CMD: u32 = 1 << 5;
pub const STATE_LEFT_CTRL: u32 = 1 << 6;
pub const STATE_RIGHT_CTRL: u32 = 1 << 7;

#[derive(Clone, PartialEq)]
pub struct KeyState {
    pub left_shift: bool,
    pub right_shift: bool,
    pub left_control: bool,
    pub right_control: bool,
    pub left_alt: bool,
    pub right_alt: bool,
    pub left_cmd: bool,
    pub right_cmd: bool,
    pub caps_lock: bool,
    pub pressed_order: Vec<u32>,
    pub pressed_set: HashSet<u32>,
}

impl Default for KeyState {
    fn default() -> Self {
        Self {
            left_shift: false,
            right_shift: false,
            left_control: false,
            right_control: false,
            left_alt: false,
            right_alt: false,
            left_cmd: false,
            right_cmd: false,
            caps_lock: false,
            pressed_order: Vec::new(),
            pressed_set: HashSet::new(),
        }
    }
}

impl KeyState {
    pub fn format_output(&self) -> String {
        let modifiers = format!(
            "{} {} {} {} {} {} {} {}",
            if self.left_shift { "LSH" } else { "lsh" },
            if self.right_shift { "RSH" } else { "rsh" },
            if self.left_control { "LCT" } else { "lct" },
            if self.right_control { "RCT" } else { "rct" },
            if self.left_alt { "LAL" } else { "lal" },
            if self.right_alt { "RAL" } else { "ral" },
            if self.left_cmd { "LME" } else { "lme" },
            if self.right_cmd { "RME" } else { "rme" },
        );

        let keys: Vec<String> = self.pressed_order
            .iter()
            .map(|&usage| usage_to_key_name(usage))
            .collect();

        format!("{} || Keys: {}", modifiers, keys.join(" "))
    }
}

pub fn usage_to_key_name(usage: u32) -> String {
    match usage {
        0x04 => "a".to_string(),
        0x05 => "b".to_string(),
        0x06 => "c".to_string(),
        0x07 => "d".to_string(),
        0x08 => "e".to_string(),
        0x09 => "f".to_string(),
        0x0A => "g".to_string(),
        0x0B => "h".to_string(),
        0x0C => "i".to_string(),
        0x0D => "j".to_string(),
        0x0E => "k".to_string(),
        0x0F => "l".to_string(),
        0x10 => "m".to_string(),
        0x11 => "n".to_string(),
        0x12 => "o".to_string(),
        0x13 => "p".to_string(),
        0x14 => "q".to_string(),
        0x15 => "r".to_string(),
        0x16 => "s".to_string(),
        0x17 => "t".to_string(),
        0x18 => "u".to_string(),
        0x19 => "v".to_string(),
        0x1A => "w".to_string(),
        0x1B => "x".to_string(),
        0x1C => "y".to_string(),
        0x1D => "z".to_string(),
        0x1E => "1".to_string(),
        0x1F => "2".to_string(),
        0x20 => "3".to_string(),
        0x21 => "4".to_string(),
        0x22 => "5".to_string(),
        0x23 => "6".to_string(),
        0x24 => "7".to_string(),
        0x25 => "8".to_string(),
        0x26 => "9".to_string(),
        0x27 => "0".to_string(),
        0x28 => "enter".to_string(),
        0x29 => "esc".to_string(),
        0x2A => "backspace".to_string(),
        0x2B => "tab".to_string(),
        0x2C => "space".to_string(),
        0x2D => "-".to_string(),
        0x2E => "=".to_string(),
        0x2F => "[".to_string(),
        0x30 => "]".to_string(),
        0x31 => "\\".to_string(),
        0x33 => ";".to_string(),
        0x34 => "'".to_string(),
        0x35 => "`".to_string(),
        0x36 => ",".to_string(),
        0x37 => ".".to_string(),
        0x38 => "/".to_string(),
        0x3A => "f1".to_string(),
        0x3B => "f2".to_string(),
        0x3C => "f3".to_string(),
        0x3D => "f4".to_string(),
        0x3E => "f5".to_string(),
        0x3F => "f6".to_string(),
        0x40 => "f7".to_string(),
        0x41 => "f8".to_string(),
        0x42 => "f9".to_string(),
        0x43 => "f10".to_string(),
        0x44 => "f11".to_string(),
        0x45 => "f12".to_string(),
        0x49 => "ins".to_string(),
        0x4A => "home".to_string(),
        0x4B => "pgup".to_string(),
        0x4C => "del".to_string(),
        0x4D => "end".to_string(),
        0x4E => "pgdn".to_string(),
        0x4F => "right".to_string(),
        0x50 => "left".to_string(),
        0x51 => "down".to_string(),
        0x52 => "up".to_string(),
        _ => format!("0x{:02X}", usage),
    }
}

// Quadrants
#[derive(Copy, Clone, Debug)]
pub enum Quad { UL, UR, LL, LR }
