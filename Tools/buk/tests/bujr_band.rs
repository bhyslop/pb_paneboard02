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

//! The precision exit-code band: which deaths keep their number, and which lose it.
//!
//! Ported from the bash bench's `band-survival` fixture, six cases, all six
//! carried.
//!
//! THE PORT MOVED THESE CASES OUT OF A CONTAINER, and that is the whole change.
//! Five of the six ran their death inside `zbuto_invoke`'s isolation subshell and
//! read the status back in the bench's own process — an observation taken from
//! inside the process tree that dies, which is the posture the obedience sheaf
//! disqualifies (BKSOB-Obedience.adoc "Observation Posture"). Here each death is
//! raised BARE at a coordinator's top level: nothing contains it, nothing on the
//! left of `||` swallows the shell's own exit, and the number is read in this
//! process, which the dispatch cannot reach.
//!
//! WHAT THE SIXTH STILL SAYS THAT THE OTHER FIVE DO NOT. Once every hurdle rides
//! the seat's whole chain — tabtarget, trampoline, launcher stub, dispatch,
//! coordinator — it is fair to ask what a survival case is still for. The five
//! vary the DEATH and hold the chain fixed: each asks which number a given
//! membrane produces. The sixth varies the CHAIN and holds the death fixed: it
//! raises the rejection where the estate's own fixture raises it, inside a
//! command substitution beneath a `|| buc_die_now`, and asks whether the number
//! reaches the caller from there. A capture is the one place in this path where a
//! status is genuinely at risk of being read, discarded and replaced, so the
//! sixth is a reading of the path rather than a sixth reading of the membrane.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;

/// The band member this kit's self-test raises, spelled as `bubc_constants.sh`
/// spells it.
///
/// NAMED HERE AND NOT COMPUTED. The constant is a substrate fact, and a hurdle
/// deriving it from the band's base and offsets would go green against a band
/// that had moved underneath it — which is the one thing these hurdles exist to
/// notice.
const BUJR_SELFTEST: i32 = 123;

/// A nonzero status standing outside the band.
const BUJR_STRANGER: i32 = 42;

/// What an imprecise death takes.
const BUJR_IMPRECISE: i32 = 1;

/// The modules a band reading needs: the band tinder `buc_reject` refuses to work
/// without, the yelp module the diagnostic renders through, and the console
/// library that carries both doors.
const BUJR_MODULES: &[&str] = &["bubc_constants.sh", "buym_yelp.sh", "buc_command.sh"];

/// A coordinator raising one death bare, with a context set so the diagnostic
/// names this hurdle rather than an empty operation.
fn bujr_raise(name: &str, line: &str, want: i32) {
    buah_Bench::buah_seat(
        name,
        BUJR_MODULES,
        &format!("buc_context \"bujr\"\n{}\n", line),
    )
    .buah_drive(&[])
    .buah_took(want);
}

#[test]
fn bujr_an_in_band_status_beneath_a_die_chain_re_exits_unchanged() {
    // THE MEMBRANE'S WHOLE PURPOSE. A door that rejected deliberately, with a
    // number its caller can act on, must not have that number replaced by the
    // generic death of whatever wrapper caught it.
    bujr_raise(
        "substrate-band-in",
        &format!(
            "( exit {} ) || buc_die_now \"in-band failure beneath a die chain\"",
            BUJR_SELFTEST
        ),
        BUJR_SELFTEST,
    );
}

#[test]
fn bujr_an_ordinary_failure_beneath_a_die_chain_stays_imprecise() {
    // THE COMPLEMENT, AND THE CONTROL FOR THE HURDLE ABOVE: a membrane that
    // passed everything through would satisfy that one and fail this.
    bujr_raise(
        "substrate-band-plain",
        "false || buc_die_now \"plain failure beneath a die chain\"",
        BUJR_IMPRECISE,
    );
}

#[test]
fn bujr_an_out_of_band_status_beneath_a_die_chain_launders_to_imprecise() {
    // A NONZERO THAT IS NOT A BAND MEMBER IS NOT A VERDICT, so it is not carried
    // out as one. Without this the membrane would promote any stray status a
    // wrapped command happened to take into something a caller would read as
    // deliberate.
    bujr_raise(
        "substrate-band-out",
        &format!(
            "( exit {} ) || buc_die_now \"out-of-band failure beneath a die chain\"",
            BUJR_STRANGER
        ),
        BUJR_IMPRECISE,
    );
}

#[test]
fn bujr_a_direct_rejection_exits_with_its_band_code() {
    bujr_raise(
        "substrate-band-reject",
        &format!(
            "buc_reject {} \"direct deliberate rejection\"",
            BUJR_SELFTEST
        ),
        BUJR_SELFTEST,
    );
}

#[test]
fn bujr_a_rejection_outside_the_band_is_itself_refused() {
    // AN OUT-OF-BAND CODE AT THE ORIGIN IS A PROGRAMMING ERROR, not a verdict to
    // deliver, so the door refuses to raise it and dies imprecisely instead. A
    // gate that passed the number through would let a typo'd code reach a caller
    // wearing the authority of a deliberate rejection.
    bujr_raise(
        "substrate-band-reject-out",
        &format!(
            "buc_reject {} \"out-of-band code is a programming error\"",
            BUJR_STRANGER
        ),
        BUJR_IMPRECISE,
    );
}

#[test]
fn bujr_a_rejection_survives_a_capture_and_the_whole_exec_path() {
    // THE ESTATE'S OWN FIXTURE SHAPE, spelled as `bux_band_chain` spells it. The
    // rejection is raised INSIDE a command substitution: bash runs that in a
    // subshell whose status the assignment then carries, so this is the one place
    // in the path where a deliberate number is genuinely at risk of being read as
    // an ordinary failure and replaced.
    //
    // THE SECOND `buc_die_now` IS THE HURDLE'S OWN TRIPWIRE. It stands on the line
    // after the chain and is reached only if the rejection did NOT propagate — so
    // a defect here does not merely change the number, it changes it to the
    // imprecise death that line raises, and the hurdle says which of the two it
    // got.
    buah_Bench::buah_seat(
        "substrate-band-survival",
        BUJR_MODULES,
        &format!(
            "buc_context \"bujr\"\n\
             z_out=$(buc_reject {code} \"deliberate self-test rejection\") \\\n\
             \x20 || buc_die_now \"band chain: origin rejected beneath capture\"\n\
             buc_die_now \"band chain: rejection failed to propagate (captured: '${{z_out}}')\"\n",
            code = BUJR_SELFTEST
        ),
    )
    .buah_drive(&[])
    .buah_took(BUJR_SELFTEST);
}
// eof
