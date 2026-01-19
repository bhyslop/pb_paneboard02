// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

//! macOS Seatbelt sandbox initialization
//!
//! This module permanently drops network access for the process using Apple's
//! sandbox_init() API. While deprecated, this API remains functional and provides
//! a simple way to guarantee no network access without requiring code signing
//! or entitlements.
//!
//! The sandbox is applied at process startup and cannot be undone.

#![cfg(target_os = "macos")]

use std::ffi::c_char;

extern "C" {
    fn sandbox_init(profile: *const c_char, flags: u64, errorbuf: *mut *mut c_char) -> i32;
    fn sandbox_free_error(errorbuf: *mut c_char);
}

/// Permanently drops network access for this process using macOS Seatbelt sandbox.
///
/// This is a one-way operation - cannot be undone for the lifetime of the process.
/// Uses the deprecated but functional sandbox_init() API.
///
/// # Policy
/// The policy allows all operations EXCEPT network access:
/// - `(allow default)` - permit everything by default
/// - `(deny network*)` - deny all network operations (connect, bind, listen, etc.)
///
/// # Panics
/// Exits the process if sandbox cannot be established. PaneBoard refuses to
/// run without network isolation.
pub fn drop_network_access() {
    // Seatbelt policy: allow everything except network operations
    // This blocks: socket creation, connect, bind, listen, send, recv, etc.
    let policy = b"(version 1)(allow default)(deny network*)\0";

    let mut errorbuf: *mut c_char = std::ptr::null_mut();
    let result = unsafe {
        sandbox_init(policy.as_ptr() as *const c_char, 0, &mut errorbuf)
    };

    if result != 0 {
        let err_msg = if !errorbuf.is_null() {
            let msg = unsafe { std::ffi::CStr::from_ptr(errorbuf) }
                .to_string_lossy()
                .into_owned();
            unsafe { sandbox_free_error(errorbuf) };
            msg
        } else {
            "unknown error".to_string()
        };
        eprintln!();
        eprintln!("FATAL: Failed to initialize network sandbox: {}", err_msg);
        eprintln!("PaneBoard refuses to run without network isolation.");
        eprintln!();
        std::process::exit(1);
    }

    eprintln!("SANDBOX: Network access permanently blocked");
}
