// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

/// Form Configuration I/O
/// Handles config file management, archiving, and path resolution
///
/// Responsibilities:
/// - Config directory and file path resolution (~/.config/paneboard/form.xml)
/// - Automatic archiving of existing configs (form.xml.NNNNN)
/// - Deployment of embedded default configuration at startup
/// - File I/O operations for loading and saving config

use std::fs;
use std::path::PathBuf;

// ============================================================================
// SECTION 1: Embedded default configuration
// ============================================================================

const DEFAULT_FORM_XML: &str = include_str!("../form.default.xml");

// ============================================================================
// SECTION 2: Config path resolution
// ============================================================================

/// Resolve the standard config file path
pub fn config_path() -> PathBuf {
    let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    path.push(".config");
    path.push("paneboard");
    path.push("form.xml");
    path
}

// ============================================================================
// SECTION 3: Config deployment and archiving
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

// ============================================================================
// SECTION 4: Config file I/O
// ============================================================================

/// Load config file contents from standard location
pub fn load_config_file() -> Result<String, std::io::Error> {
    let path = config_path();
    fs::read_to_string(&path)
}

/// Get embedded default config content
pub fn get_default_config() -> &'static str {
    DEFAULT_FORM_XML
}
