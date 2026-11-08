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
# BUUT - Tabtarget and Launcher creation utilities
#
# Functions for creating tabtargets (tt/*.sh) and launchers (rbmm_moorings/buml_launchers/launcher.*.sh)
# as part of the BUK dispatch system.

set -euo pipefail

# Multiple inclusion detection
test -z "${ZBUUT_SOURCED:-}" || buc_die_now "Module buut multiply sourced - check sourcing hierarchy"
ZBUUT_SOURCED=1

######################################################################
# Internal Functions (zbuut_*)

zbuut_kindle() {
  test -z "${ZBUUT_KINDLED:-}" || buc_die_now "Module buut already kindled"

  # Validate BURD environment
  zburd_sentinel

  # Validate BURC environment (needed for paths)
  test -n "${BURC_TABTARGET_DIR:-}" || buc_die_now "BURC_TABTARGET_DIR is unset"
  test -n "${BURC_TOOLS_DIR:-}" || buc_die_now "BURC_TOOLS_DIR is unset"

  readonly ZBUUT_KINDLED=1
}

zbuut_sentinel() {
  test "${ZBUUT_KINDLED:-}" = "1" || buc_die_now "Module buut not kindled - call zbuut_kindle first"
}

# Verbose output if BURE_VERBOSE is set
zbuut_show() {
  zbuut_sentinel
  test "${BURE_VERBOSE:-0}" != "1" || echo "BUUTSHOW: $*"
}

# Write a tabtarget file with the configuration words given
# Usage: zbuut_write_tabtarget <launcher_path> <tabtarget_file> <words>
zbuut_write_tabtarget() {
  zbuut_sentinel

  local -r z_launcher_path="${1:-}"
  local -r z_tabtarget_file="${2:-}"
  local -r z_words="${3:-}"

  test -n "${z_launcher_path}" || buc_die_now "zbuut_write_tabtarget: launcher_path required"
  test -n "${z_tabtarget_file}" || buc_die_now "zbuut_write_tabtarget: tabtarget_file required"

  zbuut_show "Writing tabtarget: ${z_tabtarget_file}"

  # Build the tabtarget content. The configuration line names the launcher as
  # a bare basename (launcher.<id>_workbench.sh), then the buuc_ words, as one
  # argument the trampoline receives after the tabtarget basename; z-launcher.sh
  # resolves the first word directly under the moorings launcher dir. The
  # tabtarget exports nothing, and its exec line carries no launcher token and
  # is byte-identical in every tabtarget.
  local z_configuration="${z_launcher_path##*/}"
  test -z "${z_words}" || z_configuration="${z_configuration} ${z_words}"
  echo '#!/bin/bash' > "${z_tabtarget_file}" || buc_die_now
  echo "set -- '${z_configuration}' \"\$@\"" >> "${z_tabtarget_file}" || buc_die_now
  echo "exec \"\${BASH_SOURCE[0]%/*}/z-launcher.sh\" \"\${0##*/}\" \"\${@}\"" >> "${z_tabtarget_file}" || buc_die_now

  chmod +x "${z_tabtarget_file}" || buc_die_now "Failed to make tabtarget executable: ${z_tabtarget_file}"
}

# Create tabtargets with the configuration words given
# Usage: zbuut_create_tabtargets <words> <launcher_path> <tabtarget_name>...
zbuut_create_tabtargets() {
  zbuut_sentinel

  local -r z_words="${1:-}"
  test "$#" -eq 0 || shift
  local z_launcher_path="${1:-}"
  test "$#" -eq 0 || shift

  test -n "${z_launcher_path}" || buc_die_now "launcher_path required"
  test "$#" -gt 0 || buc_die_now "at least one tabtarget_name required"

  # Validate launcher exists
  local z_launcher_file="${PWD}/${z_launcher_path}"
  test -f "${z_launcher_file}" || buc_die_now "stub not found: ${z_launcher_file}"

  # Process each tabtarget name
  local z_tabtarget_name
  for z_tabtarget_name in "$@"; do
    local z_tabtarget_file="${PWD}/${BURC_TABTARGET_DIR}/${z_tabtarget_name}.sh"

    # Warn if overwriting
    # Non-fatal by grant: repo owner determines warning safe here
    test ! -f "${z_tabtarget_file}" || buc_warn "overwriting existing tabtarget: ${z_tabtarget_file}"

    zbuut_write_tabtarget "${z_launcher_path}" "${z_tabtarget_file}" "${z_words}"
    buc_success "Created tabtarget: ${z_tabtarget_file}"
  done
}

######################################################################
# External Functions (buut_*)

# EVERY ARGUMENT-TAKING DOOR BELOW IS ENROLLED param1, so the dispatch takes the
# first argument off the line and hands it over in BUZ_FOLIO rather than in the
# positional parameters. Each such function binds its leading argument from
# BUZ_FOLIO and reads the rest positionally, which is why none of them shifts.
# An absent folio binds empty and dies at the usage check, the same refusal a
# bare invocation has always raised. The internal helpers keep the ordinary
# positional shape: the folio is decoded once, at the door.

# List launchers in the moorings launcher directory
buut_list_launchers() {
  buc_doc_brief "List all ${BUBG_LAUNCHER_PLURAL} in their directory"
  buc_doc_shown || return 0

  zbuut_sentinel
  local z_launcher_dir="${BURD_CONFIG_DIR}/${BUBC_launchers_subdir}"
  zbuut_show "Listing stubs in ${z_launcher_dir}"
  buc_step "Stubs in ${z_launcher_dir}"
  local z_found=0
  local z_launcher
  for z_launcher in "${z_launcher_dir}/launcher."*.sh; do
    test -f "${z_launcher}" || continue
    echo "${z_launcher}" || buc_die_now
    z_found=1
  done
  test "${z_found}" = "1" || echo "  (none found)"
}

# Create batch+logging tabtargets (default)
buut_tabtarget_batch_logging() {
  local z_launcher_path="${BUZ_FOLIO:-}"

  buc_doc_brief "Create batch tabtarget(s) keeping a ${BUBG_STATION_LOG_BASE} (default mode)"
  buc_doc_param "launcher_path" "Path to the ${BUBG_LAUNCHER_BASE} (e.g., rbmm_moorings/buml_launchers/launcher.rbw_workbench.sh)"
  buc_doc_param "tabtarget_name" "One or more tabtarget names (e.g., rbw-ri.RegimeInfo)"
  buc_doc_shown || return 0

  zbuut_sentinel
  test -n "${z_launcher_path}" || buc_usage_die

  buc_step "Creating batch tabtarget(s) keeping a ${BUBG_STATION_LOG_BASE}"
  zbuut_create_tabtargets "" "${z_launcher_path}" "$@"
}

# Create batch+nolog tabtargets (buuc_nolog)
buut_tabtarget_batch_nolog() {
  local z_launcher_path="${BUZ_FOLIO:-}"

  buc_doc_brief "Create batch+nolog tabtarget(s) (buuc_nolog)"
  buc_doc_param "launcher_path" "Path to the ${BUBG_LAUNCHER_BASE} (e.g., rbmm_moorings/buml_launchers/launcher.rbw_workbench.sh)"
  buc_doc_param "tabtarget_name" "One or more tabtarget names (e.g., rbw-ri.RegimeInfo)"
  buc_doc_shown || return 0

  zbuut_sentinel
  test -n "${z_launcher_path}" || buc_usage_die

  buc_step "Creating batch+nolog tabtarget(s)"
  zbuut_create_tabtargets "${BUBC_word_nolog}" "${z_launcher_path}" "$@"
}

# Create batch+own-log tabtargets (buuc_ownlog)
#
# For a door whose command writes its own record: under this word the dispatch
# composes the three log names and creates no file. The word follows the
# launcher on the configuration line, as every form's does, which is the shape
# the structural qualification in buq_qualify.sh holds every tabtarget to.
buut_tabtarget_batch_amanuensis() {
  local z_launcher_path="${BUZ_FOLIO:-}"

  buc_doc_brief "Create batch tabtarget(s) whose command writes its own record (buuc_ownlog)"
  buc_doc_param "launcher_path" "Path to the ${BUBG_LAUNCHER_BASE} (e.g., rbmm_moorings/buml_launchers/launcher.buw_workbench.sh)"
  buc_doc_param "tabtarget_name" "One or more tabtarget names (e.g., buw-rcv.ValidateConfigRegime)"
  buc_doc_shown || return 0

  zbuut_sentinel
  test -n "${z_launcher_path}" || buc_usage_die

  buc_step "Creating batch tabtarget(s) whose command writes its own record"
  zbuut_create_tabtargets "${BUBC_word_ownlog}" "${z_launcher_path}" "$@"
}

# Create interactive+logging tabtargets (buuc_interactive)
buut_tabtarget_interactive_logging() {
  local z_launcher_path="${BUZ_FOLIO:-}"

  buc_doc_brief "Create interactive tabtarget(s) keeping a ${BUBG_STATION_LOG_BASE} (buuc_interactive)"
  buc_doc_param "launcher_path" "Path to the ${BUBG_LAUNCHER_BASE} (e.g., rbmm_moorings/buml_launchers/launcher.cccw_workbench.sh)"
  buc_doc_param "tabtarget_name" "One or more tabtarget names (e.g., ccck-s.ConnectShell)"
  buc_doc_shown || return 0

  zbuut_sentinel
  test -n "${z_launcher_path}" || buc_usage_die

  buc_step "Creating interactive tabtarget(s) keeping a ${BUBG_STATION_LOG_BASE}"
  zbuut_create_tabtargets "${BUBC_word_interactive}" "${z_launcher_path}" "$@"
}

# Create interactive+nolog tabtargets (both words)
buut_tabtarget_interactive_nolog() {
  local z_launcher_path="${BUZ_FOLIO:-}"

  buc_doc_brief "Create interactive+nolog tabtarget(s) (buuc_interactive buuc_nolog)"
  buc_doc_param "launcher_path" "Path to the ${BUBG_LAUNCHER_BASE} (e.g., rbmm_moorings/buml_launchers/launcher.rbw_workbench.sh)"
  buc_doc_param "tabtarget_name" "One or more tabtarget names (e.g., rbw-PI.PayorInstall)"
  buc_doc_shown || return 0

  zbuut_sentinel
  test -n "${z_launcher_path}" || buc_usage_die

  buc_step "Creating interactive+nolog tabtarget(s)"
  zbuut_create_tabtargets "${BUBC_word_interactive} ${BUBC_word_nolog}" "${z_launcher_path}" "$@"
}

# Create a launcher
buut_launcher() {
  local z_workbench_path="${BUZ_FOLIO:-}"
  local z_launcher_name="${1:-}"

  buc_doc_brief "Create a ${BUBG_LAUNCHER_BASE} stub in rbmm_moorings/buml_launchers/"
  buc_doc_param "workbench_path" "Path to workbench script (e.g., Tools/myw/myw_workbench.sh)"
  buc_doc_param "launcher_name" "${BUBG_LAUNCHER_BASE_LETTRINE} name without prefix/suffix (e.g., myw_workbench)"
  buc_doc_shown || return 0

  zbuut_sentinel
  test -n "${z_workbench_path}" || buc_usage_die
  test -n "${z_launcher_name}" || buc_usage_die

  # Validate workbench exists
  local z_workbench_file="${PWD}/${z_workbench_path}"
  test -f "${z_workbench_file}" || buc_die_now "workbench not found: ${z_workbench_file}"

  # Validate moorings launcher directory exists
  local z_launcher_dir="${BURD_CONFIG_DIR}/${BUBC_launchers_subdir}"
  test -d "${z_launcher_dir}" || buc_die_now "stub directory not found: ${z_launcher_dir}"

  local z_launcher_file="${z_launcher_dir}/launcher.${z_launcher_name}.sh"

  # Warn if overwriting
  # Non-fatal by grant: repo owner determines warning safe here
  test ! -f "${z_launcher_file}" || buc_warn "overwriting existing stub: ${z_launcher_file}"

  buc_step "Creating stub: ${z_launcher_file}"
  zbuut_show "Workbench path: ${z_workbench_path}"

  # Write the two-line launcher stub: a shebang and one exec of the shared
  # launcher, the workbench path ahead of the arguments the trampoline handed.
  # z-launcher.sh chdirs to repo root before exec'ing the stub, so both paths
  # are repo-root-relative — no directory-depth counting, immune to where the
  # launcher dir sits.
  {
    echo '#!/bin/bash' || buc_die_now
    echo "exec \"Tools/buk/bul_launcher.sh\" \"${z_workbench_path}\" \"\$@\"" || buc_die_now
  } > "${z_launcher_file}"

  chmod +x "${z_launcher_file}" || buc_die_now "Failed to make stub executable: ${z_launcher_file}"
  buc_success "Created stub: ${z_launcher_file}"
}

# eof
