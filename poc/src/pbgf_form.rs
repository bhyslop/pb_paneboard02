// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

/// Form Configuration Parser
/// Parses ~/.config/paneboard/form.xml and provides runtime layout execution
///
/// This module implements the Layout Configuration System specified in paneboard-poc.md.
/// XML parsing artifacts are completely discarded after validation; runtime uses only
/// pre-computed pixel rectangles indexed by (key, display).

use quick_xml::events::Event;
use quick_xml::Reader;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[cfg(target_os = "macos")]
use crate::pbmbd_display::{DisplayInfo, RuntimeDisplayQuirk};

// Stub types for non-macOS platforms (not used, but needed for compilation)
#[cfg(not(target_os = "macos"))]
#[derive(Clone)]
pub struct DisplayInfo {
    pub index: usize,
    pub design_width: f64,
    pub design_height: f64,
    pub name: String,
}

#[cfg(not(target_os = "macos"))]
#[derive(Clone)]
pub struct RuntimeDisplayQuirk {
    pub name_contains: String,
    pub min_bottom_inset: u32,
}

// ============================================================================
// SECTION 1: Fraction type and helpers
// ============================================================================

/// Exact fractional proportion (no floating point until pixel conversion)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Fraction {
    num: u32,
    den: u32,
}

impl Fraction {
    /// Parse from string: "3/10", "1", "0"
    fn parse(s: &str) -> Result<Self, String> {
        let s = s.trim();

        if let Some(slash_pos) = s.find('/') {
            // Format: "num/den"
            let num_str = &s[..slash_pos];
            let den_str = &s[slash_pos + 1..];

            let num = num_str.parse::<u32>()
                .map_err(|_| format!("invalid numerator: {}", num_str))?;
            let den = den_str.parse::<u32>()
                .map_err(|_| format!("invalid denominator: {}", den_str))?;

            if den == 0 {
                return Err("denominator cannot be zero".to_string());
            }

            Ok(Fraction { num, den }.reduce())
        } else {
            // Whole number: "1", "0"
            let num = s.parse::<u32>()
                .map_err(|_| format!("invalid number: {}", s))?;
            Ok(Fraction { num, den: 1 })
        }
    }

    /// Convert to f64 for pixel calculations (only at final stage)
    fn to_f64(&self) -> f64 {
        self.num as f64 / self.den as f64
    }

    /// Compute GCD for fraction reduction
    fn gcd(mut a: u32, mut b: u32) -> u32 {
        while b != 0 {
            let temp = b;
            b = a % b;
            a = temp;
        }
        a
    }

    /// Reduce fraction to lowest terms
    fn reduce(self) -> Self {
        if self.num == 0 {
            return Fraction { num: 0, den: 1 };
        }
        let g = Self::gcd(self.num, self.den);
        Fraction {
            num: self.num / g,
            den: self.den / g,
        }
    }

    /// Add two fractions: a/b + c/d = (ad + bc) / bd
    fn add(&self, other: &Fraction) -> Fraction {
        Fraction {
            num: self.num * other.den + other.num * self.den,
            den: self.den * other.den,
        }.reduce()
    }

    /// Multiply two fractions: (a/b) * (c/d) = (ac) / (bd)
    fn mul(&self, other: &Fraction) -> Fraction {
        Fraction {
            num: self.num * other.num,
            den: self.den * other.den,
        }.reduce()
    }

    /// Scale and translate: parent_offset + (pane_offset * parent_size)
    /// Used for relative coordinate transformation
    fn scale_translate(pane_offset: &Fraction, parent_offset: &Fraction, parent_size: &Fraction) -> Fraction {
        // result = parent_offset + (pane_offset * parent_size)
        let scaled = pane_offset.mul(parent_size);
        parent_offset.add(&scaled)
    }
}

// ============================================================================
// SECTION 2: Runtime structures (kept after parse, no XML ties)
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

#[derive(Debug, Clone)]
pub enum DisplayMoveTarget {
    Next { wrap: bool },
    Prev { wrap: bool },
    Index(usize),
}

struct LayoutSession {
    current_key: String,
    pane_index: usize,
}

#[allow(dead_code)]
struct DisplayMoveSession {
    original_size: Option<(f64, f64)>, // (width, height) before first move
}

// ============================================================================
// SECTION 3: Parse-time structures (discarded after validation)
// ============================================================================

struct ParsedForm {
    measures: HashMap<String, u32>,
    display_quirks: Vec<ParsedDisplayQuirk>,
    spaces: HashMap<String, ParsedSpace>,
    frames: HashMap<String, ParsedFrame>,
    layouts: HashMap<String, ParsedLayout>,
    layout_actions: Vec<ParsedLayoutAction>,
    display_moves: Vec<ParsedDisplayMove>,
}

struct ParsedDisplayQuirk {
    name_contains: String,
    platform: Platform,
    min_bottom_inset: u32,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Platform {
    MacOS,
    Windows,
    Linux,
}

#[derive(Clone)]
struct ParsedSpace {
    name: String,
    matches: Vec<SpaceRule>,
    excludes: Vec<SpaceRule>,
}

#[derive(Clone)]
struct SpaceRule {
    name_contains: Option<String>,
    when_orientation: Option<Orientation>,
    min_width: Option<MeasureRef>,
    min_height: Option<MeasureRef>,
    under_width: Option<MeasureRef>,
    under_height: Option<MeasureRef>,
}

#[derive(Clone, PartialEq, Eq, Debug)]
enum Orientation {
    Portrait,
    Landscape,
    Never,  // Always fails (used for explicit drops via <Include whenOrientation="never"/>)
}

#[derive(Clone)]
enum MeasureRef {
    Name(String),
    Literal(u32),
}

#[derive(Clone)]
struct ParsedFrame {
    name: String,
    panes: Vec<ParsedPane>,
}

#[derive(Clone)]
struct ParsedPane {
    x: Fraction,
    y: Fraction,
    width: Fraction,
    height: Fraction,
}

struct ParsedLayout {
    name: String,
    space: Option<String>, // references Space name
    needed_measures: Vec<String>,
    root_shape: ParsedShape,
}

#[derive(Clone)]
struct ParsedShape {
    frame: String, // references Frame name (now required)
    when_orientation: Option<Orientation>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    min_width: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    min_height: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    under_width: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    under_height: Option<MeasureRef>,
    children: Vec<ShapeChild>,
}

#[derive(Clone)]
enum ShapeChild {
    Shape(ParsedShape),
    Include(LayoutInclude),
}

/// Include directive: terminal pane, sublayout reference, or conditional drop
#[derive(Clone)]
struct LayoutInclude {
    layout: Option<String>,  // If Some, inline this layout's structure
    condition: IncludeCondition,
}

/// Conditional evaluation for Include (all attributes AND-ed)
#[derive(Clone)]
struct IncludeCondition {
    when_orientation: Option<Orientation>,
    min_width: Option<u32>,      // Literal pixels only (no Measure references)
    under_width: Option<u32>,
    min_height: Option<u32>,
    under_height: Option<u32>,
    name_contains: Option<String>,  // Case-insensitive substring match
}

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

struct ParsedLayoutAction {
    key: String,
    layout: String, // references Layout name
    traverse: TraverseOrder,
    mirror_x: MirrorMode,
    mirror_y: MirrorMode,
}

#[derive(Clone, Copy)]
enum TraverseOrder {
    XfYf, XfYr, XrYf, XrYr,
    YfXf, YfXr, YrXf, YrXr,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum MirrorMode {
    Keep,
    Flip,
}

struct ParsedDisplayMove {
    key: String,
    target: DisplayMoveTarget,
}

// ============================================================================
// SECTION 4: Embedded default configuration
// ============================================================================

const DEFAULT_FORM_XML: &str = include_str!("../form.default.xml");

// ============================================================================
// SECTION 5: XML Parsing (builds parse-time structures)
// ============================================================================

impl ParsedForm {
    fn from_xml(xml: &str) -> Result<Self, String> {
        let mut reader = Reader::from_str(xml);
        reader.trim_text(true);

        let mut measures = HashMap::new();
        let mut display_quirks = Vec::new();
        let mut spaces = HashMap::new();
        let mut frames = HashMap::new();
        let mut layouts = HashMap::new();
        let mut layout_actions = Vec::new();
        let mut display_moves = Vec::new();

        let mut buf = Vec::new();
        let mut in_form = false;

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(Event::Start(ref e)) => {
                    match e.name().as_ref() {
                        b"Form" => in_form = true,
                        b"Measure" if in_form => {
                            let m = Self::parse_measure(e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            measures.insert(m.0, m.1);
                        }
                        b"Space" if in_form => {
                            let space = Self::parse_space(&mut reader, e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            spaces.insert(space.name.clone(), space);
                        }
                        b"Frame" if in_form => {
                            let frame = Self::parse_frame(&mut reader, e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            frames.insert(frame.name.clone(), frame);
                        }
                        b"Layout" if in_form => {
                            let layout = Self::parse_layout(&mut reader, e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            layouts.insert(layout.name.clone(), layout);
                        }
                        _ => {}
                    }
                }
                Ok(Event::Empty(ref e)) => {
                    match e.name().as_ref() {
                        b"Measure" if in_form => {
                            let m = Self::parse_measure(e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            measures.insert(m.0, m.1);
                        }
                        b"DisplayQuirk" if in_form => {
                            let quirk = Self::parse_display_quirk(e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            display_quirks.push(quirk);
                        }
                        b"LayoutAction" if in_form => {
                            let action = Self::parse_layout_action(e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            layout_actions.push(action);
                        }
                        b"DisplayMove" if in_form => {
                            let dm = Self::parse_display_move(e)
                                .map_err(|e| format!("at byte {}: {}", reader.buffer_position(), e))?;
                            display_moves.push(dm);
                        }
                        _ => {}
                    }
                }
                Ok(Event::Eof) => break,
                Err(e) => {
                    let pos = reader.buffer_position();
                    return Err(format!("XML parse error at byte {}: {}", pos, e));
                }
                _ => {}
            }
            buf.clear();
        }

        Ok(ParsedForm {
            measures,
            display_quirks,
            spaces,
            frames,
            layouts,
            layout_actions,
            display_moves,
        })
    }

    fn parse_measure(e: &quick_xml::events::BytesStart) -> Result<(String, u32), String> {
        let mut name = None;
        let mut value = None;

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            match attr.key.as_ref() {
                b"name" => name = Some(String::from_utf8_lossy(&attr.value).to_string()),
                b"value" => {
                    let v_str = String::from_utf8_lossy(&attr.value);
                    value = Some(v_str.parse::<u32>()
                        .map_err(|_| format!("invalid measure value: {}", v_str))?);
                }
                _ => {}
            }
        }

        match (name, value) {
            (Some(n), Some(v)) => Ok((n, v)),
            _ => Err("Measure missing required attributes".to_string()),
        }
    }

    fn parse_display_quirk(e: &quick_xml::events::BytesStart) -> Result<ParsedDisplayQuirk, String> {
        let mut name_contains = None;
        let mut platform = None;
        let mut min_bottom_inset = None;

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            match attr.key.as_ref() {
                b"nameContains" => {
                    name_contains = Some(String::from_utf8_lossy(&attr.value).to_string());
                }
                b"platform" => {
                    let p_str = String::from_utf8_lossy(&attr.value);
                    platform = Some(match p_str.as_ref() {
                        "macos" => Platform::MacOS,
                        "windows" => Platform::Windows,
                        "linux" => Platform::Linux,
                        _ => return Err(format!("invalid platform: {}", p_str)),
                    });
                }
                b"minBottomInset" => {
                    let v_str = String::from_utf8_lossy(&attr.value);
                    min_bottom_inset = Some(v_str.parse::<u32>()
                        .map_err(|_| format!("invalid minBottomInset value: {}", v_str))?);
                }
                _ => {}
            }
        }

        match (name_contains, platform, min_bottom_inset) {
            (Some(nc), Some(p), Some(mbi)) => Ok(ParsedDisplayQuirk {
                name_contains: nc,
                platform: p,
                min_bottom_inset: mbi,
            }),
            _ => Err("DisplayQuirk missing required attributes".to_string()),
        }
    }

    fn parse_space(reader: &mut Reader<&[u8]>, start: &quick_xml::events::BytesStart) -> Result<ParsedSpace, String> {
        let mut name = None;

        for attr in start.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            if attr.key.as_ref() == b"name" {
                name = Some(String::from_utf8_lossy(&attr.value).to_string());
            }
        }

        let name = name.ok_or("Space missing name attribute")?;
        let mut matches = Vec::new();
        let mut excludes = Vec::new();
        let mut buf = Vec::new();

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(Event::Empty(ref e)) => {
                    match e.name().as_ref() {
                        b"Match" => matches.push(Self::parse_space_rule(e)?),
                        b"Exclude" => excludes.push(Self::parse_space_rule(e)?),
                        _ => {}
                    }
                }
                Ok(Event::End(ref e)) if e.name().as_ref() == b"Space" => break,
                Ok(Event::Eof) => return Err("unexpected EOF in Space".to_string()),
                Err(e) => return Err(format!("XML parse error: {}", e)),
                _ => {}
            }
            buf.clear();
        }

        Ok(ParsedSpace { name, matches, excludes })
    }

    fn parse_space_rule(e: &quick_xml::events::BytesStart) -> Result<SpaceRule, String> {
        let mut rule = SpaceRule {
            name_contains: None,
            when_orientation: None,
            min_width: None,
            min_height: None,
            under_width: None,
            under_height: None,
        };

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"nameContains" => rule.name_contains = Some(value),
                b"whenOrientation" => {
                    rule.when_orientation = Some(match value.as_str() {
                        "portrait" => Orientation::Portrait,
                        "landscape" => Orientation::Landscape,
                        "never" => Orientation::Never,
                        _ => return Err(format!("invalid orientation: {}", value)),
                    });
                }
                b"minWidth" => rule.min_width = Some(Self::parse_measure_ref(&value)?),
                b"minHeight" => rule.min_height = Some(Self::parse_measure_ref(&value)?),
                b"underWidth" => rule.under_width = Some(Self::parse_measure_ref(&value)?),
                b"underHeight" => rule.under_height = Some(Self::parse_measure_ref(&value)?),
                _ => {}
            }
        }

        Ok(rule)
    }

    fn parse_measure_ref(s: &str) -> Result<MeasureRef, String> {
        if let Ok(n) = s.parse::<u32>() {
            Ok(MeasureRef::Literal(n))
        } else {
            Ok(MeasureRef::Name(s.to_string()))
        }
    }

    fn parse_frame(reader: &mut Reader<&[u8]>, start: &quick_xml::events::BytesStart) -> Result<ParsedFrame, String> {
        let mut name = None;

        for attr in start.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            if attr.key.as_ref() == b"name" {
                name = Some(String::from_utf8_lossy(&attr.value).to_string());
            }
        }

        let name = name.ok_or("Frame missing name attribute")?;
        let mut panes = Vec::new();
        let mut buf = Vec::new();

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(Event::Empty(ref e)) if e.name().as_ref() == b"Pane" => {
                    panes.push(Self::parse_pane(e)?);
                }
                Ok(Event::End(ref e)) if e.name().as_ref() == b"Frame" => break,
                Ok(Event::Eof) => return Err("unexpected EOF in Frame".to_string()),
                Err(e) => return Err(format!("XML parse error: {}", e)),
                _ => {}
            }
            buf.clear();
        }

        if panes.is_empty() {
            return Err(format!("Frame '{}' has no Panes", name));
        }

        Ok(ParsedFrame { name, panes })
    }

    fn parse_pane(e: &quick_xml::events::BytesStart) -> Result<ParsedPane, String> {
        let mut x = None;
        let mut y = None;
        let mut width = None;
        let mut height = None;

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value_str = String::from_utf8_lossy(&attr.value);

            match attr.key.as_ref() {
                b"x" => x = Some(Fraction::parse(&value_str)?),
                b"y" => y = Some(Fraction::parse(&value_str)?),
                b"width" => width = Some(Fraction::parse(&value_str)?),
                b"height" => height = Some(Fraction::parse(&value_str)?),
                _ => {}
            }
        }

        match (x, y, width, height) {
            (Some(x), Some(y), Some(w), Some(h)) => Ok(ParsedPane { x, y, width: w, height: h }),
            _ => Err("Pane missing required attributes (x, y, width, height)".to_string()),
        }
    }

    fn parse_layout(reader: &mut Reader<&[u8]>, start: &quick_xml::events::BytesStart) -> Result<ParsedLayout, String> {
        let mut name = None;
        let mut space = None;

        for attr in start.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"name" => name = Some(value),
                b"space" => space = Some(value),
                _ => {}
            }
        }

        let name = name.ok_or("Layout missing name attribute")?;
        let mut needed_measures = Vec::new();
        let mut root_shapes = Vec::new();
        let mut buf = Vec::new();

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(Event::Empty(ref e)) if e.name().as_ref() == b"Needs" => {
                    for attr in e.attributes() {
                        let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
                        if attr.key.as_ref() == b"measure" {
                            needed_measures.push(String::from_utf8_lossy(&attr.value).to_string());
                        }
                    }
                }
                Ok(Event::Start(ref e)) if e.name().as_ref() == b"Shape" => {
                    root_shapes.push(Self::parse_shape(reader, e)?);
                }
                Ok(Event::Empty(ref e)) if e.name().as_ref() == b"Shape" => {
                    return Err("Shape with no children not allowed at Layout level (must have children or use <Leaf/>)".to_string());
                }
                Ok(Event::End(ref e)) if e.name().as_ref() == b"Layout" => break,
                Ok(Event::Eof) => return Err("unexpected EOF in Layout".to_string()),
                Err(e) => return Err(format!("XML parse error: {}", e)),
                _ => {}
            }
            buf.clear();
        }

        if root_shapes.is_empty() {
            return Err(format!("Layout '{}' missing Shape", name));
        }

        // For now, wrap multiple shapes in a single composite root
        // The flatten logic will handle concatenating results from multiple top-level shapes
        let root_shape = if root_shapes.len() == 1 {
            root_shapes.into_iter().next().unwrap()
        } else {
            // Create synthetic "multi" frame that will be handled specially during flattening
            ParsedShape {
                frame: "__multi__".to_string(),
                when_orientation: None,
                min_width: None,
                min_height: None,
                under_width: None,
                under_height: None,
                children: root_shapes.into_iter().map(ShapeChild::Shape).collect(),
            }
        };

        Ok(ParsedLayout {
            name,
            space,
            needed_measures,
            root_shape,
        })
    }

    fn parse_shape(reader: &mut Reader<&[u8]>, start: &quick_xml::events::BytesStart) -> Result<ParsedShape, String> {
        let mut shape = Self::parse_shape_attrs(start)?;
        let mut buf = Vec::new();

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(Event::Start(ref e)) if e.name().as_ref() == b"Shape" => {
                    let child_shape = Self::parse_shape(reader, e)?;
                    shape.children.push(ShapeChild::Shape(child_shape));
                }
                Ok(Event::Empty(ref e)) => {
                    match e.name().as_ref() {
                        b"Shape" => {
                            return Err("Empty Shape (<Shape/>) not allowed as child (use <Include/>)".to_string());
                        }
                        b"Include" => {
                            let include = Self::parse_include(e)?;
                            shape.children.push(ShapeChild::Include(include));
                        }
                        // Legacy elements - deprecated but kept for backwards compatibility during migration
                        b"Leaf" => {
                            eprintln!("LAYOUT: WARNING <Leaf/> is deprecated, use <Include/> instead");
                            let include = LayoutInclude {
                                layout: None,
                                condition: IncludeCondition {
                                    when_orientation: None,
                                    min_width: None,
                                    under_width: None,
                                    min_height: None,
                                    under_height: None,
                                    name_contains: None,
                                },
                            };
                            shape.children.push(ShapeChild::Include(include));
                        }
                        b"Drop" => {
                            // <Drop/> maps to <Include whenOrientation="never"/>
                            let include = LayoutInclude {
                                layout: None,
                                condition: IncludeCondition {
                                    when_orientation: Some(Orientation::Never),
                                    min_width: None,
                                    under_width: None,
                                    min_height: None,
                                    under_height: None,
                                    name_contains: None,
                                },
                            };
                            shape.children.push(ShapeChild::Include(include));
                        }
                        _ => {}
                    }
                }
                Ok(Event::End(ref e)) if e.name().as_ref() == b"Shape" => break,
                Ok(Event::Eof) => return Err("unexpected EOF in Shape".to_string()),
                Err(e) => return Err(format!("XML parse error: {}", e)),
                _ => {}
            }
            buf.clear();
        }

        Ok(shape)
    }

    fn parse_shape_attrs(e: &quick_xml::events::BytesStart) -> Result<ParsedShape, String> {
        let mut frame = None;
        let mut when_orientation = None;
        let mut min_width = None;
        let mut min_height = None;
        let mut under_width = None;
        let mut under_height = None;

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"frame" => frame = Some(value),
                b"whenOrientation" => {
                    when_orientation = Some(match value.as_str() {
                        "portrait" => Orientation::Portrait,
                        "landscape" => Orientation::Landscape,
                        "never" => Orientation::Never,
                        _ => return Err(format!("invalid orientation: {}", value)),
                    });
                }
                b"minWidth" => min_width = Some(Self::parse_measure_ref(&value)?),
                b"minHeight" => min_height = Some(Self::parse_measure_ref(&value)?),
                b"underWidth" => under_width = Some(Self::parse_measure_ref(&value)?),
                b"underHeight" => under_height = Some(Self::parse_measure_ref(&value)?),
                _ => {}
            }
        }

        let frame = frame.ok_or("Shape missing required frame attribute")?;

        Ok(ParsedShape {
            frame,
            when_orientation,
            min_width,
            min_height,
            under_width,
            under_height,
            children: Vec::new(),
        })
    }

    fn parse_include(e: &quick_xml::events::BytesStart) -> Result<LayoutInclude, String> {
        let mut layout = None;
        let mut when_orientation = None;
        let mut min_width = None;
        let mut under_width = None;
        let mut min_height = None;
        let mut under_height = None;
        let mut name_contains = None;

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"layout" => layout = Some(value),
                b"whenOrientation" => {
                    when_orientation = Some(match value.as_str() {
                        "portrait" => Orientation::Portrait,
                        "landscape" => Orientation::Landscape,
                        "never" => Orientation::Never,
                        _ => return Err(format!("invalid orientation: {}", value)),
                    });
                }
                b"minWidth" => {
                    min_width = Some(value.parse::<u32>()
                        .map_err(|_| format!("invalid minWidth (must be literal integer): {}", value))?);
                }
                b"underWidth" => {
                    under_width = Some(value.parse::<u32>()
                        .map_err(|_| format!("invalid underWidth (must be literal integer): {}", value))?);
                }
                b"minHeight" => {
                    min_height = Some(value.parse::<u32>()
                        .map_err(|_| format!("invalid minHeight (must be literal integer): {}", value))?);
                }
                b"underHeight" => {
                    under_height = Some(value.parse::<u32>()
                        .map_err(|_| format!("invalid underHeight (must be literal integer): {}", value))?);
                }
                b"nameContains" => name_contains = Some(value),
                _ => {}
            }
        }

        Ok(LayoutInclude {
            layout,
            condition: IncludeCondition {
                when_orientation,
                min_width,
                under_width,
                min_height,
                under_height,
                name_contains,
            },
        })
    }

    fn parse_layout_action(e: &quick_xml::events::BytesStart) -> Result<ParsedLayoutAction, String> {
        let mut key = None;
        let mut layout = None;
        let mut traverse = None;
        let mut mirror_x = None;
        let mut mirror_y = None;

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"key" => key = Some(value),
                b"layout" => layout = Some(value),
                b"traverse" => {
                    traverse = Some(match value.as_str() {
                        "xfyf" => TraverseOrder::XfYf,
                        "xfyr" => TraverseOrder::XfYr,
                        "xryf" => TraverseOrder::XrYf,
                        "xryr" => TraverseOrder::XrYr,
                        "yfxf" => TraverseOrder::YfXf,
                        "yfxr" => TraverseOrder::YfXr,
                        "yrxf" => TraverseOrder::YrXf,
                        "yrxr" => TraverseOrder::YrXr,
                        _ => return Err(format!("invalid traverse: {}", value)),
                    });
                }
                b"mirrorX" => {
                    mirror_x = Some(match value.as_str() {
                        "keep" => MirrorMode::Keep,
                        "flip" => MirrorMode::Flip,
                        _ => return Err(format!("invalid mirrorX: {}", value)),
                    });
                }
                b"mirrorY" => {
                    mirror_y = Some(match value.as_str() {
                        "keep" => MirrorMode::Keep,
                        "flip" => MirrorMode::Flip,
                        _ => return Err(format!("invalid mirrorY: {}", value)),
                    });
                }
                _ => {}
            }
        }

        match (key, layout, traverse, mirror_x, mirror_y) {
            (Some(k), Some(l), Some(t), Some(mx), Some(my)) => {
                Ok(ParsedLayoutAction {
                    key: k,
                    layout: l,
                    traverse: t,
                    mirror_x: mx,
                    mirror_y: my,
                })
            }
            _ => Err("LayoutAction missing required attributes".to_string()),
        }
    }

    fn parse_display_move(e: &quick_xml::events::BytesStart) -> Result<ParsedDisplayMove, String> {
        let mut key = None;
        let mut target = None;
        let mut wrap = true; // default per schema

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"key" => key = Some(value),
                b"target" => {
                    target = Some(match value.as_str() {
                        "next" => DisplayMoveTarget::Next { wrap },
                        "prev" => DisplayMoveTarget::Prev { wrap },
                        idx => {
                            let index = idx.parse::<usize>()
                                .map_err(|_| format!("invalid target index: {}", idx))?;
                            DisplayMoveTarget::Index(index)
                        }
                    });
                }
                b"wrap" => {
                    wrap = match value.as_str() {
                        "true" => true,
                        "false" => false,
                        _ => return Err(format!("invalid wrap value: {}", value)),
                    };
                }
                _ => {}
            }
        }

        // Update wrap in target if it was set after target parsing
        let target = match target {
            Some(DisplayMoveTarget::Next { .. }) => DisplayMoveTarget::Next { wrap },
            Some(DisplayMoveTarget::Prev { .. }) => DisplayMoveTarget::Prev { wrap },
            Some(t) => t,
            None => return Err("DisplayMove missing target attribute".to_string()),
        };

        match key {
            Some(k) => Ok(ParsedDisplayMove { key: k, target }),
            None => Err("DisplayMove missing key attribute".to_string()),
        }
    }
}

// ============================================================================
// SECTION 6: Validation (operates on parse-time structures)
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
// SECTION 7: Runtime construction (parse-time → runtime)
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

            // Create new DisplayInfo with adjusted dimensions and embedded quirks
            DisplayInfo::new(
                display.index,
                display.design_width,
                display.design_height - max_bottom_inset as f64,
                display.name.clone(),
                runtime_quirks.clone(),
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

    fn space_matches_display(&self, space: &ParsedSpace, display: &DisplayProps) -> bool {
        // Multiple Match elements are OR'd
        let any_match = space.matches.is_empty() || space.matches.iter().any(|rule| {
            self.rule_matches_display(rule, display, &self.measures)
        });

        if !any_match {
            return false;
        }

        // Multiple Exclude elements are OR'd (any exclude vetoes)
        let any_exclude = space.excludes.iter().any(|rule| {
            self.rule_matches_display(rule, display, &self.measures)
        });

        !any_exclude
    }

    fn rule_matches_display(&self, rule: &SpaceRule, display: &DisplayProps, measures: &HashMap<String, u32>) -> bool {
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
            let threshold = self.resolve_measure_ref(min_width, measures);
            if display.width < threshold as f64 {
                return false;
            }
        }

        if let Some(ref min_height) = rule.min_height {
            let threshold = self.resolve_measure_ref(min_height, measures);
            if display.height < threshold as f64 {
                return false;
            }
        }

        if let Some(ref under_width) = rule.under_width {
            let threshold = self.resolve_measure_ref(under_width, measures);
            if display.width >= threshold as f64 {
                return false;
            }
        }

        if let Some(ref under_height) = rule.under_height {
            let threshold = self.resolve_measure_ref(under_height, measures);
            if display.height >= threshold as f64 {
                return false;
            }
        }

        true
    }

    fn resolve_measure_ref(&self, mref: &MeasureRef, measures: &HashMap<String, u32>) -> u32 {
        match mref {
            MeasureRef::Literal(n) => *n,
            MeasureRef::Name(name) => *measures.get(name).unwrap_or(&0),
        }
    }

    // Recursively flatten shape tree to leaf panes using pure rational arithmetic
    // Parent context is defined by fractions (all in range 0..1 relative to display)


    fn sort_pane_list(&self, rects: &mut Vec<PixelRect>, traverse: TraverseOrder) {
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

        // Combined two-level sort:
        // 1. Primary: descending by area (largest first = zoom-out progression)
        // 2. Secondary: traverse order using pane centers (for panes of same area)
        rects.sort_by(|a, b| {
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
}

// ============================================================================
// SECTION 8: Public API (operates on runtime structures only)
// ============================================================================

impl Form {
    /// Load form from file (assumes file already exists due to ensure_fresh_default_config)
    pub fn load_from_file(displays: &[DisplayInfo]) -> Self {
        eprintln!("DEBUG: Form::load_from_file called with {} displays", displays.len());
        for (i, d) in displays.iter().enumerate() {
            eprintln!("DEBUG:   display[{}]: name='{}' size={}x{}", i, d.name, d.design_width, d.design_height);
        }

        let config_path = Self::config_path();

        // Parse XML from config file
        let xml_content = match fs::read_to_string(&config_path) {
            Ok(content) => content,
            Err(e) => {
                eprintln!("CONFIG: ERROR failed to read config: {}", e);
                return Self::from_embedded_default(displays);
            }
        };

        let parsed = match ParsedForm::from_xml(&xml_content) {
            Ok(p) => p,
            Err(e) => {
                println!("LAYOUT: parse_error ({})", e);
                println!("LAYOUT: all LayoutActions disabled - fix {} and restart", config_path.display());
                return Self::empty();
            }
        };

        // Validate references
        if let Err(errors) = parsed.validate() {
            for err in &errors {
                println!("LAYOUT: ERROR {}", err);
            }
            println!("LAYOUT: all LayoutActions disabled - fix {} and restart", config_path.display());
            return Self::empty();
        }

        // Build runtime
        let form = parsed.build_runtime(displays);

        // Log summary
        eprintln!("LAYOUT: loaded {} Measures, {} Spaces, {} Frames, {} Layouts, {} LayoutActions",
            parsed.measures.len(), parsed.spaces.len(), parsed.frames.len(),
            parsed.layouts.len(), parsed.layout_actions.len());
        eprintln!("LAYOUT: loaded {} layout actions for on-demand computation",
            form.layouts.len());

        form
    }

    fn from_embedded_default(displays: &[DisplayInfo]) -> Self {
        eprintln!("LAYOUT: falling back to embedded default");
        match ParsedForm::from_xml(DEFAULT_FORM_XML) {
            Ok(parsed) => parsed.build_runtime(displays),
            Err(e) => {
                eprintln!("LAYOUT: FATAL embedded default parse failed: {}", e);
                Self::empty()
            }
        }
    }

    fn empty() -> Self {
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

    fn config_path() -> PathBuf {
        let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
        path.push(".config");
        path.push("paneboard");
        path.push("form.xml");
        path
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

    /// Adjust raw displays using parsed quirks (for caller caching)
    /// Caller should invoke this once at startup and cache the result
    #[cfg(target_os = "macos")]
    pub fn adjust_displays(&self, displays: &[DisplayInfo]) -> Vec<DisplayInfo> {
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

            // Create new DisplayInfo with adjusted dimensions and embedded quirks
            DisplayInfo::new(
                display.index,
                display.design_width,
                display.design_height - max_bottom_inset as f64,
                display.name.clone(),
                self.quirks.clone(),
            )
        }).collect()
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

// ============================================================================
// SECTION 9: Startup Configuration Deployment
// ============================================================================

/// Ensure fresh default config is deployed at startup
/// Archives existing form.xml to form.xml.NNNNN and writes embedded default
/// Called at app startup (not lazily) to guarantee latest config is used
pub fn ensure_fresh_default_config() {
    let mut config_path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    config_path.push(".config");
    config_path.push("paneboard");

    // Ensure config directory exists
    if let Err(e) = fs::create_dir_all(&config_path) {
        eprintln!("CONFIG: ERROR failed to create config directory: {}", e);
        return;
    }

    config_path.push("form.xml");

    // Archive existing form.xml if present
    if config_path.exists() {
        // Find next available suffix starting at 10000
        let mut suffix = 10000;
        let mut archive_path;
        loop {
            archive_path = config_path.with_file_name(format!("form.xml.{}", suffix));
            if !archive_path.exists() {
                break;
            }
            suffix += 1;
        }

        // Rename existing file to archive
        match fs::rename(&config_path, &archive_path) {
            Ok(()) => {
                eprintln!("CONFIG: archived existing form.xml -> form.xml.{}", suffix);
            }
            Err(e) => {
                eprintln!("CONFIG: ERROR failed to archive form.xml: {}", e);
                return;
            }
        }
    }

    // Deploy embedded default to config path
    match fs::write(&config_path, DEFAULT_FORM_XML) {
        Ok(()) => {
            eprintln!("CONFIG: deployed embedded default to {}", config_path.display());
        }
        Err(e) => {
            eprintln!("CONFIG: ERROR failed to deploy default config: {}", e);
        }
    }
}
