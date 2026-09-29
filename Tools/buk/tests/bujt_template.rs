// Copyright 2026 Scale Invariant, Inc.
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! The bootstrap seed's hand-placed shapes are what the kit's own doors emit.
//!
//! A first repository has a bootstrap to break: no door runs before a launcher
//! stub and a tabtarget exist to reach it, so those two are placed by hand. The
//! starter kit carries them as templates, and a template is a COPY — the
//! launcher and tabtarget doors in `buut_tabtarget.sh` are the only authority on
//! the shapes. This hurdle is what keeps the copy honest: it drives those doors
//! for the seed's own names and holds each template, its header stripped, byte
//! for byte against what they wrote.
//!
//! THE TEMPLATES ARE REACHED BY PATH AND NEVER COPIED, on the same ground the
//! substrate is. The starter kit stands beside the substrate under the tools
//! directory this suite was built from, so the hurdle judges the templates a
//! parcel would carry rather than a second spelling of them kept here.
//!
//! THE STRIP IS THE RECEIVER'S OWN INSTRUCTION, applied mechanically. Each
//! template names its header as every line after the first through the blank
//! line that ends it; the strip below deletes exactly that and nothing else, so
//! a template whose header outgrew its instruction fails here rather than
//! leaving its receiver with a file the doors would never have written.
//!
//! OBSERVED FROM OUTSIDE THE DISPATCH, as every hurdle here is.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;
use buk::buas_seat::buas_substrate;

/// The modules the emitting doors need, and no more.
const BUJT_MODULES: &[&str] = &[
    "buym_yelp.sh",
    "buc_command.sh",
    "buv_validation.sh",
    "burd_regime.sh",
    "buut_tabtarget.sh",
];

/// Where the coordinator lays what the doors wrote, relative to the seat.
const BUJT_EMITTED: &str = "emitted";

/// The seed tabtarget's name, which the template's header names as its target.
const BUJT_SEED_TABTARGET: &str = "buw-tt-cbl.CreateTabTargetBatchLogging";

/// A name the positive control writes under, standing for no door.
const BUJT_CONTROL_TABTARGET: &str = "bujt-control.NologControl";

/// The line every template's header carries, so the strip can prove it removed
/// a header rather than an arbitrary run of lines.
const BUJT_HEADER_MARK: &str = "# TEMPLATE";

/// Drive the launcher door and the two tabtarget doors in a composed seat, and
/// return the seat so its files can be read.
///
/// THE DOORS ARE THE KIT'S EXTERNAL FUNCTIONS, called as their workbench calls
/// them, with the folio in `BUZ_FOLIO`. Each resolves its paths from the working
/// directory, so the coordinator stands at the repository root the dispatch
/// composed and writes the stub under the moorings launcher subdirectory, where
/// the door looks for it.
fn zbujt_emit() -> buah_Bench {
    let bench = buah_Bench::buah_seat(
        "substrate-seed-templates",
        BUJT_MODULES,
        &format!(
            "buc_context \"bujt\"\n\
             zbuv_kindle\n\
             zburd_kindle\n\
             BURC_TOOLS_DIR=\"${{BURD_BUK_DIR%/*}}\"\n\
             BURC_TABTARGET_DIR=tt\n\
             zbuut_kindle\n\
             cd \"${{BURD_CONFIG_DIR}}/..\"\n\
             z_moorings=\"${{BURD_CONFIG_DIR##*/}}\"\n\
             mkdir -p Tools/buk \"${{z_moorings}}/${{BUBC_launchers_subdir}}\" tt {emitted}\n\
             : > Tools/buk/buw_workbench.sh\n\
             BUZ_FOLIO=Tools/buk/buw_workbench.sh buut_launcher buw_workbench\n\
             z_stub=\"${{z_moorings}}/${{BUBC_launchers_subdir}}/launcher.buw_workbench.sh\"\n\
             BUZ_FOLIO=\"${{z_stub}}\" buut_tabtarget_batch_logging {seed}\n\
             BUZ_FOLIO=\"${{z_stub}}\" buut_tabtarget_batch_nolog {control}\n\
             cp \"${{z_stub}}\" {emitted}/launcher.sh\n\
             cp tt/{seed}.sh {emitted}/tabtarget.sh\n\
             cp tt/{control}.sh {emitted}/control.sh\n",
            emitted = BUJT_EMITTED,
            seed = BUJT_SEED_TABTARGET,
            control = BUJT_CONTROL_TABTARGET,
        ),
    );
    bench.buah_drive(&[]).buah_thrived();
    bench
}

/// A starter kit template, its header stripped as the template instructs.
fn zbujt_template(basename: &str) -> String {
    let path = buas_substrate()
        .parent()
        .expect("the substrate stands under a tools directory")
        .join("bpk")
        .join(basename);
    let whole = std::fs::read_to_string(&path)
        .unwrap_or_else(|err| panic!("the tree carries no {}: {}", path.display(), err));

    let mut lines = whole.split_inclusive('\n');
    let first = lines.next().expect("a template has a first line");

    let mut header = String::new();
    let mut ended = false;
    for line in lines.by_ref() {
        if line == "\n" {
            ended = true;
            break;
        }
        header.push_str(line);
    }
    assert!(ended, "{} carries no blank line ending its header", path.display());
    assert!(
        header.contains(BUJT_HEADER_MARK),
        "what {} strips as its header carries no {:?} line:\n{}",
        path.display(),
        BUJT_HEADER_MARK,
        header
    );

    let mut kept = first.to_string();
    kept.extend(lines);
    kept
}

#[test]
fn bujt_the_seed_templates_are_what_the_doors_emit() {
    let bench = zbujt_emit();

    assert_eq!(
        zbujt_template("bpt_launcher.sh"),
        bench.buah_read(&format!("{}/launcher.sh", BUJT_EMITTED)),
        "the launcher template, stripped, is the stub the launcher door writes"
    );

    assert_eq!(
        zbujt_template("bpt_tabtarget.sh"),
        bench.buah_read(&format!("{}/tabtarget.sh", BUJT_EMITTED)),
        "the tabtarget template, stripped, is what the batch-and-logging door writes"
    );

    // THE POSITIVE CONTROL. The nolog door writes the same stub with one flag
    // line more, so a comparison that could not tell those two apart — an empty
    // read, a strip that swallowed the body, an emission that never happened —
    // would pass above and fail here.
    let control = bench.buah_read(&format!("{}/control.sh", BUJT_EMITTED));
    assert!(!control.is_empty(), "the control door wrote something");
    assert_ne!(
        zbujt_template("bpt_tabtarget.sh"),
        control,
        "the tabtarget template differs from the nolog door's output"
    );
}

// eof
