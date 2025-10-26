// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

/// Form Configuration Parser - XML Parsing Module
/// Extracts XML parsing logic and parse-time structures from pbgf_form.rs
///
/// This module contains:
/// - Fraction type for exact fractional proportions
/// - Parse-time structures (ParsedForm, ParsedSpace, ParsedFrame, etc.)
/// - XML parsing implementation using quick_xml

use quick_xml::events::Event;
use quick_xml::Reader;
use std::collections::HashMap;

// Import runtime types from pbgft_types
use crate::pbgft_types::DisplayMoveTarget;

// ============================================================================
// SECTION 1: Fraction type and helpers
// ============================================================================

/// Exact fractional proportion (no floating point until pixel conversion)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct Fraction {
    pub(crate) num: u32,
    pub(crate) den: u32,
}

impl Fraction {
    /// Parse from string: "3/10", "1", "0"
    pub(crate) fn parse(s: &str) -> Result<Self, String> {
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
    pub(crate) fn to_f64(&self) -> f64 {
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
    #[allow(dead_code)]
    pub(crate) fn add(&self, other: &Fraction) -> Fraction {
        Fraction {
            num: self.num * other.den + other.num * self.den,
            den: self.den * other.den,
        }.reduce()
    }

    /// Multiply two fractions: (a/b) * (c/d) = (ac) / (bd)
    pub(crate) fn mul(&self, other: &Fraction) -> Fraction {
        Fraction {
            num: self.num * other.num,
            den: self.den * other.den,
        }.reduce()
    }
}

// ============================================================================
// SECTION 3: Parse-time structures (discarded after validation)
// ============================================================================

pub(crate) struct ParsedForm {
    pub(crate) measures: HashMap<String, u32>,
    pub(crate) display_quirks: Vec<ParsedDisplayQuirk>,
    pub(crate) spaces: HashMap<String, ParsedSpace>,
    pub(crate) frames: HashMap<String, ParsedFrame>,
    pub(crate) layouts: HashMap<String, ParsedLayout>,
    pub(crate) layout_actions: Vec<ParsedLayoutAction>,
    pub(crate) display_moves: Vec<ParsedDisplayMove>,
}

pub(crate) struct ParsedDisplayQuirk {
    pub(crate) name_contains: String,
    pub(crate) platform: Platform,
    pub(crate) min_bottom_inset: u32,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Platform {
    MacOS,
    Windows,
    Linux,
}

#[derive(Clone)]
pub(crate) struct ParsedSpace {
    pub(crate) name: String,
    pub(crate) matches: Vec<SpaceRule>,
    pub(crate) excludes: Vec<SpaceRule>,
}

#[derive(Clone)]
pub(crate) struct SpaceRule {
    pub(crate) name_contains: Option<String>,
    pub(crate) when_orientation: Option<Orientation>,
    pub(crate) min_width: Option<MeasureRef>,
    pub(crate) min_height: Option<MeasureRef>,
    pub(crate) under_width: Option<MeasureRef>,
    pub(crate) under_height: Option<MeasureRef>,
}

#[derive(Clone, PartialEq, Eq, Debug)]
pub(crate) enum Orientation {
    Portrait,
    Landscape,
    Never,  // Always fails (used for explicit drops via <Include whenOrientation="never"/>)
}

#[derive(Clone)]
pub(crate) enum MeasureRef {
    Name(String),
    Literal(u32),
}

#[derive(Clone)]
pub(crate) struct ParsedFrame {
    pub(crate) name: String,
    pub(crate) panes: Vec<ParsedPane>,
}

#[derive(Clone)]
pub(crate) struct ParsedPane {
    pub(crate) x: Fraction,
    pub(crate) y: Fraction,
    pub(crate) width: Fraction,
    pub(crate) height: Fraction,
}

pub(crate) struct ParsedLayout {
    pub(crate) name: String,
    pub(crate) space: Option<String>, // references Space name
    pub(crate) needed_measures: Vec<String>,
    pub(crate) root_shape: ParsedShape,
}

#[derive(Clone)]
pub(crate) struct ParsedShape {
    pub(crate) frame: String, // references Frame name (now required)
    pub(crate) when_orientation: Option<Orientation>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    pub(crate) min_width: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    pub(crate) min_height: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    pub(crate) under_width: Option<MeasureRef>,
    #[allow(dead_code)] // For future conditional Shape evaluation
    pub(crate) under_height: Option<MeasureRef>,
    pub(crate) children: Vec<ShapeChild>,
}

#[derive(Clone)]
pub(crate) enum ShapeChild {
    Shape(ParsedShape),
    Include(LayoutInclude),
}

/// Include directive: terminal pane, sublayout reference, or conditional drop
#[derive(Clone)]
pub(crate) struct LayoutInclude {
    pub(crate) layout: Option<String>,  // If Some, inline this layout's structure
    pub(crate) condition: IncludeCondition,
}

/// Conditional evaluation for Include (all attributes AND-ed)
#[derive(Clone)]
pub(crate) struct IncludeCondition {
    pub(crate) when_orientation: Option<Orientation>,
    pub(crate) min_width: Option<u32>,      // Literal pixels only (no Measure references)
    pub(crate) under_width: Option<u32>,
    pub(crate) min_height: Option<u32>,
    pub(crate) under_height: Option<u32>,
    pub(crate) name_contains: Option<String>,  // Case-insensitive substring match
}

pub(crate) struct ParsedLayoutAction {
    pub(crate) key: String,
    pub(crate) layout: String, // references Layout name
    pub(crate) traverse: TraverseOrder,
    pub(crate) mirror_x: MirrorMode,
    pub(crate) mirror_y: MirrorMode,
}

#[derive(Clone, Copy)]
pub(crate) enum TraverseOrder {
    XfYf, XfYr, XrYf, XrYr,
    YfXf, YfXr, YrXf, YrXr,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum MirrorMode {
    Keep,
    Flip,
}

pub(crate) struct ParsedDisplayMove {
    pub(crate) key: String,
    pub(crate) target: DisplayMoveTarget,
}

// ============================================================================
// SECTION 5: XML Parsing (builds parse-time structures)
// ============================================================================

impl ParsedForm {
    pub(crate) fn from_xml(xml: &str) -> Result<Self, String> {
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

        let frame = frame.ok_or("Shape missing required 'frame' attribute")?;

        Ok(ParsedShape {
            frame,
            when_orientation,
            min_width,
            min_height,
            under_width,
            under_height,
            children: Vec::new(), // populated by caller
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
                        .map_err(|_| format!("Include minWidth must be literal pixels: {}", value))?);
                }
                b"underWidth" => {
                    under_width = Some(value.parse::<u32>()
                        .map_err(|_| format!("Include underWidth must be literal pixels: {}", value))?);
                }
                b"minHeight" => {
                    min_height = Some(value.parse::<u32>()
                        .map_err(|_| format!("Include minHeight must be literal pixels: {}", value))?);
                }
                b"underHeight" => {
                    under_height = Some(value.parse::<u32>()
                        .map_err(|_| format!("Include underHeight must be literal pixels: {}", value))?);
                }
                b"nameContains" => {
                    name_contains = Some(value);
                }
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
        let mut traverse = TraverseOrder::XfYf; // default
        let mut mirror_x = MirrorMode::Keep;    // default
        let mut mirror_y = MirrorMode::Keep;    // default

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"key" => key = Some(value),
                b"layout" => layout = Some(value),
                b"traverse" => {
                    traverse = match value.to_lowercase().as_str() {
                        "xfyf" => TraverseOrder::XfYf,
                        "xfyr" => TraverseOrder::XfYr,
                        "xryf" => TraverseOrder::XrYf,
                        "xryr" => TraverseOrder::XrYr,
                        "yfxf" => TraverseOrder::YfXf,
                        "yfxr" => TraverseOrder::YfXr,
                        "yrxf" => TraverseOrder::YrXf,
                        "yrxr" => TraverseOrder::YrXr,
                        _ => return Err(format!("invalid traverse order: {}", value)),
                    };
                }
                b"mirrorX" => {
                    mirror_x = match value.as_str() {
                        "keep" => MirrorMode::Keep,
                        "flip" => MirrorMode::Flip,
                        _ => return Err(format!("invalid mirrorX: {}", value)),
                    };
                }
                b"mirrorY" => {
                    mirror_y = match value.as_str() {
                        "keep" => MirrorMode::Keep,
                        "flip" => MirrorMode::Flip,
                        _ => return Err(format!("invalid mirrorY: {}", value)),
                    };
                }
                _ => {}
            }
        }

        match (key, layout) {
            (Some(k), Some(l)) => Ok(ParsedLayoutAction {
                key: k,
                layout: l,
                traverse,
                mirror_x,
                mirror_y,
            }),
            _ => Err("LayoutAction missing required attributes (key, layout)".to_string()),
        }
    }

    fn parse_display_move(e: &quick_xml::events::BytesStart) -> Result<ParsedDisplayMove, String> {
        let mut key = None;
        let mut next = None;
        let mut prev = None;
        let mut index = None;
        let mut wrap = false; // default

        for attr in e.attributes() {
            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
            let value = String::from_utf8_lossy(&attr.value).to_string();

            match attr.key.as_ref() {
                b"key" => key = Some(value),
                b"target" => {
                    // New unified target attribute
                    match value.as_str() {
                        "next" => next = Some(true),
                        "prev" => prev = Some(true),
                        _ => {
                            // Try parsing as numeric index
                            index = Some(value.parse::<usize>()
                                .map_err(|_| format!("invalid target: {}", value))?);
                        }
                    }
                }
                // Legacy boolean attributes
                b"next" => if value == "true" { next = Some(true); },
                b"prev" => if value == "true" { prev = Some(true); },
                b"index" => {
                    index = Some(value.parse::<usize>()
                        .map_err(|_| format!("invalid index: {}", value))?);
                }
                b"wrap" => wrap = value == "true",
                _ => {}
            }
        }

        let key = key.ok_or("DisplayMove missing key attribute")?;

        let target = match (next, prev, index) {
            (Some(true), None, None) => DisplayMoveTarget::Next { wrap },
            (None, Some(true), None) => DisplayMoveTarget::Prev { wrap },
            (None, None, Some(i)) => DisplayMoveTarget::Index(i),
            _ => return Err("DisplayMove must specify exactly one of: next, prev, or index".to_string()),
        };

        Ok(ParsedDisplayMove { key, target })
    }
}
