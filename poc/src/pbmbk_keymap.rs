// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

// Virtual keycodes for clipboard chords
pub const VK_C: u16 = 8;
pub const VK_V: u16 = 9;
pub const VK_X: u16 = 7;

// CGEvent constants for tiling PoC
pub const K_CG_KEYBOARD_EVENT_AUTOREPEAT: u32 = 8;
pub const K_CG_SESSION_EVENT_TAP: u32 = 1;
pub const K_CG_HEAD_INSERT_EVENT_TAP: u32 = 0;
pub const K_CG_EVENT_TAP_OPTION_DEFAULT: u32 = 0;
pub const K_CG_EVENT_KEY_DOWN: u32 = 10;
pub const K_CG_EVENT_KEY_UP: u32 = 11;
pub const K_CG_EVENT_FLAGS_CHANGED: u32 = 12;
pub const K_CG_EVENT_LEFT_MOUSE_DOWN: u32 = 1;
pub const K_CG_EVENT_LEFT_MOUSE_UP: u32 = 2;
pub const K_CG_EVENT_RIGHT_MOUSE_DOWN: u32 = 3;
pub const K_CG_EVENT_RIGHT_MOUSE_UP: u32 = 4;
pub const K_CG_EVENT_OTHER_MOUSE_DOWN: u32 = 25;
pub const K_CG_EVENT_OTHER_MOUSE_UP: u32 = 26;
pub const CG_EVENT_MASK_KEYBOARD: u64 = (1u64 << K_CG_EVENT_KEY_DOWN) | (1u64 << K_CG_EVENT_KEY_UP) | (1u64 << K_CG_EVENT_FLAGS_CHANGED);
pub const CG_EVENT_MASK_MOUSE: u64 = (1u64 << K_CG_EVENT_LEFT_MOUSE_DOWN) | (1u64 << K_CG_EVENT_LEFT_MOUSE_UP)
    | (1u64 << K_CG_EVENT_RIGHT_MOUSE_DOWN) | (1u64 << K_CG_EVENT_RIGHT_MOUSE_UP)
    | (1u64 << K_CG_EVENT_OTHER_MOUSE_DOWN) | (1u64 << K_CG_EVENT_OTHER_MOUSE_UP);
pub const CG_EVENT_MASK_ALL: u64 = CG_EVENT_MASK_KEYBOARD | CG_EVENT_MASK_MOUSE;
pub const K_CG_KEYCODE_FIELD_KEYCODE: u32 = 9;
pub const K_CG_EVENT_FLAG_MASK_CONTROL: u64 = 1 << 18;
pub const K_CG_EVENT_FLAG_MASK_SHIFT: u64 = 1 << 17;
pub const K_CG_EVENT_FLAG_MASK_COMMAND: u64 = 1 << 20;
pub const K_CG_EVENT_FLAG_MASK_ALTERNATE: u64 = 1 << 19;

/// Map macOS virtual keycode to XML key name (per KeyType in pbxs_schema.xsd)
/// Returns None for unmapped or modifier keys
pub fn keycode_to_xml_key(keycode: u16) -> Option<&'static str> {
    match keycode {
        // Letters (lowercase, per schema)
        0x00 => Some("a"),
        0x0B => Some("b"),
        0x08 => Some("c"),
        0x02 => Some("d"),
        0x0E => Some("e"),
        0x03 => Some("f"),
        0x05 => Some("g"),
        0x04 => Some("h"),
        0x22 => Some("i"),
        0x26 => Some("j"),
        0x28 => Some("k"),
        0x25 => Some("l"),
        0x2E => Some("m"),
        0x2D => Some("n"),
        0x1F => Some("o"),
        0x23 => Some("p"),
        0x0C => Some("q"),
        0x0F => Some("r"),
        0x01 => Some("s"),
        0x11 => Some("t"),
        0x20 => Some("u"),
        0x09 => Some("v"),
        0x0D => Some("w"),
        0x07 => Some("x"),
        0x10 => Some("y"),
        0x06 => Some("z"),

        // Digits (unshifted)
        0x1D => Some("0"),
        0x12 => Some("1"),
        0x13 => Some("2"),
        0x14 => Some("3"),
        0x15 => Some("4"),
        0x17 => Some("5"),
        0x16 => Some("6"),
        0x1A => Some("7"),
        0x1C => Some("8"),
        0x19 => Some("9"),

        // Function keys (F1-F12)
        0x7A => Some("f1"),
        0x78 => Some("f2"),
        0x63 => Some("f3"),
        0x76 => Some("f4"),
        0x60 => Some("f5"),
        0x61 => Some("f6"),
        0x62 => Some("f7"),
        0x64 => Some("f8"),
        0x65 => Some("f9"),
        0x6D => Some("f10"),
        0x67 => Some("f11"),
        0x6F => Some("f12"),

        // Navigation: arrows
        0x7E => Some("up"),
        0x7D => Some("down"),
        0x7B => Some("left"),
        0x7C => Some("right"),

        // Navigation: other
        0x73 => Some("home"),
        0x77 => Some("end"),
        0x74 => Some("pageup"),
        0x79 => Some("pagedown"),

        // Editing/Control
        0x35 => Some("escape"),
        0x30 => Some("tab"),
        0x31 => Some("space"),
        0x24 => Some("enter"),
        0x33 => Some("backspace"),
        0x75 => Some("delete"),

        // Punctuation (unshifted, spelled out per schema)
        0x32 => Some("grave"),
        0x1B => Some("minus"),
        0x18 => Some("equals"),
        0x21 => Some("leftbracket"),
        0x1E => Some("rightbracket"),
        0x2A => Some("backslash"),
        0x29 => Some("semicolon"),
        0x27 => Some("apostrophe"),
        0x2B => Some("comma"),
        0x2F => Some("period"),
        0x2C => Some("slash"),

        // Numpad (basic operators and digits)
        0x52 => Some("numpad0"),
        0x53 => Some("numpad1"),
        0x54 => Some("numpad2"),
        0x55 => Some("numpad3"),
        0x56 => Some("numpad4"),
        0x57 => Some("numpad5"),
        0x58 => Some("numpad6"),
        0x59 => Some("numpad7"),
        0x5B => Some("numpad8"),
        0x5C => Some("numpad9"),
        0x45 => Some("numpadplus"),
        0x4E => Some("numpadminus"),
        0x43 => Some("numpadmultiply"),
        0x4B => Some("numpaddivide"),
        0x51 => Some("numpadequals"),
        0x41 => Some("numpadperiod"),
        0x4C => Some("numpadenter"),

        // Modifiers and unknown keys return None
        _ => None,
    }
}

// Convert macOS virtual keycode to HID usage code (for KeyState tracking)
// Returns None for keycodes we don't track (or can't map)
pub fn vk_to_hid_usage(vk: u16) -> Option<u32> {
    match vk {
        // Letters (macOS VK uses ANSI-US layout positions)
        0x00 => Some(0x04), // A
        0x0B => Some(0x05), // B
        0x08 => Some(0x06), // C
        0x02 => Some(0x07), // D
        0x0E => Some(0x08), // E
        0x03 => Some(0x09), // F
        0x05 => Some(0x0A), // G
        0x04 => Some(0x0B), // H
        0x22 => Some(0x0C), // I
        0x26 => Some(0x0D), // J
        0x28 => Some(0x0E), // K
        0x25 => Some(0x0F), // L
        0x2E => Some(0x10), // M
        0x2D => Some(0x11), // N
        0x1F => Some(0x12), // O
        0x23 => Some(0x13), // P
        0x0C => Some(0x14), // Q
        0x0F => Some(0x15), // R
        0x01 => Some(0x16), // S
        0x11 => Some(0x17), // T
        0x20 => Some(0x18), // U
        0x09 => Some(0x19), // V
        0x0D => Some(0x1A), // W
        0x07 => Some(0x1B), // X
        0x10 => Some(0x1C), // Y
        0x06 => Some(0x1D), // Z

        // Numbers
        0x12 => Some(0x1E), // 1
        0x13 => Some(0x1F), // 2
        0x14 => Some(0x20), // 3
        0x15 => Some(0x21), // 4
        0x17 => Some(0x22), // 5
        0x16 => Some(0x23), // 6
        0x1A => Some(0x24), // 7
        0x1C => Some(0x25), // 8
        0x19 => Some(0x26), // 9
        0x1D => Some(0x27), // 0

        // Special keys
        0x24 => Some(0x28), // Enter/Return
        0x35 => Some(0x29), // Escape
        0x33 => Some(0x2A), // Delete/Backspace
        0x30 => Some(0x2B), // Tab
        0x31 => Some(0x2C), // Space
        0x1B => Some(0x2D), // Minus
        0x18 => Some(0x2E), // Equal
        0x21 => Some(0x2F), // Left Bracket
        0x1E => Some(0x30), // Right Bracket
        0x2A => Some(0x31), // Backslash
        0x29 => Some(0x33), // Semicolon
        0x27 => Some(0x34), // Quote
        0x32 => Some(0x35), // Grave
        0x2B => Some(0x36), // Comma
        0x2F => Some(0x37), // Period
        0x2C => Some(0x38), // Slash

        // Function keys
        0x7A => Some(0x3A), // F1
        0x78 => Some(0x3B), // F2
        0x63 => Some(0x3C), // F3
        0x76 => Some(0x3D), // F4
        0x60 => Some(0x3E), // F5
        0x61 => Some(0x3F), // F6
        0x62 => Some(0x40), // F7
        0x64 => Some(0x41), // F8
        0x65 => Some(0x42), // F9
        0x6D => Some(0x43), // F10
        0x67 => Some(0x44), // F11
        0x6F => Some(0x45), // F12

        // Extended keys
        0x72 => Some(0x49), // Insert/Help
        0x73 => Some(0x4A), // Home
        0x74 => Some(0x4B), // Page Up
        0x75 => Some(0x4C), // Forward Delete
        0x77 => Some(0x4D), // End
        0x79 => Some(0x4E), // Page Down

        // Arrow keys
        0x7C => Some(0x4F), // Right Arrow
        0x7B => Some(0x50), // Left Arrow
        0x7D => Some(0x51), // Down Arrow
        0x7E => Some(0x52), // Up Arrow

        // Modifiers (HID usage codes 0xE0-0xE7)
        0x3B => Some(0xE0), // Left Control
        0x38 => Some(0xE1), // Left Shift
        0x3A => Some(0xE2), // Left Alt/Option
        0x37 => Some(0xE3), // Left Command
        0x3E => Some(0xE4), // Right Control
        0x3C => Some(0xE5), // Right Shift
        0x3D => Some(0xE6), // Right Alt/Option
        0x36 => Some(0xE7), // Right Command

        _ => None, // Unknown or untracked keycode
    }
}