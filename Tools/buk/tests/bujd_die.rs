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

//! The die path keeps its diagnostic when no transcript stands.
//!
//! THE GUARD THE FIRST NEEDED PROOF LEFT OWING. That proof drove the defect, ruled
//! the failed bash guard an authoring fault rather than a structural masking, and
//! restored the bench whole — so the suite held no case against the defect and the
//! die path's transcript pipeline stood unguarded. This is that case, authored to
//! the proof's own terms.
//!
//! THE DEFECT, AND WHY IT NEEDS THREE THINGS ARMED AT ONCE. The die path builds a
//! pipeline: a writer loop feeding the drain that renders each line into the
//! transcript. A drain that returned early when no transcript stands would close
//! the read end, and the writer takes SIGPIPE the moment it loses that race; under
//! `pipefail` the writer's 141 becomes the pipeline's status, and `errexit` then
//! exits the shell INSIDE the die path, before the diagnostic reaches stderr. The
//! caller dies mute, and dies 141 rather than 1.
//!
//! A factorial over the three conditions annihilates the diagnostic in exactly one
//! cell of eight, and the other seven are structural zeros rather than lucky ones:
//! a set transcript makes the drain read to EOF, so no signal is possible; errexit
//! off lets the pipeline report 141 with nothing exiting; and bash suppresses
//! errexit inside a subshell standing on the left of `||`, which is how a guard
//! containing the death it means to observe destroys its own subject. So this
//! hurdle arms all three, and a hurdle that armed two would be green about
//! nothing.
//!
//! OBSERVED FROM OUTSIDE THE DYING SHELL. The exit code and the streams are read
//! in this process, which the dispatch cannot reach. That is the posture law, and
//! it is the whole reason this case is rust: the harness that lost this defect
//! lost it by watching from inside the process tree that dies.
//!
//! THE RACE IS FORCED RATHER THAN SAMPLED, and forced twice over. The writer is
//! given more to write, which raises the odds it is still writing when the reader
//! goes; and the run is repeated, which is what turns odds into a verdict. Neither
//! alone is enough — a single green run of a raced symptom proves nothing, which
//! is the second half of the fault the proof named.

#![deny(warnings)]

use bkk::bktu_lure::bktu_Lure;
use buk::buas_seat::buas_source;

/// How much the writer is given to write.
///
/// A STATION READING, NOT A LAW. The proof recorded fifty of fifty at twenty
/// arguments on the bench it was driven on; this station reports about half that
/// at twenty and climbs with the payload — the rate moves with machine load, as
/// the proof itself says. So the payload buys per-run odds and nothing more, and
/// the trials below are what carry the verdict.
const BUJD_ARGUMENTS: usize = 160;

/// How many times the death is driven.
///
/// The count is the guard's real instrument. Even at the LOWEST per-run rate this
/// station has shown, a defect surviving every trial is a coin landing one way a
/// hundred times; at the rate the payload above buys, it is far past that. A guard
/// observing once has run a lottery rather than an experiment.
const BUJD_TRIALS: usize = 100;

/// What a shell reports when a pipeline's writer takes SIGPIPE.
///
/// Named rather than spelled at the assertion, because this number IS the defect's
/// signature: the failure is not that the door exits non-zero but that it exits
/// with the writer's death instead of its own verdict.
const BUJD_SIGPIPE: i32 = 141;

/// The verdict the die path takes when it is sound.
const BUJD_VERDICT: i32 = 1;

/// A word the diagnostic must carry, distinctive enough that finding it proves the
/// message was rendered rather than that something merely printed.
///
/// ONE SPELLING, CARRYING NO SPACE. It is written into the payload and sought in
/// the answer, and a token needing to be reshaped between those two uses is a
/// token that can be reshaped in only one of them — which is exactly what happened
/// to the first draft of this hurdle, whose search never matched what its own
/// payload wrote.
const BUJD_SAID: &str = "the-die-path-kept-its-tongue";

#[test]
fn bujd_the_die_path_speaks_with_no_transcript_standing() {
    let lure = bktu_Lure::bktu_compose("substrate-die-path");

    // THE THREE CONDITIONS, ARMED IN THE COORDINATOR ITSELF rather than inherited.
    // The seat is entered through a real dispatch, which EXPORTS a transcript — so
    // the first condition is armed by unsetting it here, at the one place a reader
    // can see all three standing together. `set -euo pipefail` is what a substrate
    // door runs under, and the die call stands bare: not on the left of `||`, not
    // in a subshell, nothing containing the death this hurdle exists to watch.
    let mut payload = String::new();
    for i in 0..BUJD_ARGUMENTS {
        payload.push_str(&format!(" {}-{}", BUJD_SAID, i));
    }

    let tabtarget = lure.bktu_substrate_seat(&format!(
        "#!/bin/bash\n\
         set -euo pipefail\n\
         unset BURD_TRANSCRIPT\n\
         {sources}\
         buc_context \"bujd\"\n\
         buc_die_now{payload}\n",
        sources = buas_source(&["buym_yelp.sh", "buc_command.sh"]),
        payload = payload
    ));

    let mut mute = 0usize;
    let mut sigpipe = 0usize;
    let mut first = String::new();

    for trial in 0..BUJD_TRIALS {
        let out = lure.bktu_dispatch(&tabtarget, &[]);

        // THE DISPATCH MERGES THE COORDINATOR'S STREAMS into one record, which is
        // the substrate's own law rather than a fact about this hurdle, so the
        // diagnostic is sought across both rather than on the stream it was
        // written to.
        let mut said = String::from_utf8_lossy(&out.stdout).into_owned();
        said.push_str(&String::from_utf8_lossy(&out.stderr));

        let code = out.status.code();

        assert_ne!(
            code,
            Some(BUJD_SIGPIPE),
            "trial {}: the die path exited {} — the writer's death, not the door's \
             verdict. The drain returned before reading to EOF and the diagnostic was \
             annihilated:\n{}",
            trial,
            BUJD_SIGPIPE,
            said
        );

        assert_eq!(
            code,
            Some(BUJD_VERDICT),
            "trial {}: the die path took a verdict that is neither its own nor the \
             writer's:\n{}",
            trial,
            said
        );

        if trial == 0 {
            first = said.clone();
        }
        if !said.contains(BUJD_SAID) {
            mute += 1;
        }
        if code == Some(BUJD_SIGPIPE) {
            sigpipe += 1;
        }
    }

    // THE VERDICT AND THE VOICE ARE TWO ASSERTIONS because the defect takes both
    // and either could in principle go alone. A door exiting 1 with nothing said is
    // as mute as one exiting 141, and a reader handed a bare status has been handed
    // nothing to act on.
    assert_eq!(
        mute, 0,
        "the die path died mute in {} of {} trials: it took its own verdict and said \
         nothing, which is the loss this guard exists to catch. What the first trial \
         did say:\n{}",
        mute, BUJD_TRIALS, first
    );
    assert_eq!(sigpipe, 0, "unreachable while the assertion above stands");
}
// eof
