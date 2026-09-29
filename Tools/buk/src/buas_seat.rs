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

//! Where the substrate stands, and how a composed script reaches into it.
//!
//! THIS IS NOT A SECOND COMPOSING SURFACE. Reaching the temp root, composing a
//! repository and spawning a door all belong to the kennel's lure surface, which
//! is their only home, and nothing here does any of the three. What stands here
//! is the one thing that surface cannot know: which kit is under test, and how a
//! script standing outside it sources its modules.
//!
//! THE SUBSTRATE IS REACHED BY PATH AND NEVER COPIED, on the same ground the
//! composed seat takes: the kit under test is the one standing in the tree this
//! suite was built from, so a hurdle judges the same bytes the suite was compiled
//! against rather than a copy free to drift from them.

use std::path::Path;
use std::path::PathBuf;

/// Where the substrate stands in the tree this suite was built from.
///
/// Read off this crate's own manifest, which stands inside the kit: a suite
/// compiled from Tools/buk tests the substrate at Tools/buk, and there is no
/// second reading to disagree with it. A tree missing the shared launcher refuses
/// here, naming the path, rather than failing several processes deep in bash with
/// a message about something else.
pub fn buas_substrate() -> PathBuf {
    let substrate = PathBuf::from(env!("CARGO_MANIFEST_DIR"));

    let launcher = substrate.join("bul_launcher.sh");
    assert!(
        launcher.is_file(),
        "no substrate stands at {}: this suite is compiled from inside the kit it tests, \
         and the kit carries no shared launcher",
        launcher.display()
    );

    substrate
}

/// The `source` lines a composed script opens with, one per named module.
///
/// A HURDLE NAMES THE MODULES IT NEEDS AND NO MORE, which is what makes a
/// refusal legible: a script sourcing the kit whole would answer a missing
/// dependency with a failure somewhere else entirely, where a script sourcing
/// two modules fails at the line that names the one it lacks.
///
/// The paths are absolute, because the script runs with its own composed seat as
/// the working directory and the kit stands outside that seat.
pub fn buas_source(modules: &[&str]) -> String {
    let substrate = buas_substrate();
    let mut said = String::new();

    for module in modules {
        let path = substrate.join(module);
        assert!(
            path.is_file(),
            "the substrate at {} carries no {}",
            substrate.display(),
            module
        );
        said.push_str(&format!("source {}\n", zbuas_quoted(&path)));
    }

    said
}

/// A path as one single-quoted shell word.
///
/// Composed paths carry the temp root and the repository root, neither of which
/// this crate chose, so a path is quoted rather than trusted to be a bare word.
/// A single quote inside one would end the quoting, so it is rendered the one way
/// bash admits inside single quotes — close, escape, reopen.
fn zbuas_quoted(path: &Path) -> String {
    format!("'{}'", path.display().to_string().replace('\'', "'\\''"))
}

// eof
