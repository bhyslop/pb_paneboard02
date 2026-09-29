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

//! The substrate's own self-test — the library face.
//!
//! What stands here is the support the hurdles share, and the hurdles themselves
//! stand under `tests/`. The split is cargo's rather than a choice: a hurdle that
//! spawns a door wants the seat cargo gives an integration test, and support a
//! hurdle imports has to be a library for it to import.
//!
//! EVERY HURDLE JUDGES THE SHELL FROM OUTSIDE IT. The substrate under test is
//! bash, and a bash harness asserting on a bash process's death shares a failure
//! domain with the thing it is watching — when the logging stack eats a
//! diagnostic, a harness reporting the loss from inside that same stack reports
//! silence as success. So a hurdle composes a script, spawns it, and reads the
//! exit code and both streams in THIS process, which no part of the dispatch can
//! reach.
//!
//! THE CAPABILITY LINE IS POSTURE AND NEVER LANGUAGE. Nothing here says bash
//! cannot assert soundly; what it says is that a harness must observe from
//! outside the process tree that dies. This crate is the substrate's answer to
//! that requirement and not a claim about the language it tests.

#![deny(warnings)]
#![allow(non_camel_case_types)]

pub mod buah_hurdle;
pub mod buas_seat;

// eof
