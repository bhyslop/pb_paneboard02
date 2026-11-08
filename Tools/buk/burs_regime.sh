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
# BURS Regime - Bash Utility Regime Station Module

set -euo pipefail

# The gate codes this module rejects with, from the substrate's generated
# constants, sourced above the inclusion guard so the tinder block stays the run
# behind it. The sourced file carries its own inclusion guard, so a sibling
# sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"

# Multiple inclusion detection
test -z "${ZBURS_SOURCED:-}" || buc_die_now "Module burs multiply sourced - check sourcing hierarchy"
ZBURS_SOURCED=1

######################################################################
# Internal Functions (zburs_*)

zburs_kindle() {
  test -z "${ZBURS_KINDLED:-}" || buc_die_now "Module burs already kindled"

  # No defaults set — buv uses ${!varname:-} for safe indirect expansion under set -u.
  # Unset variables are detected distinctly from empty by zbuv_check_capture.

  # Enroll all BURS variables — single source of truth for validation and rendering

  buv_regime_enroll BURS

  buv_group_enroll "Developer Identity"
  buv_xname_enroll   BURS_USER     1   32  "Local developer username (routes to ${BURD_MOORINGS_DIR}/${BUBC_rbmu_users_subdir}/ profiles)"
  buv_string_enroll  BURS_TINCTURE 1    3  "Per-station tincture, under two charters: test fixtures compose it into cloud/runtime prefixes and family stems for parallel-run disjointness on a shared payor manor, and a kit keeping a per-station record names this station's share by it, so it must stay stable for the station's life and unique across the estate; a reader outside bash takes it from this file directly (lowercase alphanumeric, leading letter, no hyphen)"

  buv_group_enroll "${BUBG_STATION_LOG_BASE_LETTRINE}"
  buv_string_enroll  BURS_LOG_DIR  1  512  "Directory of the ${BUBG_STATION_LOG_BASE}, relative to the project root"

  buv_group_enroll "Shared Tooling"
  buv_string_enroll  BURS_TACKROOM 0  512  "Optional. Root for large immutable tool stores the clones beside this one draw from, rather than each keeping its own copy (VOK keeps the pinned Rust toolchain and the cargo registry cache here); a kit needing it refuses in its own voice where it is absent. Relative to the project root, as the ${BUBG_STATION_LOG_POSSESSIVE} directory is"
  buv_string_enroll  BURS_HAYLOFT  0  512  "Optional. Folder where the archives of aged ${BUBG_STATION_LOG_BASE} members and run folders are kept; a kit needing it refuses in its own voice where it is absent. Relative to the project root, as the ${BUBG_STATION_LOG_POSSESSIVE} directory is"

  # Guard against unexpected BURS_ variables not in enrollment
  buv_scope_sentinel BURS BURS_

  # Lock all enrolled BURS_ variables against mutation
  buv_lock BURS

  readonly ZBURS_KINDLED=1
}

zburs_sentinel() {
  test "${ZBURS_KINDLED:-}" = "1" || buc_die_now "Module burs not kindled - call zburs_kindle first"
}

# Enforce all BURS enrollment validations
zburs_enforce() {
  zburs_sentinel

  buv_vet BURS

  [[ "${BURS_TINCTURE}" =~ ^[a-z][a-z0-9]{0,2}$ ]] \
    || buc_reject "${BUBG_REGIME_DENTIL}" "Invalid BURS_TINCTURE format: ${BURS_TINCTURE} (expected 1-3 chars, lowercase alphanumeric starting with letter; no hyphens)"

  # A station file names its stores relative to the project root, and the
  # refusal is the whole mechanism: there is no override. The values read here
  # are the station file's own, the launcher folding no BURV_ override over
  # them ahead of this check — a dispatch's override is absolute by
  # construction and is the dispatch's, never the station's. The two kennel
  # stores are optional, so each is judged only where the file sets it, and
  # each refusal's example is the folder its definition suggests.
  [[ "${BURS_LOG_DIR}" != /* ]] \
    || buc_reject "${BUBG_REGIME_DENTIL}" "BURS_LOG_DIR is absolute (${BURS_LOG_DIR}) - the ${BUBG_STATION_BASE} file names it relative to the project root, e.g. BURS_LOG_DIR=../${BUBG_LOG_DIR_SOCLE}"
  [[ "${BURS_TACKROOM:-}" != /* ]] \
    || buc_reject "${BUBG_REGIME_DENTIL}" "BURS_TACKROOM is absolute (${BURS_TACKROOM}) - the ${BUBG_STATION_BASE} file names it relative to the project root, e.g. BURS_TACKROOM=../${BUBG_TACKROOM_SOCLE}"
  [[ "${BURS_HAYLOFT:-}" != /* ]] \
    || buc_reject "${BUBG_REGIME_DENTIL}" "BURS_HAYLOFT is absolute (${BURS_HAYLOFT}) - the ${BUBG_STATION_BASE} file names it relative to the project root, e.g. BURS_HAYLOFT=../${BUBG_HAYLOFT_SOCLE}"
}

# eof
