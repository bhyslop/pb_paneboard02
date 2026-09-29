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

//! A bootstrap predating the contract meets a named refusal, not a bash accident.
//!
//! Ported from the bash bench's `stale-launcher` fixture, four cases, all four
//! carried. The guard stands at a seam between two custodies: the moorings
//! launcher stub belongs to the consumer's tree and the modules it sources belong
//! to the kit, so a stub written before the kit's bootstrap contract existed goes
//! on sourcing what it always sourced and reaches a module that is no longer
//! willing to load alone.
//!
//! WHAT WENT WRONG BEFORE THE GUARD, and why the fixture asserts a shape rather
//! than only a code: a stale stub used to die as a bash `command not found` at
//! exit 127 — the accident of an unloaded function, carrying no condition, no
//! remedy, and nothing an operator could act on. The condition was real and the
//! diagnosis was noise, and a live consumer station went dark on exactly that.
//!
//! THE FIXTURE IS WRITTEN INTO THE SEAT RATHER THAN INTO A SCRATCH DIRECTORY.
//! The bash cases put each bootstrap under the bench's shared temp directory,
//! which is ambient ground several cases wrote into at once; here each hurdle's
//! bootstrap stands in that hurdle's own seat and is gone when the seat is.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;

/// The band member the stale-bootstrap guard raises, spelled as
/// `bubc_constants.sh` spells it.
const BUJS_DESUETUDE: i32 = 119;

/// What a bash command-not-found takes, named because it is the death SHAPE this
/// guard replaced and not merely a number the guard avoids.
const BUJS_NOT_FOUND: i32 = 127;

/// The coordinator sources nothing: each hurdle runs a bootstrap of its own in a
/// process of its own, which is the only way to read a guard that fires on a
/// source-time sentinel. A coordinator that had already loaded the kit would
/// hand that sentinel to every child it spawned.
const BUJS_MODULES: &[&str] = &[];

/// The shape that left a live consumer station dark: the console library and the
/// regime module sourced directly, the validation module and the constants never
/// loaded at all.
const BUJS_STALE: &str = "#!/bin/bash\n\
                          source \"${1}/buc_command.sh\"\n\
                          source \"${1}/burc_regime.sh\"\n\
                          zburc_kindle\n";

/// The contract met, in the order `bul_launcher` itself orders it.
const BUJS_SOUND: &str = "#!/bin/bash\n\
                          source \"${1}/buv_validation.sh\"\n\
                          source \"${1}/burc_regime.sh\"\n\
                          echo \"burc regime module loaded\"\n";

/// What the sound bootstrap says when the guard lets it through untouched.
const BUJS_LOADED: &str = "burc regime module loaded";

/// Compose a seat whose coordinator writes the given bootstrap and runs it
/// against the kit the dispatch pointed it at.
///
/// THE BOOTSTRAP RUNS BARE. Nothing contains its death: whatever status it takes
/// is the coordinator's, and so the door's, and so this process's — which is the
/// posture, and is why the refusal's own code can be asserted rather than merely
/// its non-zero-ness.
fn bujs_bootstrap(name: &str, body: &str) -> buk::buah_hurdle::buah_Said {
    buah_Bench::buah_seat(
        name,
        BUJS_MODULES,
        &format!(
            "z_boot=\"${{BURD_TEMP_DIR}}/bujs-bootstrap.sh\"\n\
             cat > \"${{z_boot}}\" <<'BUJS_FIXTURE'\n\
             {body}BUJS_FIXTURE\n\
             bash \"${{z_boot}}\" \"${{BURD_BUK_DIR}}\"\n",
            body = body
        ),
    )
    .buah_drive(&[])
}

#[test]
fn bujs_a_stale_bootstrap_exits_on_the_guards_own_band_code() {
    bujs_bootstrap("substrate-stale-code", BUJS_STALE).buah_took(BUJS_DESUETUDE);
}

#[test]
fn bujs_the_refusal_names_the_condition_the_remedy_and_the_canonical_stub() {
    // FOUR SEPARATE THINGS, because a refusal is only as good as what its reader
    // can do next. The condition says what is wrong, the emitter and its
    // tabtarget say what to run, and the canonical binding line says what the
    // result should look like — so an operator who distrusts the tool can still
    // repair the stub by hand.
    bujs_bootstrap("substrate-stale-message", BUJS_STALE)
        .buah_took(BUJS_DESUETUDE)
        .buah_carries("STALE LAUNCHER STUB")
        .buah_carries("buut_launcher")
        .buah_carries("tt/buw-tt-cl.CreateLauncher.sh")
        .buah_carries("source \"Tools/buk/bul_launcher.sh\"");
}

#[test]
fn bujs_the_bash_command_not_found_death_is_gone() {
    // THE DEFECT'S OWN SIGNATURE, asserted as an absence on both axes it wore:
    // the exit code and the words. Either alone could survive a partial repair —
    // a guard raising its own code while the shell still printed the accident
    // beneath it would satisfy the code check and leave the operator reading
    // noise.
    let said = bujs_bootstrap("substrate-stale-shape", BUJS_STALE);
    assert_ne!(
        said.buah_code,
        Some(BUJS_NOT_FOUND),
        "the exit-{} death shape survives. What the door said:\n{}",
        BUJS_NOT_FOUND,
        said.buah_text
    );
    said.buah_lacks("command not found");
}

#[test]
fn bujs_a_bootstrap_meeting_the_contract_passes_untouched() {
    // THE CONTROL THE THREE ABOVE LEAN ON. A guard refusing every bootstrap would
    // satisfy all three refusals and fail only here, and "untouched" is asserted
    // as well as "admitted": the bootstrap's own word reaches the caller, so the
    // guard added nothing to a sound path.
    bujs_bootstrap("substrate-stale-sound", BUJS_SOUND)
        .buah_thrived()
        .buah_carries(BUJS_LOADED);
}
// eof
