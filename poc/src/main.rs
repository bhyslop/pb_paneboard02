// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

// Generic modules (cross-platform)
mod pbgc_core;
mod pbgr_retry;
mod pbgk_keylog;
mod pbgft_types;
mod pbgfp_parse;
mod pbgfr_resolve;
mod pbgfc_config;

// macOS base/shared modules
#[cfg(target_os = "macos")] mod pbmba_ax;
#[cfg(target_os = "macos")] mod pbmbd_display;
#[cfg(target_os = "macos")] mod pbmbe_eventtap;
#[cfg(target_os = "macos")] mod pbmbo_overlay;
#[cfg(target_os = "macos")] mod pbmbk_keymap;

// macOS switcher modules
#[cfg(target_os = "macos")] mod pbmsb_browser;
#[cfg(target_os = "macos")] mod pbmsm_mru;
#[cfg(target_os = "macos")] mod pbmsa_alttab;
#[cfg(target_os = "macos")] mod pbmbo_observer;

// macOS clipboard modules
#[cfg(target_os = "macos")] mod pbmcl_clipboard;

// macOS pane modules
#[cfg(target_os = "macos")] mod pbmp_pane;

// macOS sandbox module
#[cfg(target_os = "macos")] mod pbmbs_sandbox;

#[cfg(not(target_os = "macos"))]
fn main() {
    eprintln!("This PoC currently only supports macOS");
    std::process::exit(1);
}

#[cfg(target_os = "macos")]
fn main() {
    // Initialize network sandbox FIRST - before any other code runs
    // This permanently blocks all network access for this process
    pbmbs_sandbox::drop_network_access();

    unsafe { pbmbe_eventtap::run_quadrant_poc(); }
}