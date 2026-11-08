#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Brad Hyslop <bhyslop@scaleinvariant.org>
#
# JJZ Zipper - Colophon registry for JJK workbench dispatch

set -euo pipefail

# Multiple inclusion guard
test -z "${ZJJZ_SOURCED:-}" || buc_die_now "Module jjz multiply sourced - check sourcing hierarchy"
ZJJZ_SOURCED=1

# The surface forms of the governed words JJ speaks, so an enrollment
# description below can expand a constant instead of spelling the word.
# The breviary carries its own inclusion guard.
source "${BASH_SOURCE[0]%/*}/jjsb_breviary.sh" || buc_die_now "Failed to source jjsb_breviary.sh"

######################################################################
# Colophon registry initialization

zjjz_kindle() {
  test -z "${ZJJZ_KINDLED:-}" || buc_die_now "jjz already kindled"

  # Verify buz zipper is kindled
  zbuz_sentinel

  # Open the JJ tome: the division of the shared roll this zipper owns. JJ
  # projects no generated const block — its colophon consts are hand-held in
  # vov_veiled/jjk/src/jjr0/jjru_util.rs — so the add and strip prefixes are the
  # enroll varnames' own, minting nothing and leaving a const stem unchanged
  # should anything ever project it. The tome earns its seat one level down: it
  # is what lets a roll emitter scope to this zipper's run instead of walking
  # whatever else shares the roll.
  buz_tome_seat "jjz" "JJZ_" "JJZ_"

  # Dispatch — session-opening working doors and read-only checks, single-character
  # colophons (jjw-). The letter is the first letter of the door's frontispiece;
  # the digit 0 is admitted for the help door alone, because it sorts first under
  # every collation where a letter does not and so marks the door to try first.
  buz_group JJZ__GROUP_DISPATCH  "jjw-"   "Dispatch — JJ session-opening working doors and read-only checks"
  buz_enroll JJZ_DISPATCH_HELP    "jjw-0"   "jjsl_cli.sh" "jjsl_help"      "param1"  "List every JJ door with what it takes and what it does; naming NO colophon lists the whole family, naming one lists that door alone"
  buz_enroll JJZ_DISPATCH_SADDLE  "jjw-s"   "jjsl_cli.sh" "jjsl_saddle"    "param1"  "${JJSB_SADDLE_BASE_LETTRINE} a pace or heat: billet + launch (target elected from the record; cwd unread)"
  buz_enroll JJZ_DISPATCH_OSTLER  "jjw-p"   "jjsl_cli.sh" "jjsl_ostler"    "param1"  "Open the planning seat, where dockets are cut and refined: name NONE to list every heat and plan over the whole estate, or one ${JJSB_TROPA_BASE} key from the roster to plan the heats its ${JJSB_WAYBILL_BASE} names"
  buz_enroll JJZ_DISPATCH_DROVER  "jjw-o"   "jjsl_cli.sh" "jjsl_drover"    "param1"  "Open the ruling seat above a wave of ${JJSB_STRAPPER_PLURAL} over every registered sire: name one ${JJSB_TROPA_BASE} key from the roster, whose ${JJSB_WAYBILL_BASE} from the studbook is composed into its orders, or name NONE to list the roster"
  buz_enroll JJZ_DISPATCH_INSTANT "jjw-i"   "jjsl_cli.sh" "jjsl_vaquero"   "param1"  "Open an immediate-work seat: name a heat and then a sire, and the session enrolls its own pace, works it and closes before the chat ends - both are required"
  buz_enroll JJZ_DISPATCH_SIGHT   "jjw-c"   "jjsl_cli.sh" "jjsl_sight"     ""        "Sight every JJ blotter lock and report who holds it (read-only; lock recovery itself is human-only)"

  # Ceremony — station ceremonies, capital-letter colophons mark durable/surprising confirm-gated doors (jjw-)
  buz_group JJZ__GROUP_CEREMONY  "jjw-"   "Ceremony — station ceremonies (confirm-gated)"
  buz_enroll JJZ_DISPATCH_CASHIER "jjw-C"   "jjsl_cli.sh" "jjsl_cashier"   ""        "Cashier a derelict lock-holder - HUMAN-ONLY ceremony: report, then offer each lock for breaking behind this terminal's typed gate (unskippable)"
  buz_enroll JJZ_DISPATCH_MUCK    "jjw-M"   "jjsl_cli.sh" "jjsl_muck"      "param1"  "Muck a named billet: plan, then destroy (confirm-gated) — the operator's one deliberate data-loss surface"
  buz_enroll JJZ_DISPATCH_ABUTTAL "jjw-A"   "jjsl_cli.sh" "jjsl_abuttal"   ""        "Apply the estate rules to this station from studbook canon: the two CLAUDE.md texts the working doors refuse without (divergence confirm-gated)"
  buz_enroll JJZ_BLOTTER_SALUTE   "jjw-S"   "jjsl_cli.sh" "jjsl_salute"    "param1"  "Lay the salutations a founding is handed: name the portrait file, then the directory to lay them in; writes one text per roster stem from this stand's starter-kit templates, the portrait filled into each"
  buz_enroll JJZ_BLOTTER_FOUND    "jjw-F"   "jjsl_cli.sh" "jjsl_found"     "param1"  "Found the studbook: name its remote, then the salutation directory, then optionally a gallops file to import; writes the empty store as the genesis, or as the next revision over a standing store with its mint seeds carried (confirm-gated)"
  buz_enroll JJZ_BLOTTER_GERMINATE "jjw-V"  "jjsl_cli.sh" "jjsl_germinate" "param1"  "Cut the corpus trunk after the founding: optionally name a file of further trees this estate bars or opens; writes the estate's infield text from this stand's starter-kit template as the corpus line's root and pushes it, refused where that line already stands"
  buz_enroll JJZ_BLOTTER_KEURING  "jjw-K"   "jjsl_cli.sh" "jjsl_keuring"   "param1"  "${JJSB_KEURING_BASE_VERSAL} — admit a sire to the register: name the infield clone, then the handle to allot it; every other fact is read off that tree, and the handle is gated unique and against the cipher registry (confirm-gated)"
  buz_enroll JJZ_BLOTTER_TURNOUT  "jjw-T"   "jjsl_cli.sh" "jjsl_turnout"   "param1"  "${JJSB_TURNOUT_BASE_VERSAL} — remove a sire from the register: name the handle alone, no tree being read; refused while any heat, live pace or replication entry still names the sire, and the refusal enumerates them (confirm-gated)"

  readonly ZJJZ_KINDLED=1
}

######################################################################
# Internal sentinel

zjjz_sentinel() {
  test "${ZJJZ_KINDLED:-}" = "1" || buc_die_now "Module jjz not kindled - call zjjz_kindle first"
}

# eof
