// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

/// Form Resolution and Runtime Construction
/// Transforms parsed layout configurations into runtime-ready structures
///
/// This module handles:
/// - Quirk matching and display detection
/// - Conditional evaluation (IncludeCondition, Space matching)
/// - Reference resolution (frames, measures, layouts)
/// - Shape tree processing and flattening
/// - Conversion from ParsedForm → Form
/// - Runtime layout computation API

use std::collections::HashMap;

#[cfg(target_os = "macos")]
use crate::pbmbd_display::{DisplayInfo, RuntimeDisplayQuirk};

// Import types from sibling modules
use crate::pbgft_types::{DisplayProps, PaneFrac, DisplayMoveTarget, LayoutSession, DisplayMoveSession};
use crate::pbgfp_parse::{ParsedForm, ParsedSpace, ParsedFrame, ParsedPane, ParsedShape,
                          Platform, Orientation, MeasureRef, SpaceRule, ShapeChild,
                          IncludeCondition, TraverseOrder, MirrorMode, Fraction};

// Use platform-specific or generic types depending on target
#[cfg(not(target_os = "macos"))]
use crate::pbgft_types::{DisplayInfo, RuntimeDisplayQuirk};

// ============================================================================
// Module-specific runtime types
// ============================================================================

/// Runtime layout configuration (stores layout data for on-demand computation)
struct RuntimeLayout {
    space: Option<String>,
    root_shape: ParsedShape,
    traverse: TraverseOrder,
    mirror_x: MirrorMode,
    mirror_y: MirrorMode,
}

/// Main runtime form - immutable configuration provider
pub struct Form {
    // Layout configurations: key_name → layout data
    layouts: HashMap<String, RuntimeLayout>,

    // Parsed data needed for runtime computation
    spaces: HashMap<String, ParsedSpace>,
    frames: HashMap<String, ParsedFrame>,
    measures: HashMap<String, u32>,

    // Runtime quirks for display adjustment
    quirks: Vec<RuntimeDisplayQuirk>,

    // DisplayMove bindings: key_name → target spec
    display_moves: HashMap<String, DisplayMoveTarget>,

    // Current layout session state (ephemeral, reset on chord release)
    layout_session: Option<LayoutSession>,

    // DisplayMove session state (tracks original size for consecutive moves)
    display_move_session: Option<DisplayMoveSession>,
}

// ============================================================================
// Conditional evaluation for Include
// ============================================================================

impl IncludeCondition {
    /// Check if all conditions match the display (AND logic)
    /// Returns true if all present conditions pass, false if any fail
    fn matches(&self, display: &DisplayProps) -> bool {
        // Orientation check
        if let Some(ref orientation) = self.when_orientation {
            let actual = if display.width >= display.height {
                Orientation::Landscape
            } else {
                Orientation::Portrait
            };

            match orientation {
                Orientation::Never => return false,  // "never" always fails
                Orientation::Portrait if actual != Orientation::Portrait => return false,
                Orientation::Landscape if actual != Orientation::Landscape => return false,
                _ => {}
            }
        }

        // Display name substring match (case-insensitive)
        if let Some(ref name_contains) = self.name_contains {
            if !display.name.to_lowercase().contains(&name_contains.to_lowercase()) {
                return false;
            }
        }

        // Width constraints
        if let Some(min_width) = self.min_width {
            if display.width < min_width as f64 {
                return false;
            }
        }
        if let Some(under_width) = self.under_width {
            if display.width >= under_width as f64 {
                return false;
            }
        }

        // Height constraints
        if let Some(min_height) = self.min_height {
            if display.height < min_height as f64 {
                return false;
            }
        }
        if let Some(under_height) = self.under_height {
            if display.height >= under_height as f64 {
                return false;
            }
        }

        true  // All conditions passed
    }
}

// ============================================================================
// Validation (operates on parse-time structures)
// ============================================================================

impl ParsedForm {
    fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();

        // Validate LayoutAction references
        for action in &self.layout_actions {
            if !self.layouts.contains_key(&action.layout) {
                errors.push(format!("LayoutAction key='{}' references undefined Layout '{}'",
                    action.key, action.layout));
            }
        }

        // Validate Layout → Space references and Needs/Measure consistency
        for (layout_name, layout) in &self.layouts {
            if let Some(ref space_name) = layout.space {
                if !self.spaces.contains_key(space_name) {
                    errors.push(format!("Layout '{}' references undefined Space '{}'",
                        layout_name, space_name));
                }
            }

            // Validate Needs declarations exist
            for measure_name in &layout.needed_measures {
                if !self.measures.contains_key(measure_name) {
                    errors.push(format!("Layout '{}' needs undefined Measure '{}'",
                        layout_name, measure_name));
                }
            }

            // Validate Shape tree: Frame references + Needs/Measure enforcement
            let mut used_measures = std::collections::HashSet::new();
            Self::validate_shape_tree(&layout.root_shape, layout_name, &self.frames, &mut used_measures, &mut errors);

            // Check that all used measures were declared in Needs
            for used_measure in &used_measures {
                if !layout.needed_measures.contains(used_measure) {
                    errors.push(format!(
                        "Layout '{}' uses Measure '{}' in Shape but does not declare it in <Needs>",
                        layout_name, used_measure
                    ));
                }
            }
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    fn validate_shape_tree(
        shape: &ParsedShape,
        layout_name: &str,
        frames: &HashMap<String, ParsedFrame>,
        used_measures: &mut std::collections::HashSet<String>,
        errors: &mut Vec<String>
    ) {
        // Collect any MeasureRefs from this Shape's constraints
        for opt_mref in [&shape.min_width, &shape.min_height, &shape.under_width, &shape.under_height] {
            if let Some(MeasureRef::Name(ref name)) = opt_mref {
                used_measures.insert(name.clone());
            }
        }

        // Special case: synthetic "__multi__" frame for multiple top-level shapes
        if shape.frame == "__multi__" {
            // Just validate children recursively
            for child in &shape.children {
                match child {
                    ShapeChild::Shape(ref child_shape) => {
                        Self::validate_shape_tree(child_shape, layout_name, frames, used_measures, errors);
                    }
                    ShapeChild::Include(_) => {
                        // Includes under __multi__ shouldn't happen but not an error
                    }
                }
            }
            return;
        }

        // Validate frame reference
        if let Some(frame) = frames.get(&shape.frame) {
            // STRICT 1:1 child count enforcement
            if shape.children.len() != frame.panes.len() {
                errors.push(format!(
                    "Layout '{}': child count {} != pane count {} of frame '{}'",
                    layout_name, shape.children.len(), frame.panes.len(), shape.frame
                ));
                return; // Don't recurse into malformed tree
            }

            // Recursively validate child Shapes and check Include layout references
            for child in &shape.children {
                match child {
                    ShapeChild::Shape(ref child_shape) => {
                        Self::validate_shape_tree(child_shape, layout_name, frames, used_measures, errors);
                    }
                    ShapeChild::Include(ref include) => {
                        // Note: Layout references in Include will be validated separately
                        // (we don't have access to layouts map here, and we need cycle detection)
                        // For now, just validate that the Include is well-formed
                        // Cycle detection will happen during layout expansion
                        if let Some(ref _layout_ref) = include.layout {
                            // Layout reference validation happens in a separate pass
                        }
                    }
                }
            }
        } else {
            errors.push(format!("Layout '{}' references undefined Frame '{}'",
                layout_name, shape.frame));
        }
    }
}

// ============================================================================
// Runtime construction (parse-time → runtime)
// ============================================================================

impl ParsedForm {
    /// Apply DisplayQuirks to adjust display dimensions and embed quirks
    /// Returns a new Vec<DisplayInfo> with adjusted dimensions and quirks embedded
    fn apply_display_quirks(&self, displays: &[DisplayInfo]) -> Vec<DisplayInfo> {
        // Determine current platform
        #[cfg(target_os = "macos")]
        let current_platform = Platform::MacOS;
        #[cfg(target_os = "windows")]
        let current_platform = Platform::Windows;
        #[cfg(target_os = "linux")]
        let current_platform = Platform::Linux;

        eprintln!("DEBUG: apply_display_quirks called with {} displays, {} quirks total",
            displays.len(), self.display_quirks.len());
        for quirk in &self.display_quirks {
            let platform_str = match quirk.platform {
                Platform::MacOS => "macos",
                Platform::Windows => "windows",
                Platform::Linux => "linux",
            };
            eprintln!("DEBUG: quirk: nameContains='{}' platform={} inset={}",
                quirk.name_contains, platform_str, quirk.min_bottom_inset);
        }

        // Filter quirks to only those matching current platform
        let runtime_quirks: Vec<RuntimeDisplayQuirk> = self.display_quirks.iter()
            .filter(|q| q.platform == current_platform)
            .map(|q| RuntimeDisplayQuirk {
                name_contains: q.name_contains.clone(),
                min_bottom_inset: q.min_bottom_inset,
            })
            .collect();

        displays.iter().map(|display| {
            eprintln!("DEBUG: checking display '{}' against quirks", display.name);

            // Find MAX bottom inset from matching quirks
            let max_bottom_inset = runtime_quirks.iter()
                .filter(|q| display.name.contains(&q.name_contains))
                .map(|q| q.min_bottom_inset)
                .max()
                .unwrap_or(0);

            if max_bottom_inset > 0 {
                eprintln!("LAYOUT: DisplayQuirk matched '{}' → applying {}px bottom inset",
                    display.name, max_bottom_inset);
            }

            // Create new DisplayInfo with adjusted dimensions
            DisplayInfo::new(
                display.index,
                display.design_width,
                display.design_height - max_bottom_inset as f64,
                display.name.clone(),
            )
        }).collect()
    }

    fn build_runtime(&self, displays: &[DisplayInfo]) -> Form {
        let mut layouts = HashMap::new();
        let mut display_moves = HashMap::new();

        // Determine current platform and filter quirks
        #[cfg(target_os = "macos")]
        let current_platform = Platform::MacOS;
        #[cfg(target_os = "windows")]
        let current_platform = Platform::Windows;
        #[cfg(target_os = "linux")]
        let current_platform = Platform::Linux;

        let runtime_quirks: Vec<RuntimeDisplayQuirk> = self.display_quirks.iter()
            .filter(|q| q.platform == current_platform)
            .map(|q| RuntimeDisplayQuirk {
                name_contains: q.name_contains.clone(),
                min_bottom_inset: q.min_bottom_inset,
            })
            .collect();

        // Apply DisplayQuirks to displays (for initial validation only)
        let _adjusted_displays = self.apply_display_quirks(displays);

        // Build DisplayMove bindings
        for dm in &self.display_moves {
            display_moves.insert(dm.key.clone(), dm.target.clone());
        }

        // Build RuntimeLayout for each LayoutAction
        for action in &self.layout_actions {
            if let Some(layout) = self.layouts.get(&action.layout) {
                let runtime_layout = RuntimeLayout {
                    space: layout.space.clone(),
                    root_shape: layout.root_shape.clone(),
                    traverse: action.traverse,
                    mirror_x: action.mirror_x,
                    mirror_y: action.mirror_y,
                };
                layouts.insert(action.key.clone(), runtime_layout);
            }
        }

        Form {
            layouts,
            spaces: self.spaces.clone(),
            frames: self.frames.clone(),
            measures: self.measures.clone(),
            quirks: runtime_quirks,
            display_moves,
            layout_session: None,
            display_move_session: None,
        }
    }
}

// ============================================================================
// Form runtime API (operates on runtime structures only)
// ============================================================================

impl Form {
    pub fn empty() -> Self {
        Form {
            layouts: HashMap::new(),
            spaces: HashMap::new(),
            frames: HashMap::new(),
            measures: HashMap::new(),
            quirks: Vec::new(),
            display_moves: HashMap::new(),
            layout_session: None,
            display_move_session: None,
        }
    }

    /// Load Form from config file and build runtime structures
    pub fn load_from_file(displays: &[DisplayInfo]) -> Self {
        // Load config file
        let xml = match crate::pbgfc_config::load_config_file() {
            Ok(content) => content,
            Err(e) => {
                eprintln!("FORM: ERROR failed to load config file: {}", e);
                eprintln!("FORM: Using embedded default config");
                crate::pbgfc_config::get_default_config().to_string()
            }
        };

        // Parse XML
        let parsed = match crate::pbgfp_parse::ParsedForm::from_xml(&xml) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("FORM: ERROR failed to parse config: {}", e);
                eprintln!("FORM: Returning empty Form");
                return Self::empty();
            }
        };

        // Validate
        if let Err(errors) = parsed.validate() {
            eprintln!("FORM: ERROR validation failed:");
            for error in errors {
                eprintln!("  {}", error);
            }
            eprintln!("FORM: Returning empty Form");
            return Self::empty();
        }

        // Apply quirks and build runtime
        let adjusted_displays = parsed.apply_display_quirks(displays);
        parsed.build_runtime(&adjusted_displays)
    }

    // Private helper methods (moved from ParsedForm)

    fn space_matches_display(&self, space: &ParsedSpace, display: &DisplayProps) -> bool {
        // Multiple Match elements are OR'd
        let any_match = space.matches.is_empty() || space.matches.iter().any(|rule| {
            self.rule_matches_display(rule, display)
        });

        if !any_match {
            return false;
        }

        // Multiple Exclude elements are OR'd (any exclude vetoes)
        let any_exclude = space.excludes.iter().any(|rule| {
            self.rule_matches_display(rule, display)
        });

        !any_exclude
    }

    fn rule_matches_display(&self, rule: &SpaceRule, display: &DisplayProps) -> bool {
        // All attributes within a rule are AND'd

        if let Some(ref name_contains) = rule.name_contains {
            if !display.name.contains(name_contains) {
                return false;
            }
        }

        if let Some(orientation) = &rule.when_orientation {
            let actual = if display.width >= display.height {
                Orientation::Landscape
            } else {
                Orientation::Portrait
            };
            if *orientation != actual {
                return false;
            }
        }

        if let Some(ref min_width) = rule.min_width {
            let threshold = self.resolve_measure_ref(min_width);
            if display.width < threshold as f64 {
                return false;
            }
        }

        if let Some(ref min_height) = rule.min_height {
            let threshold = self.resolve_measure_ref(min_height);
            if display.height < threshold as f64 {
                return false;
            }
        }

        if let Some(ref under_width) = rule.under_width {
            let threshold = self.resolve_measure_ref(under_width);
            if display.width >= threshold as f64 {
                return false;
            }
        }

        if let Some(ref under_height) = rule.under_height {
            let threshold = self.resolve_measure_ref(under_height);
            if display.height >= threshold as f64 {
                return false;
            }
        }

        true
    }

    fn resolve_measure_ref(&self, mref: &MeasureRef) -> u32 {
        match mref {
            MeasureRef::Literal(n) => *n,
            MeasureRef::Name(name) => *self.measures.get(name).unwrap_or(&0),
        }
    }

    fn flatten_shape_tree(
        &self,
        shape: &ParsedShape,
        display: &DisplayProps,
        parent_x: &Fraction,
        parent_y: &Fraction,
        parent_width: &Fraction,
        parent_height: &Fraction,
    ) -> Vec<ParsedPane> {
        let mut leaves = Vec::new();

        // Check conditional pruning (orientation)
        if let Some(orientation) = &shape.when_orientation {
            let actual = if display.width >= display.height {
                Orientation::Landscape
            } else {
                Orientation::Portrait
            };
            if *orientation != actual {
                return leaves; // Prune this subtree
            }
        }

        // Special case: synthetic "__multi__" frame for multiple top-level shapes
        if shape.frame == "__multi__" {
            for child in &shape.children {
                match child {
                    ShapeChild::Shape(ref child_shape) => {
                        // Each top-level shape starts with full display context
                        let full = Fraction { num: 1, den: 1 };
                        let zero = Fraction { num: 0, den: 1 };
                        leaves.extend(self.flatten_shape_tree(
                            child_shape,
                            display,
                            &zero,
                            &zero,
                            &full,
                            &full,
                        ));
                    }
                    ShapeChild::Include(_) => {
                        eprintln!("LAYOUT: WARNING Include child under __multi__ frame (unexpected)");
                    }
                }
            }
            return leaves;
        }

        // Get frame reference
        let frame = match self.frames.get(&shape.frame) {
            Some(f) => f,
            None => {
                eprintln!("LAYOUT: ERROR Frame '{}' not found", shape.frame);
                return leaves;
            }
        };

        // Validate 1:1 pane-to-child mapping
        if frame.panes.len() != shape.children.len() {
            eprintln!("LAYOUT: ERROR Frame '{}' has {} panes but Shape has {} children",
                shape.frame, frame.panes.len(), shape.children.len());
            return leaves;
        }

        // Process each pane with its corresponding child
        for (pane, child) in frame.panes.iter().zip(&shape.children) {
            // Compute absolute position within display (pure fraction arithmetic)
            let abs_x = parent_x.add(&parent_width.mul(&pane.x));
            let abs_y = parent_y.add(&parent_height.mul(&pane.y));
            let abs_width = parent_width.mul(&pane.width);
            let abs_height = parent_height.mul(&pane.height);

            match child {
                ShapeChild::Shape(ref child_shape) => {
                    // Recursively subdivide this pane
                    let child_leaves = self.flatten_shape_tree(
                        child_shape,
                        display,
                        &abs_x,
                        &abs_y,
                        &abs_width,
                        &abs_height,
                    );
                    leaves.extend(child_leaves);
                }
                ShapeChild::Include(ref include) => {
                    // Check conditional filtering before processing Include
                    if !include.condition.matches(display) {
                        // Condition failed, skip this Include (and its pane)
                        continue;
                    }

                    // Check if this Include references a layout for further subdivision
                    if let Some(ref layout_name) = include.layout {
                        if let Some(layout) = self.layouts.get(layout_name) {
                            // Recurse into the referenced layout's structure
                            let layout_leaves = self.flatten_shape_tree(
                                &layout.root_shape,
                                display,
                                &abs_x,
                                &abs_y,
                                &abs_width,
                                &abs_height,
                            );
                            leaves.extend(layout_leaves);
                        } else {
                            eprintln!("LAYOUT: ERROR Include references undefined layout '{}'", layout_name);
                        }
                    } else {
                        // No layout reference → this is a terminal pane
                        leaves.push(ParsedPane {
                            x: abs_x,
                            y: abs_y,
                            width: abs_width,
                            height: abs_height,
                        });
                    }
                }
            }
        }

        leaves
    }

    fn apply_mirroring_fracs(&self, panes: &mut [PaneFrac], mirror_x: MirrorMode, mirror_y: MirrorMode) {
        for pane in panes.iter_mut() {
            if mirror_x == MirrorMode::Flip {
                // x' = 1.0 - x - width (fractional space)
                pane.x = 1.0 - pane.x - pane.width;
            }

            if mirror_y == MirrorMode::Flip {
                // y' = 1.0 - y - height (fractional space)
                pane.y = 1.0 - pane.y - pane.height;
            }
        }
    }

    fn sort_pane_list_fracs(&self, panes: &mut Vec<PaneFrac>, traverse: TraverseOrder) {
        // Decode traverse order
        let (primary_axis, primary_dir, secondary_axis, secondary_dir) = match traverse {
            TraverseOrder::XfYf => ('x', 1, 'y', 1),
            TraverseOrder::XfYr => ('x', 1, 'y', -1),
            TraverseOrder::XrYf => ('x', -1, 'y', 1),
            TraverseOrder::XrYr => ('x', -1, 'y', -1),
            TraverseOrder::YfXf => ('y', 1, 'x', 1),
            TraverseOrder::YfXr => ('y', 1, 'x', -1),
            TraverseOrder::YrXf => ('y', -1, 'x', 1),
            TraverseOrder::YrXr => ('y', -1, 'x', -1),
        };

        // Sort by area descending, then by traverse order
        panes.sort_by(|a, b| {
            let area_a = a.width * a.height;
            let area_b = b.width * b.height;

            // Primary key: area descending (larger areas first)
            let area_cmp = area_b.partial_cmp(&area_a).unwrap();
            if area_cmp != std::cmp::Ordering::Equal {
                return area_cmp;
            }

            // Secondary key: spatial traverse order (for panes of same area)
            let a_center_x = a.x + a.width / 2.0;
            let a_center_y = a.y + a.height / 2.0;
            let b_center_x = b.x + b.width / 2.0;
            let b_center_y = b.y + b.height / 2.0;

            let (a_primary, b_primary) = if primary_axis == 'x' {
                (a_center_x, b_center_x)
            } else {
                (a_center_y, b_center_y)
            };

            let (a_secondary, b_secondary) = if secondary_axis == 'x' {
                (a_center_x, b_center_x)
            } else {
                (a_center_y, b_center_y)
            };

            let primary_cmp = if primary_dir == 1 {
                a_primary.partial_cmp(&b_primary).unwrap()
            } else {
                b_primary.partial_cmp(&a_primary).unwrap()
            };

            if primary_cmp != std::cmp::Ordering::Equal {
                return primary_cmp;
            }

            if secondary_dir == 1 {
                a_secondary.partial_cmp(&b_secondary).unwrap()
            } else {
                b_secondary.partial_cmp(&a_secondary).unwrap()
            }
        });
    }

    /// Apply menu bar + quirk corrections to design dimensions (ONCE, at design time)
    /// Design dimensions = fully corrected viewport (menu bar + quirks applied)
    /// live_viewport() returns these same design dimensions - no re-application
    #[cfg(target_os = "macos")]
    pub fn adjust_displays(&self, displays: &[DisplayInfo]) -> Vec<DisplayInfo> {
        use crate::pbmbd_display::{get_all_screens, visible_frame_for_screen, full_frame_for_screen, get_menu_bar_height};

        unsafe {
            let screens = get_all_screens();
            let menu_bar_height = get_menu_bar_height();

            displays.iter().map(|display| {
                // Find MAX bottom inset from matching quirks
                let max_bottom_inset = self.quirks.iter()
                    .filter(|q| display.name.contains(&q.name_contains))
                    .map(|q| q.min_bottom_inset)
                    .max()
                    .unwrap_or(0);

                if max_bottom_inset > 0 {
                    eprintln!("LAYOUT: DisplayQuirk matched '{}' → applying {}px bottom inset",
                        display.name, max_bottom_inset);
                }

                // Start from CURRENT visible frame, not cached gather value
                // (NSScreen may have changed between gather and adjust calls)
                let mut adjusted_height = if display.index < screens.len() {
                    let screen = &screens[display.index];
                    if let (Some(vf), Some(ff)) = (visible_frame_for_screen(screen), full_frame_for_screen(screen)) {
                        // Apply menu bar correction if NSScreen hasn't already done so
                        if vf.height == ff.height {
                            vf.height - menu_bar_height
                        } else {
                            // NSScreen already subtracted menu bar
                            vf.height
                        }
                    } else {
                        display.design_height
                    }
                } else {
                    display.design_height
                };

                // Apply quirks to design dimensions (physical seam compensation)
                // --- BEGIN REQUIRED FIX ---
                adjusted_height -= max_bottom_inset as f64;
                eprintln!(
                    "DEBUG: adjust_displays(): applied quirk bottom_inset={} → design_height={}",
                    max_bottom_inset, adjusted_height
                );
                // --- END REQUIRED FIX ---

                // Create new DisplayInfo with fully corrected dimensions
                DisplayInfo::new(
                    display.index,
                    display.design_width,
                    adjusted_height,
                    display.name.clone(),
                )
            }).collect()
        }
    }

    /// Compute fractional panes for a given action and display
    /// Returns None if key not found or no panes after conditional pruning
    pub fn panes_for_action(&self, key: &str, display: &DisplayProps) -> Option<Vec<PaneFrac>> {
        let layout = self.layouts.get(key)?;

        // Check if Layout's Space matches this display
        if let Some(ref space_name) = layout.space {
            if let Some(space) = self.spaces.get(space_name) {
                if !self.space_matches_display(space, display) {
                    return None; // Space doesn't match
                }
            }
        }

        // Flatten shape tree to leaf panes using pure rational arithmetic
        let full = Fraction { num: 1, den: 1 };
        let zero = Fraction { num: 0, den: 1 };
        let leaf_panes = self.flatten_shape_tree(
            &layout.root_shape,
            display,
            &zero,    // parent x = 0
            &zero,    // parent y = 0
            &full,    // parent width = 1
            &full,    // parent height = 1
        );

        if leaf_panes.is_empty() {
            return None;
        }

        eprintln!("LAYOUT: key='{}' → {} panes on display '{}'", key, leaf_panes.len(), display.name);

        // Convert ParsedPane (fractions) to PaneFrac
        let mut frac_panes: Vec<PaneFrac> = leaf_panes.iter()
            .map(|p| PaneFrac {
                x: p.x.to_f64(),
                y: p.y.to_f64(),
                width: p.width.to_f64(),
                height: p.height.to_f64(),
            })
            .collect();

        // Apply mirroring in fractional space
        self.apply_mirroring_fracs(&mut frac_panes, layout.mirror_x, layout.mirror_y);

        // Sort by area descending, then by traverse order
        self.sort_pane_list_fracs(&mut frac_panes, layout.traverse);

        Some(frac_panes)
    }

    /// Get next pane with MRU session tracking
    /// Returns (fractional pane, index) or None if no panes available
    pub fn get_next_pane(&mut self, key: &str, display: &DisplayProps) -> Option<(PaneFrac, usize)> {
        let pane_list = self.panes_for_action(key, display)?;

        if pane_list.is_empty() {
            return None;
        }

        // Check if we're continuing the same session
        let pane_index = if let Some(ref session) = self.layout_session {
            if session.current_key == key {
                // Continue session, advance index
                session.pane_index % pane_list.len()
            } else {
                // Different key, start new session
                0
            }
        } else {
            // First press, start at index 0
            0
        };

        let pane = pane_list[pane_index].clone();
        let next_index = (pane_index + 1) % pane_list.len();

        // Update session
        self.layout_session = Some(LayoutSession {
            current_key: key.to_string(),
            pane_index: next_index,
        });

        Some((pane, pane_index))
    }

    /// Reset layout session (called on chord release)
    pub fn reset_layout_session(&mut self) {
        if self.layout_session.is_some() {
            eprintln!("LAYOUT: Resetting layout session");
        }
        self.layout_session = None;
    }

    /// Reset display move session (called on chord release)
    pub fn reset_display_move_session(&mut self) {
        self.display_move_session = None;
    }

    /// Check if a key has a LayoutAction binding
    pub fn has_layout_action(&self, key: &str) -> bool {
        self.layouts.contains_key(key)
    }

    /// Check if a key has a DisplayMove binding
    #[allow(dead_code)] // Public API, may be used by future callers
    pub fn has_display_move(&self, key: &str) -> bool {
        self.display_moves.contains_key(key)
    }

    /// Execute a DisplayMove for the given key and current display index
    /// Returns the target display index, or None if key not bound or target out of range
    pub fn execute_display_move(&self, key: &str, current_display_index: usize, total_displays: usize) -> Option<usize> {
        let target = self.display_moves.get(key)?;

        match target {
            DisplayMoveTarget::Next { wrap } => {
                if current_display_index + 1 < total_displays {
                    Some(current_display_index + 1)
                } else if *wrap {
                    Some(0) // Wrap to first display
                } else {
                    None // No-op at boundary
                }
            }
            DisplayMoveTarget::Prev { wrap } => {
                if current_display_index > 0 {
                    Some(current_display_index - 1)
                } else if *wrap {
                    Some(total_displays - 1) // Wrap to last display
                } else {
                    None // No-op at boundary
                }
            }
            DisplayMoveTarget::Index(idx) => {
                if *idx < total_displays {
                    Some(*idx)
                } else {
                    eprintln!("DISPLAYMOVE: target={} out of range (max={})", idx, total_displays - 1);
                    None
                }
            }
        }
    }
}
