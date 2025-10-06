// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

//! Base overlay infrastructure for PaneBoard overlays (Alt-Tab, Clipboard, etc.)
//!
//! Provides shared types and traits for overlay management using composition over inheritance.

use std::ffi::CString;
use std::os::raw::c_char;

// ============================================================================================
// Core Overlay Types
// ============================================================================================

/// Represents the state of an overlay system
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum OverlayState {
    Hidden,
    Visible,
    Updating,
}

/// Common overlay configuration
#[derive(Debug, Clone)]
pub struct OverlayConfig {
    pub width_ratio: f64,  // Ratio of screen width for overlay (e.g., 0.9)
    pub height_ratio: f64, // Ratio of screen height for overlay (e.g., 0.5)
    pub max_width: f64,    // Maximum width in points
    pub alpha: f32,        // Background alpha transparency
}

impl Default for OverlayConfig {
    fn default() -> Self {
        Self {
            width_ratio: 0.9,
            height_ratio: 0.5,
            max_width: f64::MAX,
            alpha: 0.9,
        }
    }
}

// ============================================================================================
// Overlay Behavior Trait
// ============================================================================================

/// Trait for specific overlay implementations to customize behavior
pub trait OverlayBehavior {
    /// The type of data this overlay displays
    type Data;

    /// Check if overlay should be shown
    fn should_show(&self) -> bool;

    /// Update the overlay's content data
    fn update_content(&mut self, data: Self::Data, highlight_index: i32);

    /// Handle selection of an item at the given index
    fn handle_selection(&mut self, index: usize) -> bool;

    /// Get the current highlight index
    fn get_highlight_index(&self) -> i32;

    /// Get configuration for this overlay
    fn get_config(&self) -> OverlayConfig {
        OverlayConfig::default()
    }
}

// ============================================================================================
// Overlay Manager
// ============================================================================================

/// Generic overlay manager using composition
pub struct OverlayManager<T: OverlayBehavior> {
    /// Current state of the overlay
    pub state: OverlayState,

    /// Specific overlay implementation
    pub specific: T,

    /// Last known highlight index for efficient updates
    last_highlight: i32,
}

impl<T: OverlayBehavior> OverlayManager<T> {
    pub fn new(specific: T) -> Self {
        Self {
            state: OverlayState::Hidden,
            specific,
            last_highlight: 0,
        }
    }

    /// Show the overlay with initial data
    pub fn show(&mut self, data: T::Data, highlight_index: i32) {
        self.specific.update_content(data, highlight_index);
        self.state = OverlayState::Visible;
        self.last_highlight = highlight_index;
    }

    /// Update overlay content if visible
    pub fn update(&mut self, data: T::Data, highlight_index: i32) {
        if self.state == OverlayState::Visible {
            self.state = OverlayState::Updating;
            self.specific.update_content(data, highlight_index);
            self.last_highlight = highlight_index;
            self.state = OverlayState::Visible;
        }
    }

    /// Hide the overlay
    pub fn hide(&mut self) {
        self.state = OverlayState::Hidden;
    }

    /// Check if highlight changed (optimization helper)
    pub fn highlight_changed(&self, new_highlight: i32) -> bool {
        self.last_highlight != new_highlight
    }
}

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

/// Convert a vector of optional strings to C-compatible string pointers
/// None values become null pointers
pub fn optional_strings_to_ffi(strings: &[Option<String>]) -> (Vec<CString>, Vec<*const c_char>) {
    let mut c_strings = Vec::with_capacity(strings.len());
    let mut ptrs = Vec::with_capacity(strings.len());

    for opt_s in strings {
        match opt_s {
            Some(s) => {
                let c_string = CString::new(s.as_str()).unwrap_or_else(|_| CString::new("").unwrap());
                ptrs.push(c_string.as_ptr());
                c_strings.push(c_string);
            }
            None => {
                ptrs.push(std::ptr::null());
            }
        }
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