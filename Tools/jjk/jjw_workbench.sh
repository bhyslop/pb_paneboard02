#!/bin/bash
#
# Copyright 2025 Scale Invariant, Inc.
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
# JJW Workbench - Routes Job Jockey commands

set -euo pipefail

# Get script directory
JJW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${JJW_SCRIPT_DIR}/../buk/buc_command.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Verbose output if BUD_VERBOSE is set
jjw_show() {
  test "${BUD_VERBOSE:-0}" != "1" || echo "JJWSHOW: $*"
}

# Simple routing function
jjw_route() {
  local z_command="$1"
  shift
  local z_args="$*"

  jjw_show "Routing command: ${z_command} with args: ${z_args}"

  # Verify BDU environment variables are present
  test -n "${BUD_TEMP_DIR:-}" || buc_die "BUD_TEMP_DIR not set - must be called from BUD"
  test -n "${BUD_NOW_STAMP:-}" || buc_die "BUD_NOW_STAMP not set - must be called from BUD"

  jjw_show "BDU environment verified"

  local z_cli="${JJW_SCRIPT_DIR}/jju_cli.sh"

  # Route based on command
  case "${z_command}" in

    # Arcanum commands (install/check/uninstall)
    jja-c|jja-i|jja-u)
      jjw_show "Delegating to arcanum: ${z_command}"
      exec "${JJW_SCRIPT_DIR}/jja_arcanum.sh" "${z_command}" "$@"
      ;;

    # Heat saddle (smart argument handling)
    jjw-hs)
      local z_favor="${1:-}"

      if test -z "${z_favor}"; then
        # No argument - check heat count and decide
        local z_heat_count_file="${BUD_TEMP_DIR}/hs_heat_count.txt"
        local z_scalar_file="${BUD_TEMP_DIR}/hs_scalar.txt"
        "${z_cli}" jju_muster > "${z_heat_count_file}"

        # Count heats (lines starting with ₣) - BCG: temp file for grep
        local z_count
        grep -c '^₣' "${z_heat_count_file}" > "${z_scalar_file}" || echo "0" > "${z_scalar_file}"
        read -r z_count < "${z_scalar_file}"

        if test "${z_count}" -eq 0; then
          cat "${z_heat_count_file}"
          exit 0
        elif test "${z_count}" -eq 1; then
          # Auto-saddle the single heat - BCG: temp file for extraction
          grep '^₣' "${z_heat_count_file}" > "${z_scalar_file}"
          read -r z_favor _ < "${z_scalar_file}"
          # Append AAA for heat-only reference
          z_favor="${z_favor}AAA"
          exec "${z_cli}" jju_saddle "${z_favor}"
        else
          # Multiple heats - show list and require explicit selection
          cat "${z_heat_count_file}"
          echo ""
          echo "Multiple heats found. Please specify which heat to saddle:"
          echo "  tt/jjw-hs.HeatSaddle.sh <favor>"
          exit 1
        fi
      else
        # Favor provided - saddle it
        exec "${z_cli}" jju_saddle "${z_favor}"
      fi
      ;;

    # Favor encoding/decoding
    jjw-fe) exec "${z_cli}" jju_favor_encode "$@" ;;
    jjw-fd) exec "${z_cli}" jju_favor_decode "$@" ;;

    # Studbook operations
    jjw-m)  exec "${z_cli}" jju_muster "$@" ;;
    jjw-n)  exec "${z_cli}" jju_nominate "$@" ;;
    jjw-sl) exec "${z_cli}" jju_slate "$@" ;;
    jjw-rs) exec "${z_cli}" jju_reslate "$@" ;;
    jjw-ra) exec "${z_cli}" jju_rail "$@" ;;
    jjw-t)  exec "${z_cli}" jju_tally "$@" ;;
    jjw-pw) exec "${z_cli}" jju_wrap "$@" ;;
    jjw-re) exec "${z_cli}" jju_retire_extract "$@" ;;
    jjw-hr) exec "${z_cli}" jju_retire "$@" ;;

    # Steeplechase operations
    jjw-c)  exec "${z_cli}" jju_chalk "$@" ;;
    jjw-rn) exec "${z_cli}" jju_rein "$@" ;;
    jjw-no) exec "${z_cli}" jju_notch "$@" ;;

    # Info - show all function docs
    jjw-i) exec "${z_cli}" ;;

    *)
      buc_die "Unknown command: ${z_command}"
      ;;
  esac
}

# Main entry point
jjw_main() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  jjw_route "${z_command}" "$@"
}

jjw_main "$@"

# eof
