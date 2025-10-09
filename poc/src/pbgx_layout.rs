// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

/// Layout Configuration Parser
/// Parses ~/.config/paneboard/layouts.xml and provides layout sequences

use quick_xml::events::Event;
use quick_xml::Reader;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

// Embed the default layout template at compile time
const DEFAULT_LAYOUT_XML: &str = include_str!("../layouts.default.xml");

/// Single tiling combo: a rectangle defined as percentages of visibleFrame
#[derive(Debug, Clone)]
pub struct Combo {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

/// Layout manager holding all sequences
#[derive(Debug)]
pub struct LayoutManager {
    sequences: HashMap<String, Vec<Combo>>,
}

impl LayoutManager {
    /// Create a new layout manager with built-in default (2x2 quadrants)
    pub fn new() -> Self {
        Self {
            sequences: Self::default_quadrants(),
        }
    }

    /// Load from file, creating default template if missing
    pub fn load_from_file() -> Self {
        let config_path = Self::config_path();

        // Try to read user config
        match fs::read_to_string(&config_path) {
            Ok(xml_content) => {
                eprintln!("DEBUG: [LAYOUT] Parsing {}", config_path.display());
                match Self::parse_xml(&xml_content) {
                    Ok(manager) => {
                        eprintln!("DEBUG: [LAYOUT] Successfully loaded {} sequences", manager.sequences.len());
                        for (key, combos) in &manager.sequences {
                            eprintln!("DEBUG: [LAYOUT]   - {} → {} combos", key, combos.len());
                        }
                        manager
                    }
                    Err(e) => {
                        println!("LAYOUT: parse_error ({}), reverting to built-in default", e);
                        // Don't overwrite user's invalid file - parse embedded default instead
                        Self::parse_xml(DEFAULT_LAYOUT_XML)
                            .unwrap_or_else(|_| Self::new())
                    }
                }
            }
            Err(_) => {
                // Config file missing - create directory and write default template
                if let Some(parent) = config_path.parent() {
                    if let Err(e) = fs::create_dir_all(parent) {
                        eprintln!("DEBUG: [LAYOUT] Failed to create config directory: {}", e);
                        return Self::parse_xml(DEFAULT_LAYOUT_XML)
                            .unwrap_or_else(|_| Self::new());
                    }
                }

                match fs::write(&config_path, DEFAULT_LAYOUT_XML) {
                    Ok(()) => {
                        eprintln!("DEBUG: [LAYOUT] Created default config at {}", config_path.display());
                        // Parse the newly created file
                        Self::parse_xml(DEFAULT_LAYOUT_XML)
                            .unwrap_or_else(|_| Self::new())
                    }
                    Err(e) => {
                        eprintln!("DEBUG: [LAYOUT] Failed to write default config: {}", e);
                        // Fall back to embedded default
                        Self::parse_xml(DEFAULT_LAYOUT_XML)
                            .unwrap_or_else(|_| Self::new())
                    }
                }
            }
        }
    }

    /// Get config file path
    fn config_path() -> PathBuf {
        let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
        path.push(".config");
        path.push("paneboard");
        path.push("layouts.xml");
        path
    }

    /// Built-in 2x2 quadrant layout (WinSplit-style)
    fn default_quadrants() -> HashMap<String, Vec<Combo>> {
        let mut map = HashMap::new();

        // Upper-left: Insert
        map.insert("Insert".to_string(), vec![
            Combo { x: 0.0, y: 0.0, width: 50.0, height: 50.0 },
        ]);

        // Lower-left: Delete
        map.insert("Delete".to_string(), vec![
            Combo { x: 0.0, y: 50.0, width: 50.0, height: 50.0 },
        ]);

        // Upper-right: Home
        map.insert("Home".to_string(), vec![
            Combo { x: 50.0, y: 0.0, width: 50.0, height: 50.0 },
        ]);

        // Lower-right: End
        map.insert("End".to_string(), vec![
            Combo { x: 50.0, y: 50.0, width: 50.0, height: 50.0 },
        ]);

        map
    }

    /// Parse XML content
    fn parse_xml(xml: &str) -> Result<Self, String> {
        let mut reader = Reader::from_str(xml);
        reader.trim_text(true);

        let mut sequences: HashMap<String, Vec<Combo>> = HashMap::new();
        let mut current_key: Option<String> = None;
        let mut current_combos: Vec<Combo> = Vec::new();
        let mut warned_coords = false;

        let mut buf = Vec::new();

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(Event::Start(ref e)) => {
                    match e.name().as_ref() {
                        b"Sequence" => {
                            // Parse Sequence attributes
                            let mut key: Option<String> = None;

                            for attr in e.attributes() {
                                let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
                                match attr.key.as_ref() {
                                    b"key" => {
                                        key = Some(
                                            String::from_utf8_lossy(&attr.value).to_string()
                                        );
                                    }
                                    _ => {} // Ignore id, description
                                }
                            }

                            if let Some(k) = key {
                                current_key = Some(k);
                                current_combos.clear();
                            } else {
                                println!("LAYOUT: WARNING missing key attribute in Sequence");
                            }
                        }
                        _ => {}
                    }
                }
                Ok(Event::Empty(ref e)) => {
                    // Handle self-closing tags like <Combo ... />
                    if e.name().as_ref() == b"Combo" {
                        // Parse Combo attributes
                        let mut x: Option<f64> = None;
                        let mut y: Option<f64> = None;
                        let mut width: Option<f64> = None;
                        let mut height: Option<f64> = None;

                        for attr in e.attributes() {
                            let attr = attr.map_err(|e| format!("attribute error: {}", e))?;
                            let value_str = String::from_utf8_lossy(&attr.value);
                            let value = value_str.parse::<f64>()
                                .map_err(|_| format!("invalid number: {}", value_str))?;

                            match attr.key.as_ref() {
                                b"x" => x = Some(Self::clamp_coord(value, "x", &mut warned_coords)),
                                b"y" => y = Some(Self::clamp_coord(value, "y", &mut warned_coords)),
                                b"width" => width = Some(Self::clamp_coord(value, "width", &mut warned_coords)),
                                b"height" => height = Some(Self::clamp_coord(value, "height", &mut warned_coords)),
                                _ => {}
                            }
                        }

                        if let (Some(x), Some(y), Some(w), Some(h)) = (x, y, width, height) {
                            // Skip combos with zero width or height
                            if w == 0.0 || h == 0.0 {
                                if let Some(ref key) = current_key {
                                    println!("LAYOUT: WARNING skipping combo with zero dimension (key={})", key);
                                }
                            } else {
                                current_combos.push(Combo { x, y, width: w, height: h });
                            }
                        } else {
                            println!("LAYOUT: WARNING missing required Combo attributes");
                        }
                    }
                }
                Ok(Event::End(ref e)) => {
                    if e.name().as_ref() == b"Sequence" {
                        if let Some(key) = current_key.take() {
                            if current_combos.is_empty() {
                                println!("LAYOUT: WARNING empty sequence key={}", key);
                            } else {
                                sequences.insert(key, current_combos.clone());
                            }
                        }
                    }
                }
                Ok(Event::Eof) => break,
                Err(e) => return Err(format!("XML parse error: {}", e)),
                _ => {}
            }
            buf.clear();
        }

        if sequences.is_empty() {
            Err("no valid sequences found".to_string())
        } else {
            Ok(Self { sequences })
        }
    }

    /// Clamp coordinate to [0, 100] range
    fn clamp_coord(value: f64, name: &str, warned: &mut bool) -> f64 {
        if value < 0.0 {
            if !*warned {
                println!("LAYOUT: WARNING coord clamp {}={:.1} → 0.0", name, value);
                *warned = true;
            }
            0.0
        } else if value > 100.0 {
            if !*warned {
                println!("LAYOUT: WARNING coord clamp {}={:.1} → 100.0", name, value);
                *warned = true;
            }
            100.0
        } else {
            value
        }
    }

    /// Look up sequence by key name
    pub fn get_sequence(&self, key: &str) -> Option<&Vec<Combo>> {
        self.sequences.get(key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_quadrants() {
        let mgr = LayoutManager::new();
        assert!(mgr.get_sequence("Insert").is_some());
        assert!(mgr.get_sequence("Delete").is_some());
        assert!(mgr.get_sequence("Home").is_some());
        assert!(mgr.get_sequence("End").is_some());
    }

    #[test]
    fn test_parse_valid_xml() {
        let xml = r#"
            <LayoutManager>
                <Sequence key="Insert" id="7">
                    <Combo x="0.0" y="0.0" width="50.0" height="50.0"/>
                    <Combo x="0.0" y="0.0" width="66.67" height="50.0"/>
                </Sequence>
            </LayoutManager>
        "#;

        let mgr = LayoutManager::parse_xml(xml).unwrap();
        let seq = mgr.get_sequence("Insert").unwrap();
        assert_eq!(seq.len(), 2);
        assert_eq!(seq[0].width, 50.0);
        assert_eq!(seq[1].width, 66.67);
    }

    #[test]
    fn test_clamp_coordinates() {
        let xml = r#"
            <LayoutManager>
                <Sequence key="Test">
                    <Combo x="-5.0" y="105.0" width="50.0" height="50.0"/>
                </Sequence>
            </LayoutManager>
        "#;

        let mgr = LayoutManager::parse_xml(xml).unwrap();
        let seq = mgr.get_sequence("Test").unwrap();
        assert_eq!(seq[0].x, 0.0);
        assert_eq!(seq[0].y, 100.0);
    }

    #[test]
    fn test_skip_zero_dimension() {
        let xml = r#"
            <LayoutManager>
                <Sequence key="Test">
                    <Combo x="0.0" y="0.0" width="0.0" height="50.0"/>
                    <Combo x="0.0" y="0.0" width="50.0" height="50.0"/>
                </Sequence>
            </LayoutManager>
        "#;

        let mgr = LayoutManager::parse_xml(xml).unwrap();
        let seq = mgr.get_sequence("Test").unwrap();
        assert_eq!(seq.len(), 1); // Only the valid combo
    }
}
