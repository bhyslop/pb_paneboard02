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

//! The clipboard predicate declines over ssh, where the execution host is not the station.
//!
//! A CLIPBOARD IS A STATION RESOURCE, which is the whole subject. A tool writes
//! only the clipboard of the host it runs on, so the predicate's true contract
//! is that the execution host IS the station; `SSH_CONNECTION` is the signature
//! of that identity failing, and the guard declines on it before probing
//! anything.
//!
//! THE DEFECT WAS A TRUE EXIT WITH NOTHING COPIED, which is why the probe is
//! planted rather than left to the station. A remote run found `clip.exe`, the
//! copy exited 0 onto a window station no desktop could paste from, and the
//! caller announced a copy the operator did not have. A hurdle reading the
//! station's own tools would measure which machine it happened to run on; one
//! that plants a tool certain to be found and certain to leave a trace measures
//! the guard.
//!
//! THE LOCAL CASE IS THE OTHER TWO'S POSITIVE CONTROL. A guard that declined
//! unconditionally, and a plant the probe never reached at all, both produce the
//! same silence the remote cases assert — so the third case drives the identical
//! seat with the signature absent and requires the planted tool to have run. A
//! pair of cases without it would be green about nothing.
//!
//! THE SIGNATURE IS UNSET RATHER THAN ASSUMED ABSENT in that case. This suite is
//! itself frequently driven over ssh, and a control inheriting the very variable
//! under test would fail on the station where the subject matters most.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;

/// The modules the predicate needs: the yelp module its log channel renders
/// through, and the command module the predicate itself stands in.
const BUJO_MODULES: &[&str] = &["buym_yelp.sh", "buc_command.sh"];

/// The payload every case copies.
///
/// ONE SPELLING, CARRYING NO SPACE AND NO WORD. It is handed to the predicate
/// and sought back out of the file the planted tool wrote, and a token needing
/// to be reshaped between those two uses can be reshaped in only one of them.
const BUJO_TEXT: &str = "HXQK9F2T";

/// What sshd sets, spelled as sshd spells it: client address and port, then
/// server address and port. The addresses are documentation range (RFC 5737),
/// so nothing here names a host anyone could reach.
const BUJO_REMOTE: &str = "198.51.100.7 51015 198.51.100.9 22";

/// Where the seat's scratch stands. Beneath the seat's own gitignored temp
/// root, so a plant does not dirty the repository the seat composed.
const BUJO_SCRATCH: &str = "temp/bujo";

/// What the coordinator prints when the predicate answered true, and when it
/// answered false. Named once and spent on both sides, so the shell's word and
/// the assertion's cannot drift apart.
const BUJO_COPIED: &str = "verdict copied";
const BUJO_DECLINED: &str = "verdict declined";

/// The cause the predicate is required to name.
///
/// PINNED DELIBERATELY, AND DUPLICATED DELIBERATELY. The predicate's message is
/// the whole of what the remote caller is left with, so the wording is the
/// subject rather than an implementation detail; a rewording that leaves this
/// phrase behind should red this case and be looked at.
const BUJO_CAUSE: &str = "the execution host is not the station";

/// The file the planted tool writes when it runs at all.
fn bujo_probed() -> String {
    format!("{}/probed.txt", BUJO_SCRATCH)
}

/// The transcript the log channel is pointed at.
fn bujo_transcript() -> String {
    format!("{}/transcript.txt", BUJO_SCRATCH)
}

/// Plant a clipboard tool that is certain to be found and certain to leave a
/// trace.
///
/// `pbcopy` IS THE ONE PLANTED because it is probed first: a tool the station
/// genuinely carries can then never win the race, so the hurdle's verdict does
/// not move with the desktop the suite is driven on. The tool is told where to
/// write through the environment rather than from its own argument zero,
/// because a script reached through `PATH` should not have to know how it was
/// spelled at the call.
fn bujo_plant() -> String {
    format!(
        "mkdir -p '{scratch}'\n\
         export BUJO_PROBED=\"${{PWD}}/{probed}\"\n\
         printf '%s\\n' '#!/bin/bash' 'cat > \"${{BUJO_PROBED}}\"' > '{scratch}/pbcopy'\n\
         chmod +x '{scratch}/pbcopy'\n\
         export PATH=\"${{PWD}}/{scratch}:${{PATH}}\"\n",
        scratch = BUJO_SCRATCH,
        probed = bujo_probed()
    )
}

/// Drive the predicate and report both halves of what it left behind.
///
/// THE CALL STANDS IN AN `if`, which is where a false answer has to be survived:
/// the body runs under `errexit`, and a predicate answering false bare would end
/// the coordinator before it could say so. The probed tool is reported beside the
/// verdict because either alone is satisfiable by an outcome nobody wants — a
/// decline after probing is still a probe, and an empty tool name after a copy is
/// still a copy.
fn bujo_verdict() -> String {
    format!(
        "if buc_clipboard_copy_predicate '{text}'; then\n\
         \x20 printf '{copied}\\n'\n\
         else\n\
         \x20 printf '{declined}\\n'\n\
         fi\n\
         printf 'tool [%s]\\n' \"${{z_buc_clipboard_tool}}\"\n",
        text = BUJO_TEXT,
        copied = BUJO_COPIED,
        declined = BUJO_DECLINED
    )
}

#[test]
fn bujo_a_a_remote_session_declines_before_probing_any_tool() {
    let bench = buah_Bench::buah_seat(
        "substrate-clipboard-remote",
        BUJO_MODULES,
        &format!(
            "export SSH_CONNECTION='{remote}'\n{plant}{verdict}",
            remote = BUJO_REMOTE,
            plant = bujo_plant(),
            verdict = bujo_verdict()
        ),
    );

    let said = bench.buah_drive(&[]);

    said.buah_thrived()
        .buah_carries(BUJO_DECLINED)
        .buah_lacks(BUJO_COPIED)
        .buah_carries("tool []");

    assert!(
        !bench.buah_stands(&bujo_probed()),
        "the planted tool ran: the guard declined AFTER probing rather than before it. \
         Said: {}",
        said.buah_text
    );
}

#[test]
fn bujo_b_the_declined_copy_names_the_remote_cause() {
    let bench = buah_Bench::buah_seat(
        "substrate-clipboard-cause",
        BUJO_MODULES,
        &format!(
            "{plant}\
             export BURD_TRANSCRIPT=\"${{PWD}}/{transcript}\"\n\
             export SSH_CONNECTION='{remote}'\n\
             {verdict}",
            plant = bujo_plant(),
            transcript = bujo_transcript(),
            remote = BUJO_REMOTE,
            verdict = bujo_verdict()
        ),
    );

    let said = bench.buah_drive(&[]);
    said.buah_thrived().buah_carries(BUJO_DECLINED);

    // THE CAUSE IS SOUGHT IN THE TRANSCRIPT AND NOWHERE ELSE, which is the half
    // of the contract a stream assertion could not carry: the predicate owes the
    // reason to the log and owes the streams silence, so finding the phrase in
    // what the child SAID would be the defect rather than the proof.
    let transcript = bench.buah_read(&bujo_transcript());
    assert!(
        transcript.contains(BUJO_CAUSE),
        "the transcript does not name the remote cause. Wanted: {}\nTranscript:\n{}",
        BUJO_CAUSE,
        transcript
    );
    said.buah_lacks(BUJO_CAUSE);
}

#[test]
fn bujo_c_a_local_session_still_probes_and_copies() {
    let bench = buah_Bench::buah_seat(
        "substrate-clipboard-local",
        BUJO_MODULES,
        &format!(
            "unset SSH_CONNECTION\n{plant}{verdict}",
            plant = bujo_plant(),
            verdict = bujo_verdict()
        ),
    );

    let said = bench.buah_drive(&[]);

    said.buah_thrived()
        .buah_carries(BUJO_COPIED)
        .buah_carries("tool [pbcopy]");

    assert_eq!(
        bench.buah_read(&bujo_probed()),
        BUJO_TEXT,
        "the planted tool did not receive the payload. Said: {}",
        said.buah_text
    );
}
// eof
