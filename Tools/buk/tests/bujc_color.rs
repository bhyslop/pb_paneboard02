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

//! The dispatch reads the operator's colour preference and writes its own verdict.
//!
//! Ported from the bash bench's `dispatch-color` fixture, four cases, all four
//! carried. The subject is the read-input/write-verdict split: `BURE_COLOR` is
//! the operator's optional say and is never written; the resolved `0`/`1` lands
//! under `BURD_COLOR` instead.
//!
//! THE PORT DISSOLVES THE REASON THESE CASES WERE AWKWARD. Their bash header
//! spends a paragraph explaining why each must drive a fresh bash process: the
//! bench had already kindled the dispatch regime, which locks every enrolled
//! `BURD_` name readonly, so the resolver could not run in the case's own
//! subshell without dying on a locked assignment. A hurdle stands outside every
//! one of those processes already, and the seat it drives kindles nothing before
//! the probe runs. The explanation is no longer owed; only the probe survives.
//!
//! THE VERDICT VARIABLE IS UNSET AHEAD OF THE PROBE, which the bash case did not
//! do. It inherited whatever `BURD_COLOR` the bench's own dispatch had already
//! resolved and asserted an exact result anyway — sound only while the resolver
//! overwrites unconditionally, which is a property of the thing under test
//! rather than a premise a case may lean on. Unsetting the output before
//! resolving it removes the lean.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;

/// The dispatch spine is reached by path rather than sourced by the coordinator.
///
/// IT IS EXECUTE-ONLY AND SOURCING IT IS INERT, which is what makes the probe
/// below legitimate: the spine carries top-level assignments of its own and
/// declares no sentinel, being bootstrap infrastructure rather than a module, so
/// it is entered in a process of its own and never in the coordinator's.
const BUJC_MODULES: &[&str] = &[];

/// The token the probe prints its reading under.
///
/// A MARKER RATHER THAN A BARE PAIR, because the dispatch merges the
/// coordinator's streams and a reading spelled as `0|1` alone could be matched
/// by an unrelated line of a transcript path.
const BUJC_SAID: &str = "bujc_verdict=";

/// Drive the resolver in a fresh process under a controlled environment and hand
/// back what it resolved.
///
/// The reading is `<BURD_COLOR>|<BURE_COLOR or UNSET>`: the verdict the dispatch
/// wrote, beside what became of the operator's own input.
fn bujc_resolve(name: &str, env: &[&str]) -> buk::buah_hurdle::buah_Said {
    let mut probe = String::from("env -u BURD_COLOR");
    for word in env {
        probe.push(' ');
        probe.push_str(word);
    }
    probe.push_str(
        " bash -c 'source \"${BURD_BUK_DIR}/bud_dispatch.sh\"\n\
         zbud_resolve_color\n\
         printf \"",
    );
    probe.push_str(BUJC_SAID);
    probe.push_str("%s|%s\\n\" \"${BURD_COLOR}\" \"${BURE_COLOR:-UNSET}\"'\n");

    buah_Bench::buah_seat(name, BUJC_MODULES, &probe).buah_drive(&[])
}

#[test]
fn bujc_no_color_forces_the_verdict_dark_and_leaves_the_operator_input_alone() {
    // THE STANDARD ENVIRONMENT VARIABLE WINS OVER AN EXPLICIT PREFERENCE, which
    // is the one ordering an operator cannot discover by experiment: `NO_COLOR`
    // is a convention the estate honours, and honouring it means overriding a
    // `BURE_COLOR` that says otherwise.
    //
    // AND THE INPUT SURVIVES THE OVERRIDE. The verdict is dark, and `BURE_COLOR`
    // still reads `1` — a resolver that expressed the override by rewriting the
    // operator's own variable would satisfy the first half and fail the second.
    bujc_resolve("substrate-color-no-color", &["NO_COLOR=1", "BURE_COLOR=1"])
        .buah_thrived()
        .buah_carries(&format!("{}0|1", BUJC_SAID));
}

#[test]
fn bujc_an_explicit_preference_for_colour_resolves_lit() {
    bujc_resolve(
        "substrate-color-explicit-one",
        &["-u", "NO_COLOR", "BURE_COLOR=1"],
    )
    .buah_thrived()
    .buah_carries(&format!("{}1|1", BUJC_SAID));
}

#[test]
fn bujc_an_explicit_preference_against_colour_resolves_dark() {
    // THE PAIR ABOVE AND HERE ARE EACH OTHER'S CONTROL: a resolver hard-wired to
    // either verdict passes exactly one of them.
    bujc_resolve(
        "substrate-color-explicit-zero",
        &["-u", "NO_COLOR", "BURE_COLOR=0"],
    )
    .buah_thrived()
    .buah_carries(&format!("{}0|0", BUJC_SAID));
}

#[test]
fn bujc_an_absent_preference_is_never_invented() {
    // THE WHOLE POINT OF THE READ-INPUT/WRITE-VERDICT SPLIT. A dispatch resolving
    // a verdict must not leave an operator-ambient `BURE_COLOR` standing behind
    // it, because every child of that dispatch would then inherit a preference
    // the operator never expressed — and would be unable to tell it from one they
    // did.
    bujc_resolve(
        "substrate-color-auto",
        &["-u", "NO_COLOR", "-u", "BURE_COLOR", "TERM=dumb"],
    )
    .buah_thrived()
    .buah_carries(&format!("{}0|UNSET", BUJC_SAID));
}
// eof
