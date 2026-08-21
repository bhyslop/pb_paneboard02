#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
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
# BUL Launcher - Shared launcher logic for BUK workbenches.
# Sourced by individual launcher stubs in rbmm_moorings/rbml_launchers/
# Compatible with Bash 3.2 (e.g., macOS default shell)
#
# NOTE: This is bootstrap infrastructure, not a full module.
# No kindle/sentinel pattern - this runs before other modules are loaded.

# Guard against multiple inclusion
test -z "${ZBUL_LAUNCHER_SOURCED:-}" || return 0
ZBUL_LAUNCHER_SOURCED=1

# Establish project root. z-launcher.sh (the universal trampoline that exec's
# every launcher stub) has already chdir'd to repo root, so trust PWD rather
# than counting directory hops back from the stub's location — the latter
# couples to where the launcher dir sits and breaks whenever it moves.
ZBUL_PROJECT_ROOT="${PWD}"

# Config directory is supplied by the project-intimate trampoline (z-launcher),
# the SOLE file that knows this project's moorings/config dir name. The shared
# kit no longer hardcodes the name — it consumes the exported absolute path, so
# one kit serves every consumer (.buk, rbmm_moorings, …). The basename is
# derived below as BURD_MOORINGS_DIR for operator-facing display.
test -n "${BURD_CONFIG_DIR:-}" || {
  echo "bul_launcher: BURD_CONFIG_DIR unset — dispatch must run through z-launcher" >&2
  exit 1
}
export BURD_CONFIG_DIR

# Moorings basename — the repo-root-relative config dir name, derived from the
# absolute path. Operator-facing messages render paths relative to it because
# z-launcher leaves the operator at repo root. A BURD_ dispatch value born here
# in bootstrap (two consumers — this file's SETUP NEEDED block and burs_regime's
# enroll description — run before the BURD kindle), enrolled in burd_regime, and
# allowlisted in bud_dispatch.
export BURD_MOORINGS_DIR="${BURD_CONFIG_DIR##*/}"

# Load BURC configuration
export BURD_REGIME_FILE="${BURD_CONFIG_DIR}/burc.env"
source "${BURD_REGIME_FILE}" || exit 1 # buc_die_now not available yet

# Apply BURV (Bash Utility Regime Verification) overrides if set
BURC_OUTPUT_ROOT_DIR="${BURV_OUTPUT_ROOT_DIR:-${BURC_OUTPUT_ROOT_DIR}}"
BURC_TEMP_ROOT_DIR="${BURV_TEMP_ROOT_DIR:-${BURC_TEMP_ROOT_DIR}}"

# Source BUK modules
export BURD_STATION_FILE="${ZBUL_PROJECT_ROOT}/${BURC_STATION_FILE}"
source "${BURC_TOOLS_DIR}/buk/buc_command.sh" || exit 1 # buc_die_now not available yet
source "${BURC_TOOLS_DIR}/buk/buv_validation.sh" || buc_die_now "Failed to source buv_validation.sh"
source "${BURC_TOOLS_DIR}/buk/bubc_constants.sh" || buc_die_now "Failed to source bubc_constants.sh"
zbuv_kindle

# Load and kindle BURC
source "${BURC_TOOLS_DIR}/buk/burc_regime.sh" || buc_die_now "Failed to source burc_regime.sh"
zburc_kindle
zburc_enforce

# BURS station load is skipped under BURD_NO_LOG. No-log tabtargets (e.g.
# handbooks) need only BURC and must run on a fresh clone before any station
# file exists. The flag is the tabtarget's own — exported in its BURD_* block
# ahead of dispatch, never ambient (BUr_q2m) — so it is
# visible here. This collapses the former separate nolog launcher.
if test -z "${BURD_NO_LOG:-}"; then
  # bud_dispatch is the canonical exporter of BURD_TABTARGET_DIR, but the
  # SETUP NEEDED block below uses buym_tt_yawp which requires it earlier.
  BURD_TABTARGET_DIR="${BURC_TABTARGET_DIR}"

  # Load yelp + handbook so the SETUP NEEDED block can yawp paths, tabtarget
  # references, and recommended file contents, and print them via buh_*.
  source "${BURC_TOOLS_DIR}/buk/buym_yelp.sh"    || buc_die_now "Failed to source buym_yelp.sh"
  source "${BURC_TOOLS_DIR}/buk/buh_handbook.sh" || buc_die_now "Failed to source buh_handbook.sh"

  # Shared with tt/buw-SI.StationInit.sh — single home for the field template
  source "${BURC_TOOLS_DIR}/buk/burs_template.sh" || buc_die_now "Failed to source burs_template.sh"

  # Load BURS configuration and kindle
  z_station_file="${ZBUL_PROJECT_ROOT}/${BURC_STATION_FILE}"
  if ! test -f "${z_station_file}"; then
    buym_ui_yawp  "${z_station_file}";              z_path_yp="${z_buym_yelp}"
    buym_ui_yawp  "${BURC_STATION_FILE}";           z_rel_yp="${z_buym_yelp}"
    buym_ui_yawp  "${BURD_REGIME_FILE}";            z_burc_yp="${z_buym_yelp}"

    buh_e
    buh_section "SETUP NEEDED: Station Regime file not found"
    buh_e
    buh_line    "  Missing: ${z_path_yp}"
    buh_e
    buh_line    "  The Bash Utility Kit (BUK) launcher uses two regime files:"
    buh_e
    buh_line    "    Config Regime (BURC) - checked into the repo at ${z_burc_yp}"
    buh_line    "      Project-level settings: tool paths, tabtarget layout, and the"
    buh_line    "      location of the Station Regime file."
    buh_tt      "      Inspect: " "buw-rcr"
    buh_e
    buh_line    "    Station Regime (BURS) - developer-specific, NOT in git"
    buh_line    "      Machine-level settings that vary per developer or workstation."
    buh_line    "      The Config Regime says to look for it at: ${z_rel_yp}"
    buh_tt      "      Inspect: " "buw-rsr"
    buh_e
    buh_line    "  Other toolkits in the project may define additional regime files."
    buh_e
    buh_line    "  The fastest fix: run the fresh-station bootstrap, which writes a"
    buh_line    "  complete Station Regime file for you."
    buh_tt      "  " "buw-SI"
    buh_e
    buh_line    "  Or create it yourself with this content:"
    buh_e
    for z_i in "${!ZBURS_TEMPLATE_NAMES[@]}"; do
      buym_cmd_yawp "${ZBURS_TEMPLATE_NAMES[${z_i}]}=${ZBURS_TEMPLATE_VALUES[${z_i}]}"
      buh_line    "    ${z_buym_yelp}"
    done
    buh_e
    buh_line    "  All ${#ZBURS_TEMPLATE_NAMES[@]} variables are required."
    buh_e
    for z_i in "${!ZBURS_TEMPLATE_NAMES[@]}"; do
      buh_line    "  ${ZBURS_TEMPLATE_NAMES[${z_i}]}: ${ZBURS_TEMPLATE_COMMENTS[${z_i}]}"
      buh_e
    done
    buh_e
    exit 1
  fi
  source "${z_station_file}" || buc_die_now "Failed to source: ${z_station_file}"

  # Apply BURV (Bash Utility Regime Verification) overrides if set
  BURS_LOG_DIR="${BURV_LOG_DIR:-${BURS_LOG_DIR}}"
  BURS_TACKROOM="${BURV_TACKROOM:-${BURS_TACKROOM:-}}"

  source "${BURC_TOOLS_DIR}/buk/burs_regime.sh" || buc_die_now "Failed to source burs_regime.sh"
  zburs_kindle
  zburs_enforce
fi

# Helper function to delegate to BURD
# Usage: bul_launch "path/to/workbench.sh" "$@"
bul_launch() {
  local z_coordinator="$1"
  shift

  # Detect terminal width via /dev/tty (survives exec chain and dispatch pipes)
  # Subshell probe: /dev/tty may exist but not be openable (CI, sandbox)
  BURD_TERM_COLS=80
  if (exec </dev/tty) 2>/dev/null; then
    read -r _ BURD_TERM_COLS < <(stty size </dev/tty 2>/dev/null)
    test -n "${BURD_TERM_COLS}" || BURD_TERM_COLS=80
  fi
  export BURD_TERM_COLS

  export BURD_COORDINATOR_SCRIPT="${z_coordinator}"
  exec "${BURC_TOOLS_DIR}/buk/bud_dispatch.sh" "${1##*/}" "${@:2}"
}
