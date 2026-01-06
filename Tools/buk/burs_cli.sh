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
# BURS CLI - Command line interface for BURS regime operations

set -euo pipefail

ZBURS_CLI_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${ZBURS_CLI_SCRIPT_DIR}/buc_command.sh"
source "${ZBURS_CLI_SCRIPT_DIR}/burs_regime.sh"

######################################################################
# CLI Functions

zburs_cli_kindle() {
  test -z "${ZBURS_CLI_KINDLED:-}" || buc_die "BURS CLI already kindled"

  ZBURS_SPEC_FILE="${ZBURS_CLI_SCRIPT_DIR}/burs_specification.md"

  ZBURS_CLI_KINDLED=1
}

# Command: validate - source file and validate
burs_validate() {
  local z_file="${1:-}"
  test -n "${z_file}" || buc_die "burs_validate: file argument required"
  test -f "${z_file}" || buc_die "burs_validate: file not found: ${z_file}"

  buc_step "Validating BURS assignment file: ${z_file}"

  # Source the assignment file
  source "${z_file}" || buc_die "burs_validate: failed to source ${z_file}"

  # Validate via kindle
  zburs_kindle

  buc_step "BURS configuration valid"
}

# Command: render - display configuration values
burs_render() {
  local z_file="${1:-}"
  test -n "${z_file}" || buc_die "burs_render: file argument required"
  test -f "${z_file}" || buc_die "burs_render: file not found: ${z_file}"

  buc_step "BURS Configuration: ${z_file}"

  # Source the assignment file
  source "${z_file}" || buc_die "burs_render: failed to source ${z_file}"

  # Render with aligned columns
  printf "%-25s %s\n" "BURS_LOG_DIR" "${BURS_LOG_DIR:-<not set>}"
}

# Command: info - display specification (formatted for terminal)
burs_info() {
  cat <<EOF

${ZBUC_CYAN}========================================${ZBUC_RESET}
${ZBUC_WHITE}BURS - Bash Utility Regime Station${ZBUC_RESET}
${ZBUC_CYAN}========================================${ZBUC_RESET}

${ZBUC_YELLOW}Overview${ZBUC_RESET}
Developer/machine-level configuration for personal preferences.
NOT checked into git - each developer has their own BURS file.

${ZBUC_YELLOW}Variables${ZBUC_RESET}

  ${ZBUC_GREEN}BURS_LOG_DIR${ZBUC_RESET}
    Where this developer stores logs
    Type: string
    Example: ../_logs_buk

${ZBUC_CYAN}For full specification, see: ${ZBURS_SPEC_FILE}${ZBUC_RESET}

EOF
}

######################################################################
# Main dispatch

zburs_cli_kindle

z_command="${1:-}"

case "${z_command}" in
  validate)
    shift
    burs_validate "${@}"
    ;;
  render)
    shift
    burs_render "${@}"
    ;;
  info)
    burs_info
    ;;
  *)
    buc_die "Unknown command: ${z_command}. Usage: burs_cli.sh {validate|render|info} [args]"
    ;;
esac

# eof
