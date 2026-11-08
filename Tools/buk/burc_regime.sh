#!/bin/bash
#
# Copyright 2025 Scale Invariant, Inc.
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
# BURC Regime - Bash Utility Regime Configuration Module

set -euo pipefail

# The surface forms of the governed words this module speaks, so an enrollment
# description below expands a constant instead of spelling the word, and the
# desuetude gate's code the containment guard below exits on. Sourced at file
# top, ahead of the guard, so the refusal reaches its code before any logging
# exists; buc_die_now may not be loaded on that path, so a failed source exits
# bare. The sourced file carries its own inclusion guard, so a sibling sourcing
# it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || exit 1

######################################################################
# Bootstrap containment guard — the seam between two custodies.
#
# A moorings launcher stub is consumer-owned under the launcher stub law: no
# parcel install writes it, so a stub predating the current bootstrap contract
# survives every kit update and reaches this module with buv never loaded.
# This is the first kit module that contract leaves unmet — zburc_kindle's
# first act is a buv_regime_enroll call, which would die as a bash
# command-not-found before any logging exists to record that it happened.
#
# The contract is therefore tested, never the error trapped, and the refusal
# is written straight to stderr: buh, buym and dispatch logging are all
# themselves downstream of the contract under guard. The message carries the
# canonical stub inline because a station dark at its launcher cannot reach
# the emitter tabtarget, which dispatches through a stub of its own.
#
# The guard detects; it never repairs. Writing the moorings layer here would
# be the kit reaching across the very custody line it stands to police.
if test -z "${ZBUV_SOURCED:-}"; then
  printf '%s\n' \
    "burc_regime: STALE STUB - the bootstrap contract is unmet." \
    "" \
    "  This project's moorings launcher reached the BUK kit without loading" \
    "  the validation module, so no kit code can run. The stub predates the" \
    "  current stub contract. It is consumer-owned: no kit install" \
    "  replaces it, and it will not heal on its own." \
    "" \
    "  Remedy - restore the canonical two-line stub, the shape buut_launcher" \
    "  emits (tt/buw-tt-cl.CreateLauncher.sh). Where every stub is stale," \
    "  repair one by hand first: the emitter dispatches through a stub too." \
    "" \
    '    #!/bin/bash' \
    '    exec "Tools/buk/bul_launcher.sh" "Tools/<kit>/<name>_workbench.sh" "$@"' \
    >&2 || exit 1
  exit "${BUBG_DESUETUDE_DENTIL}"
fi

# Multiple inclusion detection
test -z "${ZBURC_SOURCED:-}" || buc_die_now "Module burc multiply sourced - check sourcing hierarchy"
ZBURC_SOURCED=1

######################################################################
# Internal Functions (zburc_*)

zburc_kindle() {
  test -z "${ZBURC_KINDLED:-}" || buc_die_now "Module burc already kindled"

  # No defaults set — buv uses ${!varname:-} for safe indirect expansion under set -u.
  # Unset variables are detected distinctly from empty by zbuv_check_capture.
  # Exception: BURC_BUK_DIR is derived from BURC_TOOLS_DIR at kindle time (before vet).
  readonly BURC_BUK_DIR="${BURC_TOOLS_DIR:-}/buk"

  # Enroll all BURC variables — single source of truth for validation and rendering

  buv_regime_enroll BURC

  buv_group_enroll "Station Reference"
  buv_string_enroll  BURC_STATION_FILE          1  512  "Path to developer's BURS station file"

  buv_group_enroll "Tabtarget Infrastructure"
  buv_string_enroll  BURC_TABTARGET_DIR         1  128  "Project dir containing entry scripts"
  buv_string_enroll  BURC_TABTARGET_DELIMITER   1    1  "Token separator in tabtarget filenames"

  buv_group_enroll "Project Structure"
  buv_string_enroll  BURC_TOOLS_DIR             1  128  "Project dir containing tool scripts"
  buv_string_enroll  BURC_PROJECT_ROOT          1  512  "Repo root, expressed relative to burc.env"
  buv_string_enroll  BURC_ENDONYM               6   64  "This repository's own ${BUBG_ENDONYM_BASE}: the head buon_, then a lowercase tail"
  buv_string_enroll  BURC_MANAGED_KITS          0  512  "The kits this repository receives by parcel, comma-separated; empty where it receives none"

  buv_group_enroll "Build Output"
  buv_string_enroll  BURC_TEMP_ROOT_DIR         1  512  "Parent dir for per-dispatch scratch subdirs (temp-<stamp>)"
  buv_string_enroll  BURC_OUTPUT_ROOT_DIR       1  512  "Parent dir containing 'current/', cleared and recreated each dispatch"
  buv_string_enroll  BURC_LOOSEBOX_ROOT_DIR     1  512  "Parent dir holding one checkout-keyed ${BUBG_LOOSEBOX_BASE} per checkout, for derived rebuildable build products"

  buv_group_enroll "${BUBG_STATION_LOG_BASE_LETTRINE}"
  buv_xname_enroll   BURC_LOG_LAST              1   64  "Filename stem for the last member of the ${BUBG_STATION_LOG_BASE}"
  buv_xname_enroll   BURC_LOG_EXT               1   16  "File extension of the ${BUBG_STATION_LOG_POSSESSIVE} members (without dot)"
  buv_string_enroll  BURC_BUK_DIR               1  256  "Derived: BUK directory"

  # Guard against unexpected BURC_ variables not in enrollment
  buv_scope_sentinel BURC BURC_

  # Lock all enrolled BURC_ variables against mutation. Nothing exports them:
  # a process that needs the config regime reads it from its file, which the
  # dispatch file names (BURD_REGIME_FILE).
  buv_lock BURC

  readonly ZBURC_KINDLED=1
}

zburc_sentinel() {
  test "${ZBURC_KINDLED:-}" = "1" || buc_die_now "Module burc not kindled - call zburc_kindle first"
}

# Enforce all BURC enrollment validations
zburc_enforce() {
  zburc_sentinel

  buv_vet BURC

  [[ "${BURC_ENDONYM}" =~ ^buon_[a-z][a-z0-9]*$ ]] \
    || buc_reject "${BUBG_REGIME_DENTIL}" "Invalid BURC_ENDONYM format: ${BURC_ENDONYM} (expected the head buon_, then a lowercase tail: a leading letter, then letters and digits)"
}

# eof
