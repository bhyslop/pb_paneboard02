// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

//! Base overlay infrastructure for PaneBoard overlays (Alt-Tab, Clipboard, etc.)
//!
//! Provides shared types and traits for overlay management using composition over inheritance.

use std::ffi::CString;
use std::os::raw::c_char;

// ============================================================================================
// FFI String Conversion Utilities
// ============================================================================================

/// Convert a slice of strings to C-compatible string pointers
/// Returns (CString storage, pointer array)
///
/// The CString storage must be kept alive as long as the pointers are used.
pub fn strings_to_ffi(strings: &[String]) -> (Vec<CString>, Vec<*const c_char>) {
    let mut c_strings = Vec::with_capacity(strings.len());
    let mut ptrs = Vec::with_capacity(strings.len());

    for s in strings {
        let c_string = CString::new(s.as_str()).unwrap_or_else(|_| CString::new("").unwrap());
        ptrs.push(c_string.as_ptr());
        c_strings.push(c_string);
    }

    (c_strings, ptrs)
}

// ============================================================================================
// External FFI Declarations
// ============================================================================================

// External Swift functions for overlay management
// These are implemented in pbmbo_observer.swift
#[cfg(target_os = "macos")]
extern "C" {
    // Alt-Tab overlay functions
    pub fn pbmbo_show_alt_tab_overlay(
        bundle_ids: *const *const c_char,
        titles: *const *const c_char,
        activation_states: *const *const c_char,
        count: i32,
        highlight_index: i32,
    );

    pub fn pbmbo_update_alt_tab_highlight(
        bundle_ids: *const *const c_char,
        titles: *const *const c_char,
        activation_states: *const *const c_char,
        count: i32,
        highlight_index: i32,
    );

    pub fn pbmbo_hide_alt_tab_overlay();

    // Clipboard overlay functions
    pub fn pbmbo_show_clipboard_overlay(
        entries: *const *const c_char,
        count: i32,
        highlight_index: i32,
    );

    pub fn pbmbo_update_clipboard_highlight(
        entries: *const *const c_char,
        count: i32,
        highlight_index: i32,
    );

    pub fn pbmbo_hide_clipboard_overlay();
}