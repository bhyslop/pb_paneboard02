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

//! The BURE regime admits what it enrolled, at the widths it enrolled it.
//!
//! Ported from the bash bench's `bure-tweak` fixture, nine cases, all nine
//! carried.
//!
//! THE AMBIENT CHANNEL IS CLEARED AT THE TOP OF EVERY COORDINATOR, and this is
//! the one place in the port where clearing is genuinely owed rather than merely
//! tidy. `BURE_` is the substrate's operator-ambient channel BY DESIGN, so the
//! kennel's dispatch deliberately passes it through untouched where it strips
//! every other regime prefix. That is correct for the substrate and fatal for
//! these hurdles: the scope sentinel refuses any `BURE_` name it did not enroll,
//! so one stray variable in a station's environment would turn every positive
//! case red and one stray `BURE_LABEL` would make a negative case pass for the
//! wrong reason. The clear is a loop over `${!BURE_@}` rather than a list,
//! because a list is a second enrollment free to fall behind the first.
//!
//! EVERY REFUSAL NAMES THE VARIABLE IT REFUSED, and that assertion is not
//! decoration. On this fixture's first drive all four negative hurdles were
//! GREEN while all five positives were red: the coordinator never kindled the
//! validation module, so it died before reaching the regime at all — and a
//! hurdle asserting only that the shell died cannot tell a refusal by its
//! subject from a death on the way to it. The positives were the control that
//! exposed it. So each negative now asserts the refused variable's own name in
//! the diagnostic, which no death short of the gate can produce.
//!
//! ONE PAYLOAD IS STRENGTHENED RATHER THAN CARRIED VERBATIM, and it is the
//! too-long tweak name. The bash case built its name from sixty-five `x`
//! characters and asserted only that the regime refused it — but a name of `x`
//! characters fails the `buo` sprue check as surely as it fails the width, and
//! the sprue check is the one it meets first. The case's own words say the
//! subject is the width, so the ported payload carries a properly sprued name at
//! sixty-five characters, where the width is the only thing left to refuse it.
//! The row is the same row; the payload now isolates what the row claims.

#![deny(warnings)]

use buk::buah_hurdle::buah_Bench;

/// The modules a regime reading needs. The order is the substrate's own: the
/// validation module loads before the regime that enrolls through it, which is
/// the bootstrap contract the stale-launcher guard exists to enforce.
const BUJE_MODULES: &[&str] = &[
    "buym_yelp.sh",
    "buc_command.sh",
    "buv_validation.sh",
    "bure_regime.sh",
];

/// The widths the regime enrolls, named as the enrollment names them.
const BUJE_NAME_WIDTH: usize = 64;
const BUJE_VALUE_WIDTH: usize = 256;
const BUJE_LABEL_WIDTH: usize = 120;

/// The sprue a tweak name must carry, and BUK's own segment within it.
const BUJE_SPRUE: &str = "buost_";

/// Compose a tweak name of exactly the given width that carries the sprue.
///
/// SO THE WIDTH IS THE ONLY THING UNDER TEST. A name failing two gates proves
/// nothing about either.
fn buje_sprued(width: usize) -> String {
    let mut name = String::from(BUJE_SPRUE);
    while name.len() < width {
        name.push('x');
    }
    assert_eq!(name.len(), width, "the sprue alone is wider than {}", width);
    name
}

/// Drive one regime reading: clear the ambient channel, export what the case
/// declares, then kindle and enforce.
///
/// KINDLE AND ENFORCE ARE BOTH RUN because they refuse on different grounds and
/// a case naming only one would miss the other. The scope sentinel and the
/// enrollment widths fire at kindle; the custom cross-field rules fire at
/// enforce.
fn buje_regime(name: &str, exports: &[(&str, &str)]) -> buk::buah_hurdle::buah_Said {
    let mut body = String::from(
        "for z_v in ${!BURE_@}; do unset \"${z_v}\"; done\n\
         buc_context \"buje\"\n",
    );
    for (var, value) in exports {
        body.push_str(&format!("export {}='{}'\n", var, value));
    }
    // THE VALIDATION MODULE IS KINDLED FIRST, and this line is here because its
    // absence was caught by the positives while every negative went green
    // WITHOUT it. `zbure_kindle` enrolls through `buv`, so an un-kindled `buv`
    // kills the coordinator before the regime is ever read — which reads as a
    // refusal, and a refusal is exactly what four of these hurdles assert. They
    // passed against a shell that had not reached their subject at all.
    body.push_str(
        "zbuv_kindle\nzbure_kindle\nzbure_enforce\necho \"buje regime enforced\"\n",
    );

    buah_Bench::buah_seat(name, BUJE_MODULES, &body).buah_drive(&[])
}

#[test]
fn buje_an_empty_tweak_channel_is_admitted() {
    // THE DEFAULT SHAPE, and the control every negative case below leans on: a
    // regime that refused everything would satisfy all five refusals and fail
    // only here.
    buje_regime("substrate-bure-empty", &[])
        .buah_thrived()
        .buah_carries("buje regime enforced");
}

#[test]
fn buje_a_tweak_name_and_value_together_are_admitted() {
    buje_regime(
        "substrate-bure-both",
        &[
            ("BURE_TWEAK_NAME", "buost_example"),
            ("BURE_TWEAK_VALUE", "us-docker.pkg.dev/proj/repo/img:latest"),
        ],
    )
    .buah_thrived();
}

#[test]
fn buje_a_tweak_name_without_a_value_is_admitted() {
    // THE HALVES ARE INDEPENDENT, deliberately: a tweak whose whole content is
    // its name is a behavioural seam being armed, and requiring a value would
    // make every such seam invent one.
    buje_regime(
        "substrate-bure-name-only",
        &[("BURE_TWEAK_NAME", "buost_example")],
    )
    .buah_thrived();
}

#[test]
fn buje_a_tweak_value_without_a_name_is_admitted() {
    buje_regime(
        "substrate-bure-value-only",
        &[("BURE_TWEAK_VALUE", "some-override-value")],
    )
    .buah_thrived();
}

#[test]
fn buje_a_tweak_name_past_its_width_is_refused() {
    buje_regime(
        "substrate-bure-name-wide",
        &[("BURE_TWEAK_NAME", &buje_sprued(BUJE_NAME_WIDTH + 1))],
    )
    .buah_died()
    .buah_carries("BURE_TWEAK_NAME");
}

#[test]
fn buje_a_tweak_value_past_its_width_is_refused() {
    buje_regime(
        "substrate-bure-value-wide",
        &[("BURE_TWEAK_VALUE", &"x".repeat(BUJE_VALUE_WIDTH + 1))],
    )
    .buah_died()
    .buah_carries("BURE_TWEAK_VALUE");
}

#[test]
fn buje_a_label_at_its_width_is_admitted() {
    // THE CEILING ITSELF IS ADMITTED, which is what makes the refusal below a
    // reading of the boundary rather than of some width below it.
    buje_regime(
        "substrate-bure-label-at",
        &[("BURE_LABEL", &"x".repeat(BUJE_LABEL_WIDTH))],
    )
    .buah_thrived();
}

#[test]
fn buje_a_label_past_its_width_is_refused() {
    buje_regime(
        "substrate-bure-label-wide",
        &[("BURE_LABEL", &"x".repeat(BUJE_LABEL_WIDTH + 1))],
    )
    .buah_died()
    .buah_carries("BURE_LABEL");
}

#[test]
fn buje_an_unenrolled_variable_trips_the_scope_sentinel() {
    // THE SENTINEL IS WHAT MAKES A TYPO LOUD. Without it an operator setting a
    // misspelled tweak name gets silence and a run that quietly did not take the
    // override — the failure this gate converts into a refusal.
    buje_regime("substrate-bure-stranger", &[("BURE_BOGUS", "foo")])
        .buah_died()
        .buah_carries("BURE_BOGUS");
}
// eof
