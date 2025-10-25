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
use crate::pbmbd_display::DisplayInfo;

// Stub DisplayInfo for non-macOS platforms (not used, but needed for compilation)
#[cfg(not(target_os = "macos"))]
#[derive(Clone)]
pub struct DisplayInfo {
    pub index: usize,
    pub width: f64,
    pub height: f64,
    pub name: String,
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

            Ok(Fraction { num, den })
        } else {
            // Whole number: "1", "0"
            let num = s.parse::<u32>()
                .map_err(|_| format!("invalid number: {}", s))?;
            Ok(Fraction { num, den: 1 })
        }
    }

    /// Convert to f64 for pixel calculations
    fn to_f64(&self) -> f64 {
        self.num as f64 / self.den as f64
    }
}

// ============================================================================
// SECTION 2: Runtime structures (kept after parse, no XML ties)
// ============================================================================

/// Runtime display quirk (platform-filtered, ready for runtime matching)
#[derive(Clone)]
struct RuntimeDisplayQuirk {
    name_contains: String,
    min_bottom_inset: u32,
}

/// Main runtime form - contains pre-computed pane lists per (key, display)
pub struct Form {
    // Pre-computed pane lists: (key_name, display_index) → sorted pixel rects
    pane_lists: HashMap<(String, usize), Vec<PixelRect>>,

    // DisplayMove bindings: key_name → target spec
    display_moves: HashMap<String, DisplayMoveTarget>,

    // DisplayQuirks: platform-filtered, ready for runtime application
    display_quirks: Vec<RuntimeDisplayQuirk>,

    // Current layout session state (ephemeral, reset on chord release)
    layout_session: Option<LayoutSession>,

    // DisplayMove session state (tracks original size for consecutive moves)
    display_move_session: Option<DisplayMoveSession>,
}

#[derive(Debug, Clone)]
pub struct PixelRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Clone)]
pub enum DisplayMoveTarget {
    Next { wrap: bool },
    Prev { wrap: bool },
    Index(usize),
}

struct LayoutSession {
    current_key: String,
    display_index: usize,
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

#[derive(Clone, PartialEq, Eq)]
enum Orientation {
    Portrait,
    Landscape,
}

#[derive(Clone)]
enum MeasureRef {
    Name(String),
    Literal(u32),
}

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
    frame: Option<String>, // references Frame name
    when_orientation: Option<Orientation>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    min_width: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    min_height: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    under_width: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    under_height: Option<MeasureRef>,
    children: Vec<ParsedShape>,
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
        let mut root_shape = None;
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
                    root_shape = Some(Self::parse_shape(reader, e)?);
                }
                Ok(Event::Empty(ref e)) if e.name().as_ref() == b"Shape" => {
                    root_shape = Some(Self::parse_empty_shape(e)?);
                }
                Ok(Event::End(ref e)) if e.name().as_ref() == b"Layout" => break,
                Ok(Event::Eof) => return Err("unexpected EOF in Layout".to_string()),
                Err(e) => return Err(format!("XML parse error: {}", e)),
                _ => {}
            }
            buf.clear();
        }

        let root_shape = root_shape.ok_or(format!("Layout '{}' missing Shape", name))?;

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
                    shape.children.push(Self::parse_shape(reader, e)?);
                }
                Ok(Event::Empty(ref e)) if e.name().as_ref() == b"Shape" => {
                    shape.children.push(Self::parse_empty_shape(e)?);
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

    fn parse_empty_shape(e: &quick_xml::events::BytesStart) -> Result<ParsedShape, String> {
        Self::parse_shape_attrs(e)
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

        if let Some(ref frame_name) = shape.frame {
            if let Some(frame) = frames.get(frame_name) {
                // Validate transitive frame resolution: children must align with panes
                if shape.children.len() > frame.panes.len() {
                    errors.push(format!(
                        "Layout '{}': Shape references Frame '{}' which has {} panes, but Shape has {} children (extras ignored)",
                        layout_name, frame_name, frame.panes.len(), shape.children.len()
                    ));
                }

                // Recursively validate children
                for child in &shape.children {
                    Self::validate_shape_tree(child, layout_name, frames, used_measures, errors);
                }
            } else {
                errors.push(format!("Layout '{}' references undefined Frame '{}'",
                    layout_name, frame_name));
            }
        } else {
            // No frame but has children - invalid
            if !shape.children.is_empty() {
                errors.push(format!(
                    "Layout '{}': Shape has {} children but no frame attribute",
                    layout_name, shape.children.len()
                ));
            }
        }
    }
}

// ============================================================================
// SECTION 7: Runtime construction (parse-time → runtime)
// ============================================================================

impl ParsedForm {
    /// Apply DisplayQuirks to adjust display dimensions
    /// Returns a new Vec<DisplayInfo> with adjusted width/height based on matching quirks
    fn apply_display_quirks(&self, displays: &[DisplayInfo]) -> Vec<DisplayInfo> {
        // Determine current platform
        #[cfg(target_os = "macos")]
        let current_platform = Platform::MacOS;
        #[cfg(target_os = "windows")]
        let current_platform = Platform::Windows;
        #[cfg(target_os = "linux")]
        let current_platform = Platform::Linux;

        displays.iter().map(|display| {
            // Find all quirks matching this display (by platform and nameContains)
            let matching_quirks = self.display_quirks.iter()
                .filter(|q| q.platform == current_platform)
                .filter(|q| display.name.contains(&q.name_contains));

            // Take MAX of all matching minBottomInset values
            let max_bottom_inset = matching_quirks
                .map(|q| q.min_bottom_inset)
                .max()
                .unwrap_or(0);

            if max_bottom_inset > 0 {
                eprintln!("LAYOUT: DisplayQuirk matched '{}' → applying {}px bottom inset",
                    display.name, max_bottom_inset);
                DisplayInfo {
                    index: display.index,
                    width: display.width,
                    height: display.height - max_bottom_inset as f64,
                    name: display.name.clone(),
                }
            } else {
                display.clone()
            }
        }).collect()
    }

    fn build_runtime(&self, displays: &[DisplayInfo]) -> Form {
        let mut pane_lists = HashMap::new();
        let mut display_moves = HashMap::new();

        // Build runtime DisplayQuirks (platform-filtered)
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

        // Apply DisplayQuirks to displays
        let adjusted_displays = self.apply_display_quirks(displays);

        // Build DisplayMove bindings
        for dm in &self.display_moves {
            display_moves.insert(dm.key.clone(), dm.target.clone());
        }

        // Build pane lists for each LayoutAction × Display
        for action in &self.layout_actions {
            if let Some(layout) = self.layouts.get(&action.layout) {
                for display in &adjusted_displays {
                    // Check if Layout's Space matches this display
                    if let Some(ref space_name) = layout.space {
                        if let Some(space) = self.spaces.get(space_name) {
                            if !self.space_matches_display(space, display) {
                                continue; // Skip this display for this layout
                            }
                        }
                    }

                    // Flatten shape tree to leaf panes
                    let leaf_panes = self.flatten_shape_tree(
                        &layout.root_shape,
                        display,
                        1.0, 0.0, 0.0, 1.0, 1.0 // parent context: full display
                    );

                    if leaf_panes.is_empty() {
                        continue;
                    }

                    // Convert to pixels FIRST (before mirroring)
                    let mut pixel_rects: Vec<PixelRect> = leaf_panes.iter()
                        .map(|p| PixelRect {
                            x: display.width * p.x.to_f64(),
                            y: display.height * p.y.to_f64(),
                            width: display.width * p.width.to_f64(),
                            height: display.height * p.height.to_f64(),
                        })
                        .collect();

                    // Apply mirroring in pixel space
                    Self::apply_mirroring_pixels(&mut pixel_rects, action.mirror_x, action.mirror_y, display.width, display.height);

                    // Cull undersized panes (< 100×100 pixels)
                    pixel_rects.retain(|r| r.width >= 100.0 && r.height >= 100.0);

                    if pixel_rects.is_empty() {
                        continue;
                    }

                    // Sort by area descending, then by traverse order
                    self.sort_pane_list(&mut pixel_rects, action.traverse);

                    // Debug: show final sorted pane sequence
                    eprintln!("LAYOUT: action={} display={} | {} panes after sort:",
                        action.key, display.index, pixel_rects.len());
                    for (idx, rect) in pixel_rects.iter().enumerate() {
                        let area = rect.width * rect.height;
                        eprintln!("  [{}] x={:.1} y={:.1} w={:.1} h={:.1} area={:.0}",
                            idx, rect.x, rect.y, rect.width, rect.height, area);
                    }

                    // Cache sorted list
                    pane_lists.insert((action.key.clone(), display.index), pixel_rects);
                }
            }
        }

        Form {
            pane_lists,
            display_moves,
            display_quirks: runtime_quirks,
            layout_session: None,
            display_move_session: None,
        }
    }

    fn space_matches_display(&self, space: &ParsedSpace, display: &DisplayInfo) -> bool {
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

    fn rule_matches_display(&self, rule: &SpaceRule, display: &DisplayInfo, measures: &HashMap<String, u32>) -> bool {
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

    // Recursively flatten shape tree to leaf panes
    // parent_* define the fractional context (relative to display)
    fn flatten_shape_tree(
        &self,
        shape: &ParsedShape,
        display: &DisplayInfo,
        parent_width: f64,
        parent_x: f64,
        parent_y: f64,
        parent_w_frac: f64,
        parent_h_frac: f64,
    ) -> Vec<ParsedPane> {
        let mut leaves = Vec::new();

        // Check conditional pruning
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

        // Check dimension constraints (would need to resolve MeasureRefs here)
        // For now, skip dimension constraints on Shapes (can be added later)

        // If no frame, this is an empty leaf shape
        let frame_name = match &shape.frame {
            Some(name) => name,
            None => return leaves,
        };

        let frame = match self.frames.get(frame_name) {
            Some(f) => f,
            None => return leaves,
        };

        // If no children, all frame panes are leaves
        if shape.children.is_empty() {
            for pane in &frame.panes {
                // Transform pane coordinates to display-relative fractions
                let abs_x = Fraction {
                    num: (parent_x * pane.x.den as f64 + pane.x.num as f64 * parent_w_frac) as u32,
                    den: pane.x.den,
                };
                let abs_y = Fraction {
                    num: (parent_y * pane.y.den as f64 + pane.y.num as f64 * parent_h_frac) as u32,
                    den: pane.y.den,
                };
                let abs_w = Fraction {
                    num: (pane.width.num as f64 * parent_w_frac) as u32,
                    den: pane.width.den,
                };
                let abs_h = Fraction {
                    num: (pane.height.num as f64 * parent_h_frac) as u32,
                    den: pane.height.den,
                };

                leaves.push(ParsedPane {
                    x: abs_x,
                    y: abs_y,
                    width: abs_w,
                    height: abs_h,
                });
            }
        } else {
            // Children subdivide parent panes
            for (i, pane) in frame.panes.iter().enumerate() {
                if let Some(child_shape) = shape.children.get(i) {
                    // Calculate absolute position and size for this pane
                    let pane_x = parent_x + pane.x.to_f64() * parent_w_frac;
                    let pane_y = parent_y + pane.y.to_f64() * parent_h_frac;
                    let pane_w = pane.width.to_f64() * parent_w_frac;
                    let pane_h = pane.height.to_f64() * parent_h_frac;

                    // Recursively flatten child
                    let child_leaves = self.flatten_shape_tree(
                        child_shape,
                        display,
                        parent_width,
                        pane_x,
                        pane_y,
                        pane_w,
                        pane_h,
                    );

                    leaves.extend(child_leaves);
                } else {
                    // No child shape = this pane is a leaf
                    let abs_x = Fraction {
                        num: (parent_x * pane.x.den as f64 + pane.x.num as f64 * parent_w_frac) as u32,
                        den: pane.x.den,
                    };
                    let abs_y = Fraction {
                        num: (parent_y * pane.y.den as f64 + pane.y.num as f64 * parent_h_frac) as u32,
                        den: pane.y.den,
                    };
                    let abs_w = Fraction {
                        num: (pane.width.num as f64 * parent_w_frac) as u32,
                        den: pane.width.den,
                    };
                    let abs_h = Fraction {
                        num: (pane.height.num as f64 * parent_h_frac) as u32,
                        den: pane.height.den,
                    };

                    leaves.push(ParsedPane {
                        x: abs_x,
                        y: abs_y,
                        width: abs_w,
                        height: abs_h,
                    });
                }
            }
        }

        leaves
    }

    /// Apply mirroring in pixel space (correct approach per code review)
    /// Mirroring formula: x' = display_width - x - width (for X flip)
    fn apply_mirroring_pixels(rects: &mut [PixelRect], mirror_x: MirrorMode, mirror_y: MirrorMode, display_width: f64, display_height: f64) {
        for rect in rects.iter_mut() {
            if mirror_x == MirrorMode::Flip {
                // x' = display_width - x - width
                rect.x = display_width - rect.x - rect.width;
            }

            if mirror_y == MirrorMode::Flip {
                // y' = display_height - y - height
                rect.y = display_height - rect.y - rect.height;
            }
        }
    }

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
}

// ============================================================================
// SECTION 8: Public API (operates on runtime structures only)
// ============================================================================

impl Form {
    /// Load form from file (assumes file already exists due to ensure_fresh_default_config)
    pub fn load_from_file(displays: &[DisplayInfo]) -> Self {
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
        eprintln!("LAYOUT: precomputed {} pane lists across {} displays",
            form.pane_lists.len(), displays.len());

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
            pane_lists: HashMap::new(),
            display_moves: HashMap::new(),
            display_quirks: Vec::new(),
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

    /// Get next pane in sequence for a given key and display
    /// Returns (PixelRect, pane_index) or None if no panes available
    pub fn get_next_pane(&mut self, key: &str, display_index: usize) -> Option<(PixelRect, usize)> {
        let pane_list = self.pane_lists.get(&(key.to_string(), display_index))?;

        if pane_list.is_empty() {
            return None;
        }

        // Check if we're continuing the same session
        let pane_index = if let Some(ref session) = self.layout_session {
            if session.current_key == key && session.display_index == display_index {
                // Continue session, advance index
                session.pane_index % pane_list.len()
            } else {
                // Different key or display, start new session
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
            display_index,
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

    /// Get minimum bottom inset for a display by name
    /// Returns the MAX of all matching DisplayQuirk minBottomInset values, or 0 if none match
    pub fn get_min_bottom_inset(&self, display_name: &str) -> u32 {
        self.display_quirks.iter()
            .filter(|q| display_name.contains(&q.name_contains))
            .map(|q| q.min_bottom_inset)
            .max()
            .unwrap_or(0)
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
