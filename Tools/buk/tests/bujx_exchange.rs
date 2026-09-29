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

//! The dispatch's own fact file, and the two writers that lay a fact down.
//!
//! Ported from the bash bench's `burx-exchange` fixture, seven cases, all seven
//! carried.
//!
//! THE DISPATCH IS THE INTEGRATION TEST, which is the fixture's own founding
//! observation and survives the port intact: nothing here composes a fact file by
//! hand, because the thing worth asserting on is the one a real dispatch wrote on
//! its way to running a coordinator.
//!
//! WHAT MOVED IS WHOSE DISPATCH IT IS. The bash cases inspected the BENCH's own
//! dispatch — the very run that was executing them — so their reach was a
//! directory shared with every other case in the suite, and the multi-writer
//! cases had to pick unique file names to keep out of each other's way. Each
//! hurdle here drives a dispatch of its own into a seat of its own, and asserts
//! on that dispatch's directories, which no other hurdle can see.
//!
//! THE COORDINATOR REPORTS AND THE HURDLE JUDGES. A coordinator that compared
//! two files and printed a verdict would be a harness inside the process tree
//! under test; instead it reports the two paths and this process opens both. The
//! two refusal cases go the other way and raise their death bare, so the status a
//! duplicate write takes is read from outside rather than captured within.

#![deny(warnings)]
// The estate's minted names are lowercase with a prefix, which rust's own
// convention for a type disagrees with. The lib says so once for itself; a test
// file is a crate of its own and says so for itself.
#![allow(non_camel_case_types)]

use buk::buah_hurdle::buah_Bench;

/// The modules a fact reading needs.
const BUJX_MODULES: &[&str] = &["buym_yelp.sh", "buc_command.sh", "buf_fact.sh"];

/// The tokens the coordinator reports its directories under.
const BUJX_TEMP: &str = "bujx_temp=";
const BUJX_OUTPUT: &str = "bujx_output=";

/// The fact file every dispatch lays down, spelled as `buf_fact.sh` spells it.
const BUJX_BURX: &str = "burx.env";

/// A coordinator prelude reporting the two directories a fact is dual-written to.
const BUJX_REPORT: &str = "printf 'bujx_temp=%s\\n'   \"${BURD_TEMP_DIR}\"\n\
                           printf 'bujx_output=%s\\n' \"${BURD_OUTPUT_DIR}\"\n";

/// What the coordinator said its temp and output directories were.
struct bujx_Where {
    temp: String,
    output: String,
}

/// Drive a coordinator that reports its directories and then does the given work.
///
/// THE BENCH IS HANDED BACK AND NOT MERELY USED, and that is load-bearing rather
/// than stylistic: a seat is removed when it is dropped, so a helper that
/// composed one, drove it, and returned only what the shell SAID would delete
/// every file the hurdle is about before the hurdle could open one. It cost this
/// fixture a whole red drive to find, and it could only ever have been found
/// here — every hurdle before this one read the door's words and nothing else,
/// so none of them cared whether the seat outlived the drive.
fn bujx_drive(name: &str, work: &str) -> (buah_Bench, buk::buah_hurdle::buah_Said, bujx_Where) {
    let bench = buah_Bench::buah_seat(
        name,
        BUJX_MODULES,
        &format!("{report}{work}", report = BUJX_REPORT, work = work),
    );
    let said = bench.buah_drive(&[]);

    let where_ = bujx_Where {
        temp: bujx_after(&said.buah_text, BUJX_TEMP),
        output: bujx_after(&said.buah_text, BUJX_OUTPUT),
    };

    (bench, said, where_)
}

/// The rest of the line following a reported token.
///
/// THE STREAMS ARE MERGED AND THE TRANSCRIPT CARRIES PATHS OF ITS OWN, so a
/// reading is taken from the line the coordinator's own token opens and never by
/// hunting for something path-shaped.
fn bujx_after(text: &str, token: &str) -> String {
    let at = text
        .find(token)
        .unwrap_or_else(|| panic!("the coordinator never reported {}:\n{}", token, text));
    let rest = &text[at + token.len()..];
    rest.lines()
        .next()
        .unwrap_or_else(|| panic!("{} opened an empty line", token))
        .trim_end()
        .to_string()
}

/// Read a file the dispatch wrote, naming it when it is not there.
fn bujx_read(dir: &str, name: &str) -> String {
    let path = std::path::Path::new(dir).join(name);
    std::fs::read_to_string(&path)
        .unwrap_or_else(|err| panic!("no {} stands: {}", path.display(), err))
}

#[test]
fn bujx_the_fact_file_is_dual_written_with_matching_content() {
    // TWO SEATS, ONE CONTENT. The temp copy dies with the dispatch and the output
    // copy outlives it to become the next dispatch's `previous`, so a writer that
    // laid down only one would leave either this run or the next one blind — and
    // a writer that laid down two that DISAGREED would be worse than either.
    let (_seat, said, at) = bujx_drive("substrate-burx-dual", "");
    said.buah_thrived();

    let temp = bujx_read(&at.temp, BUJX_BURX);
    let output = bujx_read(&at.output, BUJX_BURX);
    assert_eq!(
        temp, output,
        "the dual write disagreed between {} and {}",
        at.temp, at.output
    );
}

#[test]
fn bujx_the_fact_file_is_sourceable_and_carries_every_initial_field() {
    let (_seat, said, at) = bujx_drive("substrate-burx-fields", "");
    said.buah_thrived();
    let burx = bujx_read(&at.temp, BUJX_BURX);

    for field in [
        "BURX_PID",
        "BURX_BEGAN_AT",
        "BURX_TABTARGET",
        "BURX_TEMP_DIR",
        "BURX_TRANSCRIPT",
        "BURX_LOG_HIST",
    ] {
        let line = bujx_assignment(&burx, field);
        assert!(
            !line.is_empty(),
            "{} stands in the fact file with no value:\n{}",
            field,
            burx
        );
    }

    // BURX_LABEL IS DECLARED THOUGH IT MAY BE EMPTY, and the distinction is the
    // whole reason it is asserted separately: a consumer reading an absent name
    // under `set -u` dies, where one reading a declared empty gets the empty it
    // was promised. Missing and empty are different facts.
    assert!(
        burx.contains("BURX_LABEL="),
        "BURX_LABEL is not declared at all:\n{}",
        burx
    );
}

#[test]
fn bujx_the_fact_file_is_refused_a_second_time() {
    // RAISED BARE, so the refusal's own status is this process's to read. A fact
    // file is written once per dispatch by construction; a writer that silently
    // overwrote would let a later caller replace the record of the run in
    // progress.
    let (_seat, said, _) = bujx_drive(
        "substrate-burx-preexist",
        "buf_write_fact_single \"${BUF_burx_env}\" \"duplicate-write\"\n",
    );
    // THE REFUSAL NAMES ITSELF, and this hurdle asserts that rather than a bare
    // death, on the lesson the BURE fixture taught earlier in this pace: a case
    // satisfied by any non-zero exit is satisfied by a death on the way to its
    // subject just as readily as by the refusal it means to read.
    said.buah_died()
        .buah_carries("buf_write_fact_single")
        .buah_carries("preexists");
}

#[test]
fn bujx_the_beginning_stamp_carries_nanosecond_precision() {
    let (_seat, said, at) = bujx_drive("substrate-burx-stamp", "");
    said.buah_thrived();
    let burx = bujx_read(&at.temp, BUJX_BURX);
    let stamp = bujx_assignment(&burx, "BURX_BEGAN_AT");

    // YYYYMMDD-HHMMSS.NNNNNNNNN, checked shape-first so the failure says which
    // part is wrong rather than that a regular expression did not match.
    let (date, rest) = stamp
        .split_once('-')
        .unwrap_or_else(|| panic!("no date separator in {:?}", stamp));
    let (clock, nanos) = rest
        .split_once('.')
        .unwrap_or_else(|| panic!("no fractional separator in {:?}", stamp));

    for (part, width, what) in [(date, 8, "date"), (clock, 6, "clock"), (nanos, 9, "nanoseconds")] {
        assert_eq!(part.len(), width, "the {} of {:?} is not {} wide", what, stamp, width);
        assert!(
            part.chars().all(|c| c.is_ascii_digit()),
            "the {} of {:?} is not all digits",
            what,
            stamp
        );
    }
}

#[test]
fn bujx_a_multi_fact_is_dual_written_with_its_content() {
    let (_seat, said, at) = bujx_drive(
        "substrate-burx-multi-dual",
        "buf_write_fact_multi \"bujx_multi_a\" \"probe\" \"alpha\"\n",
    );
    said.buah_thrived();

    let temp = bujx_read(&at.temp, "bujx_multi_a.probe");
    let output = bujx_read(&at.output, "bujx_multi_a.probe");
    assert_eq!(temp, output, "the multi writer's dual write disagreed");
    assert_eq!(
        temp.trim_end(),
        "alpha",
        "the multi writer laid down content it was not given: {:?}",
        temp
    );
}

#[test]
fn bujx_a_multi_fact_is_refused_a_second_time() {
    // THE FIRST WRITE MUST SUCCEED FOR THE SECOND'S REFUSAL TO MEAN ANYTHING,
    // which is why both stand in one coordinator: a hurdle whose first write had
    // failed would see the second refused too, and would read that as the
    // property under test.
    let (_seat, said, _) = bujx_drive(
        "substrate-burx-multi-preexist",
        "buf_write_fact_multi \"bujx_multi_b\" \"probe\" \"first\"\n\
         buf_write_fact_multi \"bujx_multi_b\" \"probe\" \"second\"\n",
    );
    said.buah_died()
        .buah_carries("buf_write_fact_multi")
        .buah_carries("preexists");
}

#[test]
fn bujx_a_multi_fact_may_be_empty_because_presence_is_the_fact() {
    // A FACT WHOSE WHOLE CONTENT IS THAT IT EXISTS. The writer must not treat an
    // empty value as nothing to write, because the file's presence is what a
    // later reader is asking about.
    let (_seat, said, at) = bujx_drive(
        "substrate-burx-multi-empty",
        "buf_write_fact_multi \"bujx_multi_c\" \"${BUF_EXT_ALIAS}\" \"\"\n",
    );
    said.buah_thrived();

    let name = "bujx_multi_c.buf_ext_alias";
    for dir in [&at.temp, &at.output] {
        assert!(
            std::path::Path::new(dir).join(name).is_file(),
            "no {} stands under {}",
            name,
            dir
        );
    }
}

/// The value a shell assignment line carries, with any surrounding quotes taken off.
fn bujx_assignment(body: &str, name: &str) -> String {
    let prefix = format!("{}=", name);
    let line = body
        .lines()
        .find(|line| line.trim_start().starts_with(&prefix))
        .unwrap_or_else(|| panic!("no {} line in the fact file:\n{}", name, body));

    line.trim_start()[prefix.len()..]
        .trim()
        .trim_matches('"')
        .to_string()
}
// eof
