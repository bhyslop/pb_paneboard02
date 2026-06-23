// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

//! Viewer conductor — paneboard as the diagram viewer's launchd-routed
//! lifecycle owner.
//!
//! Paneboard runs under a permanent `(deny network*)` seatbelt sandbox and
//! refuses to run without it. A process spawned DIRECTLY by paneboard
//! (posix_spawn / exec) inherits that sandbox and is network-denied, so it
//! could never listen on the viewer's advertised TCP port (verified
//! 2026-06-23: a direct child gets EPERM on both listen and connect). The
//! viewer is therefore launched INDEPENDENTLY through launchd — `/usr/bin/open`
//! of its `.app` bundle — which makes launchd the parent, so the viewer
//! escapes the sandbox and gets full networking. `open` itself runs fine under
//! the sandbox (it reaches launchd over Mach IPC, which `deny network*` does
//! not touch). Paneboard never reads the image bytes and never forks the
//! viewer.
//!
//! Lifecycle: `ensure_viewer()` rides the existing alt-tab window-switch event
//! (no new poll). On each gesture it checks whether the viewer is running; if
//! absent (first run, or the operator closed it) it relaunches it EMPTY — a
//! declared state the viewer renders gracefully ("waiting for a pushed
//! image…") — and the next pusher frame fills it. A respawn is a fresh process
//! with a fresh ephemeral port; the pusher reads the port-file every push, so
//! it picks up the new port with no pusher change.
//!
//! Placement is NOT the conductor's job. The switcher selects windows; window
//! geometry belongs to paneboard's layout chords. The viewer is a normal AX
//! window the operator tiles like any other — the conductor only spawns it and
//! keeps it alive, never moving or resizing it.
//!
//! The bundle path arrives via the `PBGV_VIEWER_APP` environment variable,
//! exported by the pbw workbench when it assembles the bundle at build time.
//! Absent that variable (paneboard launched outside the workbench), the
//! conductor disables itself with a one-time notice and the standalone viewer
//! still works on its own.

#![cfg(target_os = "macos")]

use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};

use block2::StackBlock;
use core_foundation_sys::base::CFTypeRef;
use objc2::msg_send;
use objc2_app_kit::NSWorkspace;

/// Bundle identifier minted for the viewer .app (matches viewer/macos/Info.plist).
const VIEWER_BUNDLE_ID: &str = "org.scaleinvariant.paneboard-viewer";

/// One-time notice latch for the "no bundle path" disabled state.
static NO_BUNDLE_WARNED: AtomicBool = AtomicBool::new(false);

/// Absolute path to the viewer .app bundle, from the build-time env export.
fn viewer_app_path() -> Option<String> {
    std::env::var("PBGV_VIEWER_APP").ok().filter(|s| !s.is_empty())
}

/// Ensure the viewer is running. Rides the alt-tab window-switch event; safe to
/// call from the event-tap thread. The work is marshalled to the main runloop
/// (NSWorkspace affinity), matching the overlay render path. Spawns only — never
/// touches the viewer's geometry.
pub unsafe fn ensure_viewer() {
    let block = StackBlock::new(|| {
        ensure_viewer_on_main();
    });

    let main_runloop = crate::pbmba_ax::CFRunLoopGetMain();
    crate::pbmba_ax::CFRunLoopPerformBlock(
        main_runloop,
        core_foundation::runloop::kCFRunLoopDefaultMode as CFTypeRef,
        &*block as *const _ as *const c_void,
    );
    crate::pbmba_ax::CFRunLoopWakeUp(main_runloop);
}

/// Main-thread body: relaunch the viewer if it is not running.
unsafe fn ensure_viewer_on_main() {
    let Some(app_path) = viewer_app_path() else {
        if !NO_BUNDLE_WARNED.swap(true, Ordering::SeqCst) {
            println!(
                "VIEWER: conductor disabled (PBGV_VIEWER_APP unset); standalone viewer unaffected"
            );
        }
        return;
    };

    if running_viewer_pid().is_none() {
        launch_viewer(&app_path);
    }
}

/// The pid of the running viewer app (by bundle id), or None if not running.
unsafe fn running_viewer_pid() -> Option<u32> {
    let workspace = NSWorkspace::sharedWorkspace();
    let apps = workspace.runningApplications();
    for i in 0..apps.len() {
        let app = apps.objectAtIndex(i);
        if let Some(bid) = app.bundleIdentifier() {
            if bid.to_string() == VIEWER_BUNDLE_ID {
                let pid: i32 = msg_send![&app, processIdentifier];
                if pid > 0 {
                    return Some(pid as u32);
                }
            }
        }
    }
    None
}

/// Launch the viewer through launchd, non-activating so it does not steal focus
/// mid-alt-tab. `open -g` hands off to launchd and returns immediately; the
/// short-lived `open` process is reaped off-thread to avoid a zombie.
unsafe fn launch_viewer(app_path: &str) {
    match std::process::Command::new("/usr/bin/open")
        .arg("-g") // do not bring to foreground — must not fight the alt-tab gesture
        .arg(app_path)
        .spawn()
    {
        Ok(mut child) => {
            std::thread::spawn(move || {
                let _ = child.wait();
            });
            println!("VIEWER: launch dispatched via launchd (open -g) -> {}", app_path);
        }
        Err(e) => eprintln!("VIEWER: launch failed: {e}"),
    }
}
