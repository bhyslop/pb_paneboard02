// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    if env::var("CARGO_CFG_TARGET_OS").unwrap_or_default() == "macos" {
        println!("cargo:rustc-link-lib=framework=IOKit");
        println!("cargo:rustc-link-lib=framework=CoreFoundation");
        println!("cargo:rustc-link-lib=framework=Foundation");
        println!("cargo:rustc-link-lib=framework=Cocoa");

        // Compile Swift shim
        compile_swift_shim();
    }
}

fn compile_swift_shim() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let src_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("src");

    let swift_file = src_dir.join("pbmbo_observer.swift");
    let header_file = src_dir.join("pbmbo_observer.h");
    let obj_file = out_dir.join("pbmbo_observer.o");

    // Get SDK path dynamically
    let sdk_output = Command::new("xcrun")
        .args(&["--show-sdk-path"])
        .output()
        .expect("Failed to find SDK path");

    let sdk_path = String::from_utf8_lossy(&sdk_output.stdout).trim().to_string();

    // Compile Swift to object file
    let status = Command::new("swiftc")
        .arg("-parse-as-library")
        .arg("-c")
        .arg(&swift_file)
        .arg("-import-objc-header")
        .arg(&header_file)
        .arg("-o")
        .arg(&obj_file)
        .arg("-sdk")
        .arg(&sdk_path)
        .status()
        .expect("Failed to compile Swift code");

    if !status.success() {
        panic!("Swift compilation failed");
    }

    // Link the object file
    println!("cargo:rustc-link-search=native={}", out_dir.display());
    println!("cargo:rustc-link-lib=static=pbmbo_observer");

    // Create static library from object file
    let lib_file = out_dir.join("libpbmbo_observer.a");
    let ar_status = Command::new("ar")
        .arg("rcs")
        .arg(&lib_file)
        .arg(&obj_file)
        .status()
        .expect("Failed to create static library");

    if !ar_status.success() {
        panic!("Failed to create static library");
    }

    // Link Swift runtime libraries
    // Get Swift library path
    let swift_lib_output = Command::new("xcrun")
        .args(&["--show-sdk-path"])
        .output()
        .expect("Failed to find SDK path");

    let sdk_path = String::from_utf8_lossy(&swift_lib_output.stdout).trim().to_string();
    let swift_lib_path = format!("{}/usr/lib/swift", sdk_path);

    println!("cargo:rustc-link-search=native={}", swift_lib_path);
    println!("cargo:rustc-link-lib=dylib=swiftCore");
    println!("cargo:rustc-link-lib=dylib=swiftFoundation");
    println!("cargo:rustc-link-lib=dylib=swiftAppKit");
    println!("cargo:rustc-link-lib=dylib=swiftCoreFoundation");

    // Rebuild if Swift source changes
    println!("cargo:rerun-if-changed={}", swift_file.display());
    println!("cargo:rerun-if-changed={}", header_file.display());
}