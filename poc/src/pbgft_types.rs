// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

/// Form Configuration Runtime Types
///
/// This module contains runtime type definitions used by the Form configuration system.
/// These types are kept after XML parsing is complete and are used during layout
/// computation and execution.

// Re-export platform display types for convenience
#[cfg(target_os = "macos")]
#[allow(unused_imports)] // Re-exported for module interface
pub use crate::pbmbd_display::DisplayInfo;

// Stub types for non-macOS platforms (not used, but needed for compilation)
#[cfg(not(target_os = "macos"))]
#[derive(Clone)]
pub struct DisplayInfo {
    pub index: usize,
    pub design_width: f64,
    pub design_height: f64,
    pub name: String,
}

// ============================================================================
// Runtime display and geometry structures
// ============================================================================

/// Logical display properties for conditional matching (Form input)
#[derive(Debug, Clone)]
pub struct DisplayProps {
    pub width: f64,
    pub height: f64,
    pub name: String,
}

/// Fractional pane in [0,1] relative to display (Form output)
#[derive(Debug, Clone)]
pub struct PaneFrac {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

/// Pixel rectangle in screen coordinates (Display layer output)
#[derive(Debug, Clone)]
pub struct PixelRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

// ============================================================================
// DisplayMove types
// ============================================================================

#[derive(Debug, Clone)]
pub enum DisplayMoveTarget {
    Next { wrap: bool },
    Prev { wrap: bool },
    Index(usize),
}

// ============================================================================
// Session state structures
// ============================================================================

pub(crate) struct LayoutSession {
    pub(crate) current_key: String,
    pub(crate) pane_index: usize,
}

#[allow(dead_code)]
pub(crate) struct DisplayMoveSession {
    pub(crate) original_size: Option<(f64, f64)>, // (width, height) before first move
}
