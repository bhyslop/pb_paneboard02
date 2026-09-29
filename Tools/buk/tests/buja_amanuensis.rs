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

//! Amanuensis mode: the dispatch names the log family and writes none of it.
//!
//! Ported from the bash bench's `amanuensis-mode` fixture, six cases, all six
//! carried. The mode is the third of the Log Family Law: the dispatch composes
//! the family's three names, exports them across the exec boundary, creates no
//! file and tees nothing, so the coordinator writes the record itself.
//!
//! A DISPATCH DECLARES ITS MODE BEFORE ANY WORK RUNS, which is why every case
//! here drives a dispatch of its own rather than reading the one it is running
//! under. The bash cases reached that conclusion first and the port keeps their
//! shape: a sub-dispatch is spawned with the mode's flags set, pointed at a probe
//! coordinator that reports the environment it was handed. What changed is where
//! the sub-dispatch's scratch stands — under the hurdle's own seat rather than
//! under a bench temp directory six other fixtures were also writing into — and
//! who counts the log directory afterwards, which is now this process.
//!
//! THE LOGGED CONTROL IS NOT DECORATION AND IS NOT DROPPED. Two of these hurdles
//! assert an ABSENCE — that no member was created — and an absence reads green
//! whether the mode worked or the probe looked in the wrong directory entirely.
//! The control drives the same probe through the same helper with the flag empty
//! and asserts all three members appear. That this pace has now twice caught a
//! hurdle passing for the wrong reason is the argument for keeping it.

#![deny(warnings)]
#![allow(non_camel_case_types)]

use buk::buah_hurdle::buah_Bench;

/// The coordinator drives a dispatch rather than sourcing the kit, so it sources
/// nothing itself.
const BUJA_MODULES: &[&str] = &[];

/// The tokens the outer coordinator reports its scratch under.
const BUJA_LOGS: &str = "buja_logs=";
const BUJA_REPORT: &str = "buja_report=";

/// How many members a logged dispatch's family holds.
const BUJA_FAMILY: usize = 3;

/// Where a drive's sub-dispatch scratch stood.
struct buja_Where {
    logs: String,
    report: String,
}

/// Compose a coordinator that lays down a probe and drives one sub-dispatch
/// under the named mode flags.
///
/// THE THREE FLAGS ARE PASSED ON EVERY DRIVE, empty standing for a flag the
/// tabtarget does not carry — which is how the dispatch itself reads them, so an
/// empty value exercises the same branch an absent one would. The bash helper
/// made the same choice and for the same reason.
fn buja_drive(
    name: &str,
    amanuensis: &str,
    no_log: &str,
    interactive: &str,
) -> (buah_Bench, buk::buah_hurdle::buah_Said, buja_Where) {
    let body = format!(
        // The scratch stands under this seat's own temp directory and is reported
        // before anything can fail, so a hurdle whose sub-dispatch is SUPPOSED to
        // die still learns where to look for what it must not find.
        "z_logs=\"${{BURD_TEMP_DIR}}/buja-logs\"\n\
         z_report=\"${{BURD_TEMP_DIR}}/buja-report.env\"\n\
         z_probe=\"${{BURD_TEMP_DIR}}/buja-coordinator.sh\"\n\
         mkdir -p \"${{z_logs}}\"\n\
         printf 'buja_logs=%s\\n'   \"${{z_logs}}\"\n\
         printf 'buja_report=%s\\n' \"${{z_report}}\"\n\
         cat > \"${{z_probe}}\" <<BUJA_PROBE\n\
         #!/bin/bash\n\
         {{\n\
         \x20 printf 'buja_last=\\\"%s\\\"\\\\n' \"\\${{BURD_LOG_LAST:-}}\"\n\
         \x20 printf 'buja_same=\\\"%s\\\"\\\\n' \"\\${{BURD_LOG_SAME:-}}\"\n\
         \x20 printf 'buja_hist=\\\"%s\\\"\\\\n' \"\\${{BURD_LOG_HIST:-}}\"\n\
         \x20 printf 'buja_temp=\\\"%s\\\"\\\\n' \"\\${{BURD_TEMP_DIR:-}}\"\n\
         }} > \"${{z_report}}\"\n\
         echo \"buja probe coordinator ran\"\n\
         BUJA_PROBE\n\
         chmod +x \"${{z_probe}}\"\n\
         env \"BURV_LOG_DIR=${{z_logs}}\" \\\n\
         \x20 \"BURD_COORDINATOR_SCRIPT=${{z_probe}}\" \\\n\
         \x20 \"BURD_AMANUENSIS={amanuensis}\" \\\n\
         \x20 \"BURD_NO_LOG={no_log}\" \\\n\
         \x20 \"BURD_INTERACTIVE={interactive}\" \\\n\
         \x20 bash \"${{BURD_BUK_DIR}}/bud_dispatch.sh\" \"buja-probe.LogFamily.sh\"\n",
        amanuensis = amanuensis,
        no_log = no_log,
        interactive = interactive
    );

    let bench = buah_Bench::buah_seat(name, BUJA_MODULES, &body);
    let said = bench.buah_drive(&[]);
    let where_ = buja_Where {
        logs: buja_after(&said.buah_text, BUJA_LOGS),
        report: buja_after(&said.buah_text, BUJA_REPORT),
    };
    (bench, said, where_)
}

/// The rest of the line a reported token opens.
fn buja_after(text: &str, token: &str) -> String {
    let at = text
        .find(token)
        .unwrap_or_else(|| panic!("the coordinator never reported {}:\n{}", token, text));
    text[at + token.len()..]
        .lines()
        .next()
        .unwrap_or_else(|| panic!("{} opened an empty line", token))
        .trim_end()
        .to_string()
}

/// What the probe coordinator said it was handed.
fn buja_report(at: &buja_Where) -> String {
    std::fs::read_to_string(&at.report)
        .unwrap_or_else(|err| panic!("the probe coordinator wrote no {}: {}", at.report, err))
}

/// The value a reported assignment carries, quotes taken off.
fn buja_field(report: &str, name: &str) -> String {
    let prefix = format!("{}=", name);
    let line = report
        .lines()
        .find(|line| line.starts_with(&prefix))
        .unwrap_or_else(|| panic!("no {} in the probe's report:\n{}", name, report));
    line[prefix.len()..].trim().trim_matches('"').to_string()
}

/// How many members stand in the driven log directory.
fn buja_members(at: &buja_Where) -> usize {
    std::fs::read_dir(&at.logs)
        .unwrap_or_else(|err| panic!("no log directory at {}: {}", at.logs, err))
        .count()
}

#[test]
fn buja_the_coordinator_is_handed_all_three_log_names() {
    let (_seat, said, at) = buja_drive("substrate-amanuensis-exports", "1", "", "");
    said.buah_thrived();
    let report = buja_report(&at);

    // THE NAMES ARE THE DISPATCH'S, WHICH IS THE HALF THAT MATTERS. A coordinator
    // could compose three plausible paths of its own and satisfy a presence
    // check; each name is therefore required to stand under the directory THIS
    // dispatch was pointed at, which the coordinator had no way to invent.
    for field in ["buja_last", "buja_same", "buja_hist"] {
        let path = buja_field(&report, field);
        assert!(!path.is_empty(), "{} never reached the coordinator", field);
        assert!(
            path.starts_with(&at.logs),
            "{} names {} which stands outside the dispatch's log directory {}",
            field,
            path,
            at.logs
        );
    }
}

#[test]
fn buja_the_dispatch_creates_the_directory_and_none_of_its_members() {
    let (_seat, said, at) = buja_drive("substrate-amanuensis-none", "1", "", "");
    said.buah_thrived();

    assert!(
        std::path::Path::new(&at.logs).is_dir(),
        "the log directory is absent: {}",
        at.logs
    );
    assert_eq!(
        buja_members(&at),
        0,
        "the dispatch wrote log members it owed none of, under {}",
        at.logs
    );
}

#[test]
fn buja_the_logged_control_writes_the_whole_family() {
    // THE CONTROL FOR THE ABSENCE ABOVE, driven through the same helper with the
    // flag empty. Without it, a probe that had looked at the wrong directory
    // would report the same zero the working mode reports.
    let (_seat, said, at) = buja_drive("substrate-amanuensis-control", "", "", "");
    said.buah_thrived();
    assert_eq!(
        buja_members(&at),
        BUJA_FAMILY,
        "a logged dispatch wrote {} member(s) under {}, where {} were owed — and the \
         absence the flagged hurdles assert is unproven without this",
        buja_members(&at),
        at.logs,
        BUJA_FAMILY
    );
}

#[test]
fn buja_the_fact_file_names_the_same_historical_member_the_coordinator_was_handed() {
    // TWO CHANNELS MUST AGREE. The coordinator is handed the path in its
    // environment and a later reader finds it in the fact file; a mode that
    // exported one path and recorded another would leave the two consumers of the
    // same run pointing at different records.
    let (_seat, said, at) = buja_drive("substrate-amanuensis-burx", "1", "", "");
    said.buah_thrived();
    let report = buja_report(&at);

    let temp = buja_field(&report, "buja_temp");
    assert!(!temp.is_empty(), "BURD_TEMP_DIR never reached the coordinator");

    let burx = std::path::Path::new(&temp).join("burx.env");
    let body = std::fs::read_to_string(&burx)
        .unwrap_or_else(|err| panic!("no fact file at {}: {}", burx.display(), err));

    let recorded = buja_field(&body, "BURX_LOG_HIST");
    assert!(
        !recorded.is_empty(),
        "BURX_LOG_HIST is empty where a path was composed; empty reads as no-log:\n{}",
        body
    );
    assert_eq!(
        recorded,
        buja_field(&report, "buja_hist"),
        "the fact file and the coordinator's environment name different records"
    );
}

#[test]
fn buja_the_mode_refuses_to_stand_beside_no_log() {
    // THE TWO FLAGS ASK FOR OPPOSITE THINGS — one says the coordinator will write
    // the record, the other says there is no record — so admitting both would
    // make the outcome depend on which branch happened to run last.
    let (_seat, said, at) = buja_drive("substrate-amanuensis-nolog", "1", "1", "");
    said.buah_died()
        .buah_carries("BURD_AMANUENSIS")
        .buah_carries("BURD_NO_LOG");

    // AND IT REFUSES BEFORE THE COORDINATOR RUNS, which is the part that makes
    // the refusal safe rather than merely correct: a mode conflict caught after
    // the work had started would leave half a record behind.
    assert!(
        !std::path::Path::new(&at.report).is_file(),
        "the coordinator ran despite the refusal"
    );
}

#[test]
fn buja_the_mode_refuses_to_stand_beside_interactive() {
    let (_seat, said, at) = buja_drive("substrate-amanuensis-interactive", "1", "", "1");
    said.buah_died()
        .buah_carries("BURD_AMANUENSIS")
        .buah_carries("BURD_INTERACTIVE");
    assert!(
        !std::path::Path::new(&at.report).is_file(),
        "the coordinator ran despite the refusal"
    );
}
// eof
