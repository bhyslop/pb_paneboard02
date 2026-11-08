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
# BUUR - Roll call: the installed kits' enrollments against the doors standing
#
# A repository holds the subset of a kit's doors it chose to stand, so nothing
# here asks that every enrolled colophon have a door — that sweep is the source
# tree's proof (buz_healthcheck), never a receiver's. What a receiver cannot see
# for itself is the other direction: a kit update that drops or renames a
# colophon leaves the door standing, naming a route its workbench no longer
# knows. The roll call names every such door and exits red where one stands.
# Beside that it lists each enrolled colophon no door stands for, with what it
# does and how it takes its folio, which is the receiver's menu of doors it may
# yet stand through the create doors.
#
# WHAT IS JUDGED. A door is a tabtarget whose configuration line names a
# launcher as its first word and which execs a trampoline beside it; a file doing only one of the two is
# a script of the repository's own and is not read. A door is judged only where
# its launcher's workbench stands in a kit BURC_MANAGED_KITS declares — a door
# over a workbench the repository wrote for itself is its own business. A kit
# whose workbench keeps no zipper enrolls nothing, so a door over it is named.
#
# WHERE THE ROSTER COMES FROM. Every zipper each declared kit carries, found by
# the module contract's name ({prefix}z_zipper.sh, in the kit directory or one
# directory below it) and kindled by the contract's kindle name
# (z{prefix}z_kindle), into the one shared roll. The registry module itself is
# not a zipper and is skipped. Nothing here names a kit.
#
# KITS BEYOND THE DECLARATION. BUUR_ALSO_KITS, where set, names further kits
# (comma-separated, as BURC_MANAGED_KITS is) judged exactly as declared ones.
# The declaration names only the kits a repository receives by parcel, so a
# forge's own kits stand outside it: the forge's source-tree proof fills this
# door with them, and a receiver never needs it. A declaration naming no kit
# and an unset door judge no door at all.

set -euo pipefail

source "${BASH_SOURCE[0]%/*}/buc_command.sh" || exit 1
source "${BASH_SOURCE[0]%/*}/buym_yelp.sh" || buc_die_now "Failed to source buym_yelp.sh"

######################################################################
# Internal helpers (zbuur_*)

# zbuur_kit_declared_predicate() - True when BURC_MANAGED_KITS declares the kit
# Args: kit
zbuur_kit_declared_predicate() {
  local -r z_kit="${1:-}"

  local z_i=""
  for z_i in "${!z_buur_kit_roll[@]}"; do
    test "${z_buur_kit_roll[z_i]}" != "${z_kit}" || return 0
  done
  return 1
}

# zbuur_enrolled_predicate() - True when a kindled zipper enrolls the colophon
# Args: colophon
zbuur_enrolled_predicate() {
  local -r z_colophon="${1:-}"

  local z_i=""
  for z_i in "${!z_buz_colophon_roll[@]}"; do
    test "${z_buz_colophon_roll[z_i]}" != "${z_colophon}" || return 0
  done
  return 1
}

# zbuur_door_launcher_capture() - The launcher a door names, or exit 1
# Args: tabtarget path
# A door's configuration line names a bare launcher basename as its first word,
# and the door execs a sibling trampoline; a file lacking either line is no door.
zbuur_door_launcher_capture() {
  local -r z_file="${1:-}"
  local -r z_launcher_re="^set -- '(launcher\\.[A-Za-z0-9_]+\\.sh)[ ']"
  local -r z_exec_re='^exec "\$\{BASH_SOURCE\[0\]%/\*\}/z-[A-Za-z0-9_]+\.sh"'

  local z_lines=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_lines+=("${z_line}")
  done < "${z_file}" || return 1

  local z_launcher=""
  local z_execs=0
  local z_i=""
  for z_i in "${!z_lines[@]}"; do
    if [[ "${z_lines[z_i]}" =~ ${z_launcher_re} ]]; then
      z_launcher="${BASH_REMATCH[1]}"
    fi
    if [[ "${z_lines[z_i]}" =~ ${z_exec_re} ]]; then
      z_execs=1
    fi
  done

  test -n "${z_launcher}" || return 1
  test "${z_execs}" = "1" || return 1
  echo "${z_launcher}"
}

# zbuur_launcher_kit_capture() - The kit directory a launcher's workbench stands in, or exit 1
# Args: launcher path
# Read off the launcher's exec line, which names the workbench from the
# repository root under the tools directory; the first directory beneath it is
# the kit.
zbuur_launcher_kit_capture() {
  local -r z_file="${1:-}"
  local -r z_launch_re='^exec "Tools/buk/bul_launcher\.sh" "Tools/([^/"]+)/'

  test -f "${z_file}" || return 1

  local z_lines=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_lines+=("${z_line}")
  done < "${z_file}" || return 1

  local z_kit=""
  local z_i=""
  for z_i in "${!z_lines[@]}"; do
    if [[ "${z_lines[z_i]}" =~ ${z_launch_re} ]]; then
      z_kit="${BASH_REMATCH[1]}"
    fi
  done

  test -n "${z_kit}" || return 1
  echo "${z_kit}"
}

######################################################################
# External Functions (buur_*)

# buur_roll_call() - Hold the installed kits' enrollments against the doors standing
buur_roll_call() {
  buc_doc_brief "Name each door whose colophon no installed kit enrolls (red), and each enrolled colophon no door stands for"
  buc_doc_shown || return 0

  local -r z_tt_dir="${BURC_TABTARGET_DIR}"
  local -r z_delim="${BURC_TABTARGET_DELIMITER}"
  local -r z_launcher_dir="${BURD_CONFIG_DIR}/${BUBC_launchers_subdir}"

  local z_kits_shown="${z_buur_kit_roll[*]:-}"
  buc_step "Roll call: ${#z_buur_zipper_roll[@]} zipper(s) of the kits ${z_kits_shown// /,} against ${z_tt_dir}/"
  local z_z=""
  for z_z in "${!z_buur_zipper_roll[@]}"; do
    buc_bare "  roster: ${z_buur_zipper_roll[z_z]}"
  done

  local z_strangers=()
  local z_unread=()
  local z_judged=0
  local z_door=""
  local z_launcher=""
  local z_kit=""
  local z_colophon=""
  local z_status=0
  for z_door in "${z_tt_dir}/"*.sh; do
    test -f "${z_door}" || continue

    z_status=0
    z_launcher=$(zbuur_door_launcher_capture "${z_door}") || z_status=$?
    test "${z_status}" = "0" || continue

    z_status=0
    z_kit=$(zbuur_launcher_kit_capture "${z_launcher_dir}/${z_launcher}") || z_status=$?
    if test "${z_status}" != "0"; then
      z_unread+=("${z_door} (its stub ${z_launcher} does not stand, or names no workbench under ${BURC_TOOLS_DIR})")
      continue
    fi

    zbuur_kit_declared_predicate "${z_kit}" || continue

    z_judged=$((z_judged + 1))
    z_colophon="${z_door##*/}"
    z_colophon="${z_colophon%%"${z_delim}"*}"
    zbuur_enrolled_predicate "${z_colophon}" \
      || z_strangers+=("${z_door} names ${z_colophon}, which no zipper of kit ${z_kit} enrolls")
  done

  local z_unstood=()
  local z_i=""
  local z_takes=""
  for z_i in "${!z_buz_colophon_roll[@]}"; do
    local z_matches=("${z_tt_dir}/${z_buz_colophon_roll[z_i]}${z_delim}"*.sh)
    test ! -e "${z_matches[0]}" || continue

    # Channel to plain words, as the help-door face says them (buz_emit_roll).
    z_takes="takes nothing"
    case "${z_buz_channel_roll[z_i]}" in
      "param1")          z_takes="takes one argument"           ;;
      "imprint")         z_takes="named in the file"            ;;
      "buz_passthrough") z_takes="takes its arguments as typed" ;;
    esac
    z_unstood+=("${z_buz_colophon_roll[z_i]}  [${z_takes}]  ${z_buz_describe_roll[z_i]}")
  done

  if (( ${#z_unstood[@]} )); then
    buc_step "Enrolled, with no door standing (${#z_unstood[@]}) - stand any you want through the create doors (buw-tt-c*):"
    for z_i in "${!z_unstood[@]}"; do
      buc_bare "  ${z_unstood[z_i]}"
    done
  fi

  if (( ${#z_unread[@]} )); then
    buc_step "Not judged (${#z_unread[@]}):"
    for z_i in "${!z_unread[@]}"; do
      buc_bare "  ${z_unread[z_i]}"
    done
  fi

  if (( ${#z_strangers[@]} )); then
    buc_step "Unenrolled (${#z_strangers[@]}) - a door naming a colophon no installed kit enrolls:"
    for z_i in "${!z_strangers[@]}"; do
      buc_bare "  ${z_strangers[z_i]}"
    done
    buc_die_now "Roll call: ${#z_strangers[@]} door(s) unenrolled - remove each, or restore its colophon's enrollment"
  fi

  buc_success "Roll call: no door unenrolled (${z_judged} judged, ${#z_unstood[@]} enrolled with no door standing)"
}

######################################################################
# Furnish

zbuur_furnish() {
  buc_doc_env_row "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_row "BURD_CONFIG_DIR       " "Moorings directory holding the stub directory (dispatch-provided)"
  buc_doc_env_row "BURD_REGIME_FILE      " "The repository's burc.env (dispatch-provided)"
  buc_doc_env_row "BUUR_ALSO_KITS        " "Optional: further kits judged as if declared (comma-separated)"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/buz_zipper.sh" || buc_die_now "Failed to source buz_zipper.sh"

  z_buur_kit_roll=()
  IFS=',' read -r -a z_buur_kit_roll <<< "${BURC_MANAGED_KITS:-}" \
    || buc_die_now "Failed to read the kit list: ${BURC_MANAGED_KITS}"
  if test -n "${BUUR_ALSO_KITS:-}"; then
    local z_also=()
    IFS=',' read -r -a z_also <<< "${BUUR_ALSO_KITS}" \
      || buc_die_now "Failed to read the further kit list: ${BUUR_ALSO_KITS}"
    if test "${#z_also[@]}" -gt 0; then
      z_buur_kit_roll+=("${z_also[@]}")
    fi
  fi

  zbuz_kindle

  # Every zipper a declared kit carries, into the one shared roll.
  z_buur_zipper_roll=()
  local z_k=""
  local z_zipper=""
  local z_stem=""
  local z_kindle=""
  for z_k in "${!z_buur_kit_roll[@]}"; do
    for z_zipper in "${BURC_TOOLS_DIR}/${z_buur_kit_roll[z_k]}/"*z_zipper.sh \
                    "${BURC_TOOLS_DIR}/${z_buur_kit_roll[z_k]}/"*/*z_zipper.sh; do
      test -f "${z_zipper}" || continue
      z_stem="${z_zipper##*/}"
      z_stem="${z_stem%_zipper.sh}"
      test "${z_stem}" != "buz" || continue

      z_kindle="z${z_stem}_kindle"
      source "${z_zipper}" || buc_die_now "Failed to source zipper: ${z_zipper}"
      # A call through a variable: the name arrives at run time, so the call takes a form the
      # unguarded-command reading admits (VOr_jqp). A known name is called by name.
      declare -F "${z_kindle}" > /dev/null \
        || buc_die_now "Zipper ${z_zipper} defines no ${z_kindle}, the kindle its name promises"
      "${z_kindle}"
      z_buur_zipper_roll+=("${z_zipper}")
    done
  done
}

buc_execute buur_ "Roll Call" zbuur_furnish "$@"

# eof
