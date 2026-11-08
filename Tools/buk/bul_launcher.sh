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
# BUL Launcher - Shared launcher logic for BUK workbenches.
# Run as a command by every launcher stub in a moorings launcher directory,
# which execs it with the workbench path ahead of the trampoline's arguments.
# Compatible with Bash 3.2 (e.g., macOS default shell)
#
# NOTE: This is bootstrap infrastructure, not a module.
# No kindle/sentinel pattern - this runs before other modules are loaded.

set -euo pipefail

# RUN, NEVER SOURCED. A launcher stub predating the exec form sources this file
# and calls a function that no longer stands. That stub is consumer-owned, no
# kit install replaces it, and it will not heal on its own, so the refusal is
# the desuetude gate's and carries the canonical stub inline: a station dark at
# its stubs reaches no door that could print it. The test reads this file's own
# path against the process's, as the dispatcher's does, and stands ahead of the
# contract test, since a sourcing stub hands on exactly the trampoline's
# contract arguments. The gate's code is read from the generated constants
# file, which calls nothing, and only once the file is found sourced.
z_bul_run=1
test "${BASH_SOURCE[0]}" = "${0}" || z_bul_run=0
if test "${z_bul_run}" = "0"; then
  source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || exit 1
  printf '%s\n' \
    "bul_launcher: STALE STUB - bul_launcher.sh is run, never sourced." \
    "" \
    "  This project's ${BUBG_LAUNCHER_BASE} stub sources the shared script, a" \
    "  form the kit no longer runs. It is consumer-owned: no kit install replaces" \
    "  it, and it will not heal on its own. Regenerate every stub through the" \
    "  stub door, buut_launcher (tt/buw-tt-cl.CreateLauncher.sh). Where" \
    "  every stub is stale, write the BUK workbench's stub by hand first, since" \
    "  that door dispatches through a stub too. The canonical stub is two lines:" \
    "" \
    '    #!/bin/bash' \
    '    exec "Tools/buk/bul_launcher.sh" "Tools/<kit>/<name>_workbench.sh" "$@"' \
    >&2 || exit 1
  exit "${BUBG_DESUETUDE_DENTIL}"
fi

# THE TRAMPOLINE'S CONTRACT, tested from the arguments alone before any file is
# sourced. The launcher stub hands the workbench path first, then what the
# trampoline handed the stub: the configuration, the seat and the moorings
# directory, both absolute, then the tabtarget basename and the user's
# arguments. A trampoline predating the configuration line hands the tabtarget
# basename first and exports its launcher instead. That trampoline is
# consumer-owned, no kit install replaces it, and it will not heal on its own,
# so the refusal is the desuetude gate's and carries the canonical trampoline
# inline: a station dark at its trampoline reaches no door that could print it.
# The gate's code is read from the generated constants file, which calls
# nothing, and only once the contract has failed.
z_bul_contract=1
test "$#" -ge 5 || z_bul_contract=0
case "${2:-}" in
  launcher.*.sh|launcher.*.sh" "*) ;;
  *) z_bul_contract=0 ;;
esac
case "${3:-}" in
  /*) ;;
  *) z_bul_contract=0 ;;
esac
case "${4:-}" in
  /*) ;;
  *) z_bul_contract=0 ;;
esac
if test "${z_bul_contract}" = "0"; then
  source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || exit 1
  printf '%s\n' \
    "bul_launcher: STALE TRAMPOLINE - the launch contract is unmet." \
    "" \
    "  This project's tt/z-launcher.sh predates the configuration line: it" \
    "  handed the stub no configuration, seat and ${BUBG_MOORINGS_BASE} directory." \
    "  It is consumer-owned: no kit install replaces it, and it will not heal" \
    "  on its own. Restore the canonical trampoline, filling the one name:" \
    "" \
    '    #!/bin/bash' \
    '    set -u' \
    '    z_dir="${BASH_SOURCE[0]%/*}"' \
    '    case "${z_dir}" in' \
    '      /*) ;;' \
    '      *)  z_dir="${PWD}/${z_dir}" ;;' \
    '    esac' \
    '    z_moorings_dir="<your-moorings-dirname>"' \
    "    z_canonical=\"set -- 'launcher.<id>_workbench.sh[ buuc_…]' \\\"\\\$@\\\"\"" \
    '    z_launcher_name=""' \
    '    test "$#" -lt 2 || z_launcher_name="${2%% *}"' \
    '    case "${z_launcher_name}" in' \
    '      launcher.*.sh) ;;' \
    '      *) echo "z-launcher: no configuration: ${z_canonical}" >&2; exit 1 ;;' \
    '    esac' \
    '    z_launcher="${z_dir}/../${z_moorings_dir}/buml_launchers/${z_launcher_name}"' \
    '    test -f "${z_launcher}" || { echo "z-launcher: no stub ${z_launcher}: ${z_canonical}" >&2; exit 1; }' \
    '    cd -P "${z_dir}/.." || { echo "z-launcher: cannot cd to repo root" >&2; exit 1; }' \
    '    exec "${z_launcher}" "${2}" "${PWD}" "${PWD}/${z_moorings_dir}" "${1}" "${@:3}"' \
    "" \
    "  Then regenerate the ${BUBG_TABTARGET_PLURAL} through the create doors, each" \
    "  carrying its configuration line; where all of them are stale, write the" \
    "  create door's own by hand first, since it dispatches through the" \
    "  trampoline too." \
    >&2 || exit 1
  exit "${BUBG_DESUETUDE_DENTIL}"
fi

# THE CONFIGURATION: the launcher stub's basename, then at most two words under
# the buuc_ sprue, the own-log word standing alone. A tabtarget is generated, so
# a malformed word is a hand edit, and it dies imprecisely naming the canonical
# line rather than spending a band code.
z_bul_coordinator="${1:-}"
ZBUL_CONFIGURATION="${2:-}"
ZBUL_SEAT="${3:-}"
z_bul_moorings="${4:-}"
z_bul_canonical="set -- 'launcher.<id>_workbench.sh[ buuc_interactive][ buuc_nolog]' \"\$@\", or 'launcher.<id>_workbench.sh buuc_ownlog'"
z_bul_words=()
read -r -a z_bul_words <<< "${ZBUL_CONFIGURATION}" || {
  printf '%s\n' "bul_launcher: cannot read the configuration '${ZBUL_CONFIGURATION}'" >&2 || exit 1
  exit 1
}
z_bul_nolog=""
z_bul_interactive=""
z_bul_ownlog=""
z_bul_i=1
while test "${z_bul_i}" -lt "${#z_bul_words[@]}"; do
  case "${z_bul_words[${z_bul_i}]}" in
    buuc_nolog)       test -z "${z_bul_nolog}"       || z_bul_i=99; z_bul_nolog=1 ;;
    buuc_interactive) test -z "${z_bul_interactive}" || z_bul_i=99; z_bul_interactive=1 ;;
    buuc_ownlog)      test -z "${z_bul_ownlog}"      || z_bul_i=99; z_bul_ownlog=1 ;;
    *)                z_bul_i=99 ;;
  esac
  z_bul_i=$((z_bul_i + 1))
done
if test "${z_bul_i}" -ge 99 \
   || test "${#z_bul_words[@]}" -gt 3 \
   || { test -n "${z_bul_ownlog}" && test "${#z_bul_words[@]}" -gt 2; }; then
  printf '%s\n' "bul_launcher: malformed configuration '${ZBUL_CONFIGURATION}'; the configuration line is one of: ${z_bul_canonical}" >&2 || exit 1
  exit 1
fi

# The workbench path and the three contract arguments are consumed here, so
# what stands is the tabtarget basename and the user's arguments alone.
set -- "${@:5}"

# A pointer and a kit directory inherited from a parent door are that door's
# hand-offs. This launch composes its own run's, so the inherited pair is
# withdrawn before the command module, which kindles from a pointer, is sourced.
unset BURD_BURD_FILE BURD_BUK_DIR

# Establish project root. z-launcher.sh (the universal trampoline that exec's
# every launcher stub) has already chdir'd to repo root, so trust PWD rather
# than counting directory hops back from the stub's location — the latter
# couples to where the launcher dir sits and breaks whenever it moves.
ZBUL_PROJECT_ROOT="${PWD}"

# Config directory is handed by the project-intimate trampoline (z-launcher),
# the one file the shared kit learns this project's moorings/config dir name
# from. The shared kit hardcodes no name — it consumes the handed absolute path,
# so one kit serves every consumer (.buk, rbmm_moorings, …). The basename is
# derived below as BURD_MOORINGS_DIR for operator-facing display. These names
# are this process's own: the dispatch is handed the directory by argument and
# derives the rest, and nothing here exports them.
BURD_CONFIG_DIR="${z_bul_moorings}"

# Moorings basename — the repo-root-relative config dir name, derived from the
# absolute path. Operator-facing messages render paths relative to it because
# z-launcher leaves the operator at repo root. A BURD_ dispatch value born here
# in bootstrap (two consumers — this file's SETUP NEEDED block and burs_regime's
# enroll description — run before the BURD kindle), enrolled in burd_regime.
BURD_MOORINGS_DIR="${BURD_CONFIG_DIR##*/}"

# Load BURC configuration
BURD_REGIME_FILE="${BURD_CONFIG_DIR}/burc.env"
source "${BURD_REGIME_FILE}" || exit 1 # buc_die_now not available yet

# Apply BURV (Bash Utility Regime Verification) overrides if set
# A regime value the file omits stands empty here, so its absence is the
# enforce's to name rather than an unbound-variable death.
BURC_OUTPUT_ROOT_DIR="${BURV_OUTPUT_ROOT_DIR:-${BURC_OUTPUT_ROOT_DIR:-}}"
BURC_TEMP_ROOT_DIR="${BURV_TEMP_ROOT_DIR:-${BURC_TEMP_ROOT_DIR:-}}"
BURC_LOOSEBOX_ROOT_DIR="${BURV_LOOSEBOX_ROOT_DIR:-${BURC_LOOSEBOX_ROOT_DIR:-}}"

# Source BUK modules
BURD_STATION_FILE="${ZBUL_PROJECT_ROOT}/${BURC_STATION_FILE:-}"
source "${BURC_TOOLS_DIR}/buk/buc_command.sh" || exit 1 # buc_die_now not available yet

# The band's range, its gate codes and the verdict codes, from the substrate's
# generated constants, sourced at this process's entry. The sourced file carries
# its own inclusion guard, so a sibling sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"

# The yelp module, ahead of every regime check: a refusal speaks through it, so
# a regime refused before it was sourced would die naming a missing function
# rather than the regime's own words.
source "${BURC_TOOLS_DIR}/buk/buym_yelp.sh" || buc_die_now "Failed to source buym_yelp.sh"

source "${BURC_TOOLS_DIR}/buk/buv_validation.sh" || buc_die_now "Failed to source buv_validation.sh"
source "${BURC_TOOLS_DIR}/buk/bubc_constants.sh" || buc_die_now "Failed to source bubc_constants.sh"
zbuv_kindle

# THE LAUNCHER'S ENTRY, ahead of every kindle: a name of the kit standing
# exported here is refused save the hand-offs this level declares, the override
# family a harness composes for this one child among them. The inherited
# pointer and kit directory were withdrawn above, which is how this launch
# replaces them with its own run's.
buv_export_sentinel "${1##*/}" "BURV_"

# Load and kindle BURC
source "${BURC_TOOLS_DIR}/buk/burc_regime.sh" || buc_die_now "Failed to source burc_regime.sh"
zburc_kindle
zburc_enforce

# The SETUP NEEDED display for a missing station file: prints the guidance and
# exits, since nothing past it can run without the file.
# Usage: zbul_setup_needed <station-file-path>
zbul_setup_needed() {
  local -r z_station_path="${1:-}"
  test -n "${z_station_path}" || buc_die_now "zbul_setup_needed: path required"
  buym_ui_yawp "${z_station_path}"; local -r z_path_yp="${z_buym_yelp}"
  buym_ui_yawp "${BURC_STATION_FILE}"; local -r z_rel_yp="${z_buym_yelp}"
  buym_ui_yawp "${BURD_REGIME_FILE}"; local -r z_burc_yp="${z_buym_yelp}"

  buh_e
  buh_section "SETUP NEEDED: Station Regime file not found"
  buh_e
  buh_line    "  Missing: ${z_path_yp}"
  buh_e
  buh_line    "  The Bash Utility Kit (BUK) script bul_launcher.sh uses two regime files:"
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
  local z_i=""
  for z_i in "${!ZBURS_TEMPLATE_NAMES[@]}"; do
    zbul_template_line "${ZBURS_TEMPLATE_NAMES[${z_i}]}" "${ZBURS_TEMPLATE_VALUES[${z_i}]}"
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
}

# One template line of the station file's recommended content.
# Usage: zbul_template_line <name> <value>
zbul_template_line() {
  local -r z_template_name="${1:-}"
  local -r z_template_value="${2:-}"
  test -n "${z_template_name}" || buc_die_now "zbul_template_line: name required"
  buym_cmd_yawp "${z_template_name}=${z_template_value}"; local -r z_cmd_yp="${z_buym_yelp}"
  buh_line    "    ${z_cmd_yp}"
}

# BURS station load is skipped under the no-log word. No-log tabtargets (e.g.
# handbooks) need only BURC and must run on a fresh clone before any station
# file exists. The word is the tabtarget's own — said on its configuration line,
# never ambient (BUr_q2m). This collapses the former separate nolog launcher.
if test -z "${z_bul_nolog}"; then
  # bud_dispatch is the canonical exporter of BURD_TABTARGET_DIR, but the
  # SETUP NEEDED block below uses buym_tt_yawp which requires it earlier.
  BURD_TABTARGET_DIR="${BURC_TABTARGET_DIR}"

  # Load the handbook so the SETUP NEEDED block can print the paths, tabtarget
  # references and recommended file contents it yawps, via buh_*.
  source "${BURC_TOOLS_DIR}/buk/buh_handbook.sh" || buc_die_now "Failed to source buh_handbook.sh"

  # Shared with tt/buw-SI.StationInit.sh — single home for the field template
  source "${BURC_TOOLS_DIR}/buk/burs_template.sh" || buc_die_now "Failed to source burs_template.sh"

  # Load BURS configuration and kindle
  z_station_file="${ZBUL_PROJECT_ROOT}/${BURC_STATION_FILE}"
  if ! test -f "${z_station_file}"; then
    zbul_setup_needed "${z_station_file}"
  fi
  source "${z_station_file}" || buc_die_now "Failed to source: ${z_station_file}"

  # No BURV override is folded in here: enforce judges the station file as the
  # station states it. The values do not cross the exec below, and the dispatch
  # re-reads the file and folds each override over it for the composed child.

  source "${BURC_TOOLS_DIR}/buk/burs_regime.sh" || buc_die_now "Failed to source burs_regime.sh"
  zburs_kindle
  zburs_enforce
fi

# The dispatch takes the coordinator, the configuration, the seat and the
# moorings directory as its leading arguments, then the tabtarget basename and
# the user's arguments: the hand-off crosses by argument, never by export. The
# coordinator is the workbench path the stub handed first.
exec "${BURC_TOOLS_DIR}/buk/bud_dispatch.sh" "${z_bul_coordinator}" "${ZBUL_CONFIGURATION}" "${ZBUL_SEAT}" "${BURD_CONFIG_DIR}" "${1##*/}" "${@:2}" || buc_die_now "exec failed"
