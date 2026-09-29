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

//! Facts travel from one dispatch to the next, and reading one consumes nothing.
//!
//! Ported from the bash bench's `fact-chaining` fixture, nine cases, all nine
//! carried.
//!
//! THIS FIXTURE IS WHY THE PACE'S NO-AMBIENT-STATE CINCH HAS A SPECIMEN. Its
//! bash header records the trap plainly: `BURD_PREVIOUS_DIR` and
//! `BURD_OUTPUT_DIR` are locked readonly by the dispatch regime, so the cases
//! could not point them at scratch and instead seeded uniquely-named files into
//! the LIVE directories of the run that was executing them — asserting around
//! whatever else those directories happened to hold, and leaving their own
//! seedings behind for whatever came next. Every hurdle here owns the directories
//! it seeds, because its seat composed them; the names need no uniqueness, the
//! reach needs no negotiation, and nothing survives the hurdle that made it.
//!
//! THE COORDINATOR SEEDS AND REPORTS; THIS PROCESS JUDGES. Where a case reads a
//! value back, the coordinator prints what it read and the hurdle compares;
//! where a case proves a refusal, the read is raised bare and the hurdle reads
//! the death from outside. Where a case proves a file SURVIVED, this process
//! opens it — which is the reading the bash bench could not take at all, its
//! observer standing in the same directories it was asking about.

#![deny(warnings)]
#![allow(non_camel_case_types)]

use buk::buah_hurdle::buah_Bench;

/// The modules a chaining reading needs.
const BUJF_MODULES: &[&str] = &["buym_yelp.sh", "buc_command.sh", "buf_fact.sh"];

/// The tokens the coordinator reports under.
const BUJF_WHERE: &str = "bujf_output=";
const BUJF_PRIOR: &str = "bujf_previous=";
const BUJF_VALUE: &str = "bujf_value=";

/// The prelude every coordinator opens with: make the prior dispatch's directory
/// stand, and say where both directories are.
///
/// THE DIRECTORY IS CREATED RATHER THAN ASSUMED. A seat's first dispatch has no
/// predecessor, so nothing has promoted a `current` into a `previous` yet; the
/// bash cases carried the same `mkdir` for the same reason, and it stayed inline
/// there because the readonly path could not be lifted to a setup step.
const BUJF_PRELUDE: &str = "mkdir -p \"${BURD_PREVIOUS_DIR}\"\n\
                            printf 'bujf_output=%s\\n'   \"${BURD_OUTPUT_DIR}\"\n\
                            printf 'bujf_previous=%s\\n' \"${BURD_PREVIOUS_DIR}\"\n";

/// Where a drive's two fact directories stood.
struct bujf_Where {
    output: String,
    previous: String,
}

/// Drive a coordinator that reports its fact directories and then does the work.
///
/// The bench is handed back because a hurdle reading the seat's own files must
/// outlive the drive — the burx fixture paid a red drive to learn it.
fn bujf_drive(name: &str, work: &str) -> (buah_Bench, buk::buah_hurdle::buah_Said, bujf_Where) {
    let bench = buah_Bench::buah_seat(
        name,
        BUJF_MODULES,
        &format!("{prelude}{work}", prelude = BUJF_PRELUDE, work = work),
    );
    let said = bench.buah_drive(&[]);
    let where_ = bujf_Where {
        output: bujf_after(&said.buah_text, BUJF_WHERE),
        previous: bujf_after(&said.buah_text, BUJF_PRIOR),
    };
    (bench, said, where_)
}

/// The rest of the line a reported token opens.
fn bujf_after(text: &str, token: &str) -> String {
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

/// A shell line seeding one fact under a named directory.
///
/// THE TRAILING NEWLINE IS THE PRODUCER'S OWN FORMAT, written deliberately so
/// the read path exercises the stripping it owes rather than being handed
/// something already bare.
fn bujf_seed(dir: &str, name: &str, value: &str) -> String {
    format!("printf '%s\\n' '{}' > \"${{{}}}/{}\"\n", value, dir, name)
}

/// Read a fact this process can see, naming it when it is absent.
fn bujf_read(dir: &str, name: &str) -> String {
    let path = std::path::Path::new(dir).join(name);
    std::fs::read_to_string(&path)
        .unwrap_or_else(|err| panic!("no {} stands: {}", path.display(), err))
        .trim_end()
        .to_string()
}

#[test]
fn bujf_a_relay_forwards_a_prior_fact_into_the_current_dispatch() {
    let (_seat, said, at) = bujf_drive(
        "substrate-fact-forward",
        &format!(
            "{seed}buf_relay\n",
            seed = bujf_seed("BURD_PREVIOUS_DIR", "bujf_fwd", "forwarded-value")
        ),
    );
    said.buah_thrived();
    assert_eq!(bujf_read(&at.output, "bujf_fwd"), "forwarded-value");
}

#[test]
fn bujf_a_relay_never_clobbers_a_fact_the_current_dispatch_already_holds() {
    // THE CURRENT DISPATCH OUTRANKS ITS PREDECESSOR, always. A relay that
    // overwrote would let a stale value from the last run silently replace one
    // this run computed — the failure being that both are well-formed facts under
    // the same name, so nothing downstream could tell which it got.
    let (_seat, said, at) = bujf_drive(
        "substrate-fact-preserve",
        &format!(
            "{prev}{curr}buf_relay\n",
            prev = bujf_seed("BURD_PREVIOUS_DIR", "bujf_pres", "from-previous"),
            curr = bujf_seed("BURD_OUTPUT_DIR", "bujf_pres", "from-current")
        ),
    );
    said.buah_thrived();
    assert_eq!(bujf_read(&at.output, "bujf_pres"), "from-current");
}

#[test]
fn bujf_a_second_relay_is_a_no_op_that_still_succeeds() {
    // IDEMPOTENCE IS ASSERTED ON BOTH AXES: the second call must not fail, and it
    // must not alter what the first forwarded. A relay refusing on its second
    // call would make the order of a coordinator's own steps load-bearing.
    let (_seat, said, at) = bujf_drive(
        "substrate-fact-idempotent",
        &format!(
            "{seed}buf_relay\nbuf_relay\n",
            seed = bujf_seed("BURD_PREVIOUS_DIR", "bujf_idem", "v1")
        ),
    );
    said.buah_thrived();
    assert_eq!(bujf_read(&at.output, "bujf_idem"), "v1");
}

#[test]
fn bujf_a_read_emits_the_bare_value_with_the_newline_stripped() {
    let (_seat, said, _) = bujf_drive(
        "substrate-fact-read",
        &format!(
            "{seed}printf 'bujf_value=[%s]\\n' \"$(buf_read_fact_capture bujf_greeting)\"\n",
            seed = bujf_seed("BURD_PREVIOUS_DIR", "bujf_greeting", "hello world")
        ),
    );
    // THE BRACKETS ARE THE ASSERTION'S TEETH. The value is compared inside
    // delimiters so a trailing newline the reader failed to strip shows up as a
    // mismatch rather than vanishing into the line break it would have become.
    said.buah_thrived()
        .buah_carries(&format!("{}[hello world]", BUJF_VALUE));
}

#[test]
fn bujf_a_read_of_an_absent_fact_fails_hard() {
    // SILENCE WOULD BE THE WORST ANSWER HERE. A reader returning empty for an
    // absent fact hands its caller a value indistinguishable from a fact that was
    // genuinely written empty.
    let (_seat, said, _) = bujf_drive(
        "substrate-fact-absent",
        "buf_read_fact_capture bujf_definitely_absent\n",
    );
    said.buah_died().buah_carries("bujf_definitely_absent");
}

#[test]
fn bujf_a_non_empty_express_value_wins_and_the_chain_is_never_read() {
    // THE ABSENT FACT IS THE INSTRUMENT. It is named deliberately and never
    // seeded, so an elect that consulted the chain despite holding an express
    // value would die on the read — which turns "the express won" from something
    // asserted about a returned string into something the drive's survival
    // proves.
    let (_seat, said, _) = bujf_drive(
        "substrate-fact-express",
        "printf 'bujf_value=[%s]\\n' \
         \"$(buf_elect_fact_capture 'express-wins' bujf_definitely_absent)\"\n",
    );
    said.buah_thrived()
        .buah_carries(&format!("{}[express-wins]", BUJF_VALUE));
}

#[test]
fn bujf_an_elect_still_reads_the_prior_dispatch_after_a_relay() {
    // A RELAY COPIES FORWARD AND MOVES NOTHING, which is what makes both halves
    // true at once: the elect still finds the baton where it was written, and the
    // forwarded copy stands in `current` ready to become the next run's
    // `previous`.
    let (_seat, said, at) = bujf_drive(
        "substrate-fact-elect-relay",
        &format!(
            "{seed}buf_relay\n\
             printf 'bujf_value=[%s]\\n' \"$(buf_elect_fact_capture '' bujf_baton)\"\n",
            seed = bujf_seed("BURD_PREVIOUS_DIR", "bujf_baton", "baton-value")
        ),
    );
    said.buah_thrived()
        .buah_carries(&format!("{}[baton-value]", BUJF_VALUE));
    assert_eq!(bujf_read(&at.output, "bujf_baton"), "baton-value");
}

#[test]
fn bujf_reading_a_fact_consumes_nothing() {
    // BOTH GENERATIONS SURVIVE REPEATED READS, and this process opens both files
    // to say so — the reading the bash bench structurally could not take, its
    // observer standing inside the very directories it was asking about.
    let (_seat, said, at) = bujf_drive(
        "substrate-fact-survives",
        &format!(
            "{seed}buf_relay\n\
             printf 'bujf_value=[%s]\\n' \"$(buf_read_fact_capture bujf_survive)\"\n\
             printf 'bujf_value=[%s]\\n' \"$(buf_read_fact_capture bujf_survive)\"\n",
            seed = bujf_seed("BURD_PREVIOUS_DIR", "bujf_survive", "immortal")
        ),
    );
    said.buah_thrived();

    assert_eq!(
        said.buah_tally(&format!("{}[immortal]", BUJF_VALUE)),
        2,
        "the fact did not read the same twice:\n{}",
        said.buah_text
    );
    assert_eq!(bujf_read(&at.previous, "bujf_survive"), "immortal");
    assert_eq!(bujf_read(&at.output, "bujf_survive"), "immortal");
}

#[test]
fn bujf_an_empty_express_falls_back_to_the_chain_and_a_broken_chain_dies() {
    // ONE COORDINATOR CARRIES BOTH HALVES because they are one rule read in both
    // directions: an empty express means "go and look", and going to look at
    // something absent is the broken chain. The successful fallback is reported
    // before the broken one is raised, so a drive that died at the wrong step
    // says which step it reached.
    let (_seat, said, _) = bujf_drive(
        "substrate-fact-chain",
        &format!(
            "{seed}printf 'bujf_value=[%s]\\n' \"$(buf_elect_fact_capture '' bujf_chained)\"\n\
             buf_elect_fact_capture '' bujf_definitely_absent\n",
            seed = bujf_seed("BURD_PREVIOUS_DIR", "bujf_chained", "from-chain")
        ),
    );
    said.buah_died()
        .buah_carries(&format!("{}[from-chain]", BUJF_VALUE))
        .buah_carries("bujf_definitely_absent");
}
// eof
