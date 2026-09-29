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

//! The shape the ported hurdles share: a seat, a drive, and what the shell said.
//!
//! THIS IS NOT A THIRD COMPOSING SURFACE. Composing a repository, laying a
//! substrate seat into it and spawning a door all belong to the kennel's lure
//! surface, and every one of them is reached through it here. What stands in
//! this module is the SHAPE a ported case takes over that surface — a
//! coordinator built from named modules and a body, driven once, its streams
//! joined and its exit code read — and the assertions a hurdle then makes
//! against what came back.
//!
//! WHY A SHARED SHAPE AT ALL. Sixty-six cases came across from the bash bench
//! and the overwhelming majority say one thing: run this against the substrate
//! and tell me what it said and how it died. Spelled at each of them, that
//! sentence is sixty-six chances to spell it differently; spelled once, a
//! hurdle's own text is only the part that differs from its neighbours, which
//! is the part a reader came to read.
//!
//! NO AMBIENT MUTABLE STATE IN ANY FORM. Each drive composes its own seat,
//! whose temp, output and log roots stand inside it, and drops it when the
//! hurdle ends. Nothing is seeded into a directory another hurdle can see,
//! nothing is read back out of one, and no hurdle's verdict is a function of
//! what ran before it. The bash bench could not hold this line — its fact
//! cases seeded uniquely-named files into the live dispatch's own directories
//! because the regime had made the path variables readonly — and losing that
//! constraint is the port's plainest gain.
//!
//! THE STREAMS ARE JOINED RATHER THAN KEPT APART, which is the substrate's law
//! and not this module's choice: a dispatch merges its coordinator's stderr
//! onto stdout, so a hurdle seeking a diagnostic seeks it across both and an
//! assertion aimed at one stream alone would be aimed at an artifact of the
//! merge.

use std::path::Path;
use std::path::PathBuf;

use bkk::bktu_lure::bktu_Lure;

use crate::buas_seat::buas_source;

/// A composed seat with one door, standing until the hurdle drops it.
pub struct buah_Bench {
    lure: bktu_Lure,
    tabtarget: PathBuf,
}

/// What a drive came back with.
///
/// The exit code is an `Option` because a child killed by a signal has none,
/// and a hurdle asserting against a code it never received should say so rather
/// than compare against a number invented here.
pub struct buah_Said {
    pub buah_code: Option<i32>,
    pub buah_text: String,
}

impl buah_Bench {
    /// Compose a seat whose coordinator sources the named modules and then runs
    /// the given body.
    ///
    /// A HURDLE NAMES THE MODULES IT NEEDS AND NO MORE. The reason is the seat
    /// module's and is not restated: a script sourcing the kit whole answers a
    /// missing dependency somewhere else entirely.
    ///
    /// THE BODY RUNS UNDER `set -euo pipefail`, which is what a substrate door
    /// runs under. A case wanting a failure to be survivable rather than fatal
    /// spells that itself, at the line where it wants it — never by relaxing the
    /// shell options for the whole body, which would make every other line of
    /// that body a weaker assertion than it reads as.
    pub fn buah_seat(name: &str, modules: &[&str], body: &str) -> buah_Bench {
        let lure = bktu_Lure::bktu_compose(name);
        let tabtarget = lure.bktu_substrate_seat(&format!(
            "#!/bin/bash\n\
             set -euo pipefail\n\
             {sources}{body}\n",
            sources = buas_source(modules),
            body = body
        ));

        buah_Bench { lure, tabtarget }
    }

    /// Drive the seat's door and hand back what the shell said.
    pub fn buah_drive(&self, args: &[&str]) -> buah_Said {
        let out = self.lure.bktu_dispatch(&self.tabtarget, args);

        let mut text = String::from_utf8_lossy(&out.stdout).into_owned();
        text.push_str(&String::from_utf8_lossy(&out.stderr));

        buah_Said {
            buah_code: out.status.code(),
            buah_text: text,
        }
    }

    /// Where the seat stands.
    ///
    /// A hurdle whose coordinator reports by writing a file names a path under
    /// this root, so the rust side chooses where the report lands rather than
    /// reconstructing a path the dispatch composed.
    pub fn buah_root(&self) -> &Path {
        self.lure.bktu_root()
    }

    /// Read a file the coordinator wrote under the seat.
    ///
    /// THE ABSENCE IS ITS OWN DIAGNOSTIC. A coordinator that died before
    /// reporting leaves no file, and a hurdle told only that a read failed would
    /// be told nothing about why — so the panic names the path and the drive's
    /// own words are the hurdle's to add.
    pub fn buah_read(&self, relative: &str) -> String {
        let path = self.buah_root().join(relative);
        std::fs::read_to_string(&path).unwrap_or_else(|err| {
            panic!(
                "the coordinator wrote no {}: {}",
                path.display(),
                err
            )
        })
    }

    /// Whether a file stands under the seat.
    pub fn buah_stands(&self, relative: &str) -> bool {
        self.buah_root().join(relative).is_file()
    }
}

impl buah_Said {
    /// Assert the shell took the named exit code.
    pub fn buah_took(&self, want: i32) -> &buah_Said {
        assert_eq!(
            self.buah_code,
            Some(want),
            "the door took {:?} where {} was owed. What it said:\n{}",
            self.buah_code,
            want,
            self.buah_text
        );
        self
    }

    /// Assert the shell exited cleanly.
    pub fn buah_thrived(&self) -> &buah_Said {
        self.buah_took(0)
    }

    /// Assert the shell died, without saying how.
    ///
    /// FOR A CASE WHOSE SUBJECT IS THE REFUSAL AND NOT ITS CODE. Where the code
    /// is the property — a band member, a named guard — the hurdle asserts it by
    /// number through `buah_took`, because a refusal reaching the caller with the
    /// wrong code is exactly the defect a bare death-check cannot see.
    pub fn buah_died(&self) -> &buah_Said {
        assert_ne!(
            self.buah_code,
            Some(0),
            "the door thrived where a refusal was owed. What it said:\n{}",
            self.buah_text
        );
        self
    }

    /// Assert a needle stands in what the shell said.
    pub fn buah_carries(&self, needle: &str) -> &buah_Said {
        assert!(
            self.buah_text.contains(needle),
            "the door never said {:?}. What it did say:\n{}",
            needle,
            self.buah_text
        );
        self
    }

    /// Assert a needle stands nowhere in what the shell said.
    pub fn buah_lacks(&self, needle: &str) -> &buah_Said {
        assert!(
            !self.buah_text.contains(needle),
            "the door said {:?} where it owed silence. What it said:\n{}",
            needle,
            self.buah_text
        );
        self
    }

    /// How many times a needle stands in what the shell said.
    ///
    /// Counted by non-overlapping advance, which is what a reader means by "how
    /// many of these are in there" for the escape sequences the yelp hurdles
    /// count.
    pub fn buah_tally(&self, needle: &str) -> usize {
        assert!(!needle.is_empty(), "an empty needle matches without bound");
        self.buah_text.matches(needle).count()
    }
}

/// The escape a terminal renders as the named colour, as bash's `printf` writes it.
///
/// SPELLED ONCE, BECAUSE A HURDLE SEEKING AN ESCAPE AND A COORDINATOR WRITING ONE
/// MUST AGREE BYTE FOR BYTE. The founding die hurdle records the same hazard
/// about its own token: a needle needing to be reshaped between the writing and
/// the seeking is a needle that can be reshaped in only one of them.
pub const BUAH_ESC: &str = "\u{1b}";

/// The cyan a resolved command marker renders as.
pub const BUAH_CYAN: &str = "\u{1b}[36m";

/// The gray a resolved operation sigil renders as.
pub const BUAH_GRAY: &str = "\u{1b}[90m";

/// The opening bytes of an OSC-8 hyperlink.
pub const BUAH_OSC8: &str = "\u{1b}]8;;";

/// The byte a diastema marker is built from.
///
/// NO RESOLVED OUTPUT MAY CARRY ONE. It is the yelp module's own interior
/// delimiter, so a survivor in rendered text is a marker the resolver failed to
/// consume — which is why nearly every yelp hurdle asserts its absence beside
/// whatever else it asserts.
pub const BUAH_DIASTEMA: &str = "\u{2}";

// eof
