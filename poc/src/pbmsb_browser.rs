// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#![cfg(target_os = "macos")]

// Chromium-based app detection for diagnostic tagging
const CHROMIUM_BUNDLE_IDS: &[&str] = &[
    "com.google.Chrome",
    "com.google.Chrome.canary",
    "org.chromium.Chromium",
    "com.brave.Browser",
    "com.microsoft.Edge",
    "com.vivaldi.Vivaldi",
    "company.thebrowser.Browser", // Arc
];

pub fn is_chromium_based(bundle_id: &str) -> bool {
    CHROMIUM_BUNDLE_IDS.contains(&bundle_id)
}
