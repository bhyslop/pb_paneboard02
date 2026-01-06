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

# Verbose output if BUD_VERBOSE is set
buw_show() {
  test "${BUD_VERBOSE:-0}" != "1" || echo "BUWSHOW: $*"
}

# Load BURC configuration
buw_load_burc() {
  local z_burc_file="${PWD}/.buk/burc.env"

  test -f "${z_burc_file}" || buc_die "BURC file not found: ${z_burc_file}"

  buw_show "Loading BURC from: ${z_burc_file}"
  # shellcheck disable=SC1090
  source "${z_burc_file}"
}

# Simple routing function
buw_route() {
  local z_command="$1"
  shift
  local z_args="$*"

  buw_show "Routing command: ${z_command} with args: ${z_args}"

  # Verify BDU environment variables are present
  test -n "${BUD_TEMP_DIR:-}" || buc_die "BUD_TEMP_DIR not set - must be called from BUD"
  test -n "${BUD_NOW_STAMP:-}" || buc_die "BUD_NOW_STAMP not set - must be called from BUD"

  buw_show "BDU environment verified"

  # Load BURC configuration
  buw_load_burc

  # Route based on command
  case "${z_command}" in

    # Launcher management
    buw-ll)
      # List launchers in .buk/
      buw_show "Listing launchers in .buk/"
      buc_step "Launchers in ${PWD}/.buk/"
      ls -1 "${PWD}/.buk/launcher."*.sh 2>/dev/null || echo "  (none found)"
      ;;

    # TabTarget management
    buw-tc)
      # Create tabtarget: buw-tc <workbench-path> <tabtarget-name>
      # Example: buw-tc Tools/buk/buw_workbench.sh buw-ri.RegimeInfo
      local z_workbench_path="${1:-}"
      local z_tabtarget_name="${2:-}"

      test -n "${z_workbench_path}" || buc_die "usage: buw-tc <workbench-path> <tabtarget-name>\n  Example: buw-tc Tools/buk/buw_workbench.sh buw-ri.RegimeInfo"
      test -n "${z_tabtarget_name}" || buc_die "usage: buw-tc <workbench-path> <tabtarget-name>\n  Example: buw-tc Tools/buk/buw_workbench.sh buw-ri.RegimeInfo"

      local z_tabtarget_file="${PWD}/${BURC_TABTARGET_DIR}/${z_tabtarget_name}.sh"
      local z_workbench_file="${PWD}/${z_workbench_path}"

      test ! -f "${z_tabtarget_file}" || buc_die "tabtarget already exists: ${z_tabtarget_file}"

      test -f "${z_workbench_file}" || buc_warn "workbench not found: ${z_workbench_file}\nCreating tabtarget anyway..."

      buw_show "Creating tabtarget: ${z_tabtarget_file}"

      # Extract command from tabtarget name (first token before delimiter)
      local z_command_token
      z_command_token="${z_tabtarget_name%%${BURC_TABTARGET_DELIMITER}*}"

      echo "#!/bin/bash" > "${z_tabtarget_file}"
      echo "# Generated tabtarget - delegates to ${z_workbench_path}" >> "${z_tabtarget_file}"
      echo "exec \"\$(dirname \"\${BASH_SOURCE[0]}\")/../${z_workbench_path}\" \"${z_command_token}\" \"\${@}\"" >> "${z_tabtarget_file}"

      chmod +x "${z_tabtarget_file}" || buc_die "Failed to make tabtarget executable: ${z_tabtarget_file}"
      buc_success "Created tabtarget: ${z_tabtarget_file}"
      echo "  Delegates to: ${z_workbench_file}"
      echo "  Command: ${z_command_token}"
      ;;

    # Regime management (consolidated)
    buw-rv)
      # Validate both regimes
      buc_step "Validating BURC"
      "${BUW_SCRIPT_DIR}/burc_regime.sh" validate "${PWD}/.buk/burc.env" || buc_die "BURC validation failed"

      buc_step "Validating BURS"
      local z_station_file="${PWD}/${BURC_STATION_FILE}"
      "${BUW_SCRIPT_DIR}/burs_regime.sh" validate "${z_station_file}" || buc_die "BURS validation failed"

      buc_success "All regime validations passed"
      ;;

    buw-rr)
      # Render both regimes
      buc_step "BURC Configuration"
      "${BUW_SCRIPT_DIR}/burc_regime.sh" render "${PWD}/.buk/burc.env" || buc_die "BURC render failed"

      buc_step "BURS Configuration"
      local z_station_file="${PWD}/${BURC_STATION_FILE}"
      "${BUW_SCRIPT_DIR}/burs_regime.sh" render "${z_station_file}" || buc_die "BURS render failed"
      ;;

    buw-ri)
      # Show info for both regimes
      buc_step "BURC Specification"
      "${BUW_SCRIPT_DIR}/burc_regime.sh" info || buc_die "BURC info failed"

      buc_step "BURS Specification"
      "${BUW_SCRIPT_DIR}/burs_regime.sh" info || buc_die "BURS info failed"
      ;;

    # Unknown command
    *)
      buc_die "Unknown command: ${z_command}\nAvailable commands:\n  Launcher:  buw-ll\n  TabTarget: buw-tc <workbench-path> <tabtarget-name>\n  Regime:    buw-rv, buw-rr, buw-ri"
      ;;
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
