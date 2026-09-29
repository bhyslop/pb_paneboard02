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

//! `buh_link` renders a hyperlink, and degrades to a readable URL where it cannot.
//!
//! Ported from the bash bench's `buh-link` fixture, three cases, all three
//! carried. The subject is unchanged; what moved is the observer. The bash cases
//! read the rendered bytes out of a capture the bench took inside its own
//! process; these read them out of a child this process spawned.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;
use buk::buah_hurdle::BUAH_OSC8;

/// The modules a link render needs: the yelp module the handbook resolves
/// through, and the handbook itself.
const BUJL_MODULES: &[&str] = &["buym_yelp.sh", "buc_command.sh", "buh_handbook.sh"];

/// The URL every case links to, and the fragment that makes each anchor its own.
const BUJL_URL: &str = "https://example.com#hallmark";

#[test]
fn bujl_a_link_renders_as_an_osc8_hyperlink() {
    buah_Bench::buah_seat(
        "substrate-link-osc8",
        BUJL_MODULES,
        &format!(
            "buh_link \"A \" \"hallmark\" \"{url}\" \" is a named artifact.\"\n",
            url = BUJL_URL
        ),
    )
    .buah_drive(&[])
    .buah_thrived()
    .buah_carries(BUAH_OSC8);
}

#[test]
fn bujl_no_hyperlinks_falls_back_to_an_angle_bracket_url() {
    let said = buah_Bench::buah_seat(
        "substrate-link-fallback",
        BUJL_MODULES,
        &format!(
            "export BURD_NO_HYPERLINKS=1\n\
             buh_link \"A \" \"hallmark\" \"{url}\" \" is a named artifact.\"\n",
            url = BUJL_URL
        ),
    )
    .buah_drive(&[]);

    // BOTH HALVES ARE ASSERTED, because either alone is satisfiable by a
    // rendering nobody wants: the URL can stand in angle brackets INSIDE an
    // OSC-8 sequence, and the absence of OSC-8 says nothing about whether the
    // URL reached the reader at all.
    said.buah_thrived()
        .buah_carries(&format!("<{}>", BUJL_URL))
        .buah_lacks(BUAH_OSC8);
}

#[test]
fn bujl_every_argument_shape_renders() {
    // THE THREE SHAPES ARE THE ARITY'S OWN EDGES: an empty leading phrase, an
    // empty trailing one, and both filled. `buh_link` takes four arguments
    // always, so a shape emptying one of them is where a body indexing its
    // arguments by position would fail.
    buah_Bench::buah_seat(
        "substrate-link-variants",
        BUJL_MODULES,
        "buh_link \"\" \"click here\" \"https://example.com\" \" for details\"\n\
         buh_link \"See \" \"docs\" \"https://example.com/docs\" \"\"\n\
         buh_link \"A \" \"vessel\" \"https://example.com#vessel\" \" is a container image.\"\n",
    )
    .buah_drive(&[])
    .buah_thrived()
    .buah_carries("click here")
    .buah_carries("docs")
    .buah_carries("vessel");
}
// eof
