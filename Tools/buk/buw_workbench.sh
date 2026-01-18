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
# BUK Workbench - Routes BUK management commands

set -euo pipefail

# Get script directory
BUW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${BUW_SCRIPT_DIR}/buc_command.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Verify launcher provided regime environment
test -n "${BUD_REGIME_FILE:-}"   || buc_die "BUD_REGIME_FILE not set - must be called via launcher"
test -n "${BUD_STATION_FILE:-}"  || buc_die "BUD_STATION_FILE not set - must be called via launcher"

# Verbose output if BUD_VERBOSE is set
buw_show() {
  test "${BUD_VERBOSE:-0}" != "1" || echo "BUWSHOW: $*"
}

# Simple routing function
buw_route() {
  local z_command="$1"
  shift

  buw_show "Routing command: ${z_command} with args: $*"

  # Verify BDU environment variables are present
  test -n "${BUD_TEMP_DIR:-}" || buc_die "BUD_TEMP_DIR not set - must be called from BUD"
  test -n "${BUD_NOW_STAMP:-}" || buc_die "BUD_NOW_STAMP not set - must be called from BUD"

  buw_show "BDU environment verified"

  # Route based on command
  local z_buut_cli="${BUW_SCRIPT_DIR}/buut_cli.sh"
  local z_burc_cli="${BUW_SCRIPT_DIR}/burc_cli.sh"
  local z_burs_cli="${BUW_SCRIPT_DIR}/burs_cli.sh"

  case "${z_command}" in

    # TabTarget subsystem (buw-tt-*)
    buw-tt-ll)  exec "${z_buut_cli}" buut_list_launchers                 "$@" ;;
    buw-tt-cbl) exec "${z_buut_cli}" buut_tabtarget_batch_logging        "$@" ;;
    buw-tt-cbn) exec "${z_buut_cli}" buut_tabtarget_batch_nolog          "$@" ;;
    buw-tt-cil) exec "${z_buut_cli}" buut_tabtarget_interactive_logging  "$@" ;;
    buw-tt-cin) exec "${z_buut_cli}" buut_tabtarget_interactive_nolog    "$@" ;;
    buw-tt-cl)  exec "${z_buut_cli}" buut_launcher                       "$@" ;;

    # Regime subsystem
    buw-rgv-burc) exec "${z_burc_cli}" validate ;;
    buw-rgr-burc) exec "${z_burc_cli}" render ;;
    buw-rgi-burc) exec "${z_burc_cli}" info ;;

    # Regime subsystem
    buw-rgv-burs) exec "${z_burs_cli}" validate ;;
    buw-rgr-burs) exec "${z_burs_cli}" render ;;
    buw-rgi-burs) exec "${z_burs_cli}" info ;;

    # Unknown command
    *)   buc_die "Unknown command: ${z_command}" ;;
  esac
}

buw_main() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  buw_route "${z_command}" "$@"
}

buw_main "$@"

# eof
