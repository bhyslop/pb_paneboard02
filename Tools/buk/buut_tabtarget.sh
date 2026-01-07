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
# BUUT - Tabtarget and Launcher creation utilities
#
# Functions for creating tabtargets (tt/*.sh) and launchers (.buk/launcher.*.sh)
# as part of the BUK dispatch system.

set -euo pipefail

# Multiple inclusion detection
test -z "${ZBUUT_SOURCED:-}" || buc_die "Module buut multiply sourced - check sourcing hierarchy"
ZBUUT_SOURCED=1

######################################################################
# Internal Functions (zbuut_*)

zbuut_kindle() {
  test -z "${ZBUUT_KINDLED:-}" || buc_die "Module buut already kindled"

  # Validate BUD environment
  test -n "${BUD_TEMP_DIR:-}" || buc_die "BUD_TEMP_DIR is unset"

  # Validate BURC environment (needed for paths)
  test -n "${BURC_TABTARGET_DIR:-}" || buc_die "BURC_TABTARGET_DIR is unset"
  test -n "${BURC_TOOLS_DIR:-}" || buc_die "BURC_TOOLS_DIR is unset"

  ZBUUT_KINDLED=1
}

zbuut_sentinel() {
  test "${ZBUUT_KINDLED:-}" = "1" || buc_die "Module buut not kindled - call zbuut_kindle first"
}

# Verbose output if BUD_VERBOSE is set
zbuut_show() {
  test "${BUD_VERBOSE:-0}" != "1" || echo "BUUTSHOW: $*"
}

# Write a tabtarget file with specified flags
# Usage: zbuut_write_tabtarget <launcher_path> <tabtarget_file> <flag_lines>
zbuut_write_tabtarget() {
  zbuut_sentinel

  local z_launcher_path="${1:-}"
  local z_tabtarget_file="${2:-}"
  local z_flag_lines="${3:-}"

  test -n "${z_launcher_path}" || buc_die "zbuut_write_tabtarget: launcher_path required"
  test -n "${z_tabtarget_file}" || buc_die "zbuut_write_tabtarget: tabtarget_file required"

  zbuut_show "Writing tabtarget: ${z_tabtarget_file}"

  # Build the tabtarget content
  echo '#!/bin/bash' > "${z_tabtarget_file}"
  echo "export BUD_LAUNCHER=\"${z_launcher_path}\"" >> "${z_tabtarget_file}"

  # Add flag lines if provided
  if test -n "${z_flag_lines}"; then
    echo "${z_flag_lines}" >> "${z_tabtarget_file}"
  fi

  echo 'exec "$(dirname "${BASH_SOURCE[0]}")/../${BUD_LAUNCHER}" "${0##*/}" "${@}"' >> "${z_tabtarget_file}"

  chmod +x "${z_tabtarget_file}" || buc_die "Failed to make tabtarget executable: ${z_tabtarget_file}"
}

# Create tabtargets with specified flags
# Usage: zbuut_create_tabtargets <flag_lines> <launcher_path> <tabtarget_name>...
zbuut_create_tabtargets() {
  zbuut_sentinel

  local z_flag_lines="${1:-}"
  shift || true
  local z_launcher_path="${1:-}"
  shift || true

  test -n "${z_launcher_path}" || buc_die "usage: <launcher-path> <tabtarget-name> [<tabtarget-name>...]\n  Example: .buk/launcher.rbw_workbench.sh rbw-ri.RegimeInfo"
  test "$#" -gt 0 || buc_die "usage: <launcher-path> <tabtarget-name> [<tabtarget-name>...]\n  At least one tabtarget name required"

  # Validate launcher exists
  local z_launcher_file="${PWD}/${z_launcher_path}"
  test -f "${z_launcher_file}" || buc_die "launcher not found: ${z_launcher_file}"

  # Process each tabtarget name
  local z_tabtarget_name
  for z_tabtarget_name in "$@"; do
    local z_tabtarget_file="${PWD}/${BURC_TABTARGET_DIR}/${z_tabtarget_name}.sh"

    # Warn if overwriting
    test ! -f "${z_tabtarget_file}" || buc_warn "overwriting existing tabtarget: ${z_tabtarget_file}"

    zbuut_write_tabtarget "${z_launcher_path}" "${z_tabtarget_file}" "${z_flag_lines}"
    buc_success "Created tabtarget: ${z_tabtarget_file}"
  done
}

######################################################################
# External Functions (buut_*)

# List launchers in .buk/ directory
# Note: Does not require kindling - uses fixed path pattern
buut_list_launchers() {
  zbuut_show "Listing launchers in .buk/"
  buc_step "Launchers in ${PWD}/.buk/"
  ls -1 "${PWD}/.buk/launcher."*.sh 2>/dev/null || echo "  (none found)"
}

# Create batch+logging tabtargets (default)
# Usage: buut_tabtarget_batch_logging <launcher_path> <tabtarget_name>...
buut_tabtarget_batch_logging() {
  zbuut_sentinel

  buc_step "Creating batch+logging tabtarget(s)"
  zbuut_create_tabtargets "" "$@"
}

# Create batch+nolog tabtargets (BUD_NO_LOG=1)
# Usage: buut_tabtarget_batch_nolog <launcher_path> <tabtarget_name>...
buut_tabtarget_batch_nolog() {
  zbuut_sentinel

  buc_step "Creating batch+nolog tabtarget(s)"
  zbuut_create_tabtargets 'export BUD_NO_LOG=1' "$@"
}

# Create interactive+logging tabtargets (BUD_INTERACTIVE=1)
# Usage: buut_tabtarget_interactive_logging <launcher_path> <tabtarget_name>...
buut_tabtarget_interactive_logging() {
  zbuut_sentinel

  buc_step "Creating interactive+logging tabtarget(s)"
  zbuut_create_tabtargets 'export BUD_INTERACTIVE=1' "$@"
}

# Create interactive+nolog tabtargets (both flags)
# Usage: buut_tabtarget_interactive_nolog <launcher_path> <tabtarget_name>...
buut_tabtarget_interactive_nolog() {
  zbuut_sentinel

  buc_step "Creating interactive+nolog tabtarget(s)"
  local z_flags='export BUD_NO_LOG=1
export BUD_INTERACTIVE=1'
  zbuut_create_tabtargets "${z_flags}" "$@"
}

# Create a launcher
# Usage: buut_launcher <workbench_path> <launcher_name>
buut_launcher() {
  zbuut_sentinel

  local z_workbench_path="${1:-}"
  local z_launcher_name="${2:-}"

  test -n "${z_workbench_path}" || buc_die "usage: buut_launcher <workbench-path> <launcher-name>\n  Example: buut_launcher Tools/myw/myw_workbench.sh myw_workbench"
  test -n "${z_launcher_name}" || buc_die "usage: buut_launcher <workbench-path> <launcher-name>\n  launcher-name required"

  # Validate workbench exists
  local z_workbench_file="${PWD}/${z_workbench_path}"
  test -f "${z_workbench_file}" || buc_die "workbench not found: ${z_workbench_file}"

  # Validate .buk directory exists
  local z_buk_dir="${PWD}/.buk"
  test -d "${z_buk_dir}" || buc_die ".buk directory not found: ${z_buk_dir}"

  local z_launcher_file="${z_buk_dir}/launcher.${z_launcher_name}.sh"

  # Warn if overwriting
  test ! -f "${z_launcher_file}" || buc_warn "overwriting existing launcher: ${z_launcher_file}"

  buc_step "Creating launcher: ${z_launcher_file}"
  zbuut_show "Workbench path: ${z_workbench_path}"

  # Extract comment description from launcher name (strip common suffixes)
  local z_description="${z_launcher_name}"
  z_description="${z_description%_workbench}"
  z_description="${z_description%_testbench}"
  z_description="${z_description%_Coordinator}"

  # Write the 4-line launcher stub
  echo '#!/bin/bash' > "${z_launcher_file}"
  echo "# Launcher stub - delegates to ${z_description} workbench" >> "${z_launcher_file}"
  echo 'source "${BASH_SOURCE[0]%/*}/launcher_common.sh"' >> "${z_launcher_file}"
  echo "bud_launch \"\${BURC_TOOLS_DIR}/${z_workbench_path#Tools/}\" \"\$@\"" >> "${z_launcher_file}"

  chmod +x "${z_launcher_file}" || buc_die "Failed to make launcher executable: ${z_launcher_file}"
  buc_success "Created launcher: ${z_launcher_file}"
}

# eof
