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
# BURN CLI - Command line interface for BURN node regime operations
#
#   burn_validate/render/list  — regime read operations
#       validate/render require BUZ_FOLIO (the investiture)
#       list enumerates the project-global node subtree

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"

######################################################################
# Command Functions — Regime Operations

burn_validate() {
  buc_doc_brief "Validate BURN node regime profile via enrollment report"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burn_die_no_folio
  buc_step "Validating BURN node regime"
  buv_report BURN "Node Regime"
  buc_step "BURN node regime valid"
}

burn_render() {
  buc_doc_brief "Display diagnostic view of BURN node regime profile"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burn_die_no_folio
  local z_profile_file="${BURD_CONFIG_DIR}/${BUBC_rbmn_nodes_subdir}/${BUZ_FOLIO}/burn.env"
  buv_render BURN "BURN - Bash Utility Node Regime" "${z_profile_file}"
}

burn_list() {
  buc_doc_brief "List available BURN node investitures"
  buc_doc_shown || return 0

  local z_aliases
  z_aliases=$(burn_list_capture) || buc_die "No BURN profiles under ${BUBC_moorings_dir}/${BUBC_rbmn_nodes_subdir}/"
  buc_step "Available investitures:"
  local z_alias=""
  for z_alias in ${z_aliases}; do
    buc_bare "        ${z_alias}"
  done
}

######################################################################
# Furnish and Main

zburn_furnish() {
  buc_doc_env "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env "BURD_CONFIG_DIR       " "BUK config directory (dispatch-provided)"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/buv_validation.sh"
  source "${BURD_BUK_DIR}/burd_regime.sh"
  source "${BURD_BUK_DIR}/burc_regime.sh"
  source "${BURD_BUK_DIR}/burs_regime.sh"
  source "${BURD_BUK_DIR}/buf_fact.sh"
  source "${BURD_BUK_DIR}/bubc_constants.sh"
  source "${BURD_BUK_DIR}/burn_regime.sh"
  source "${BURD_BUK_DIR}/bupr_PresentationRegime.sh"
  source "${BURD_BUK_DIR}/buym_yelp.sh"
  source "${BURD_BUK_DIR}/buh_handbook.sh"

  zbuv_kindle
  zburd_kindle
  zburd_enforce

  source "${BURD_REGIME_FILE}" || buc_die "Failed to source BURC: ${BURD_REGIME_FILE}"

  zburc_kindle
  zburc_enforce

  source "${BURD_STATION_FILE}" || buc_die "Failed to source BURS: ${BURD_STATION_FILE}"

  zburs_kindle
  zburs_enforce

  zbupr_kindle

  # If BUZ_FOLIO is set, load and kindle the specified profile
  if test -n "${BUZ_FOLIO:-}"; then
    local -r z_profile_file="${BURD_CONFIG_DIR}/${BUBC_rbmn_nodes_subdir}/${BUZ_FOLIO}/burn.env"
    test -f "${z_profile_file}" || buc_die "BURN profile not found: ${z_profile_file}"
    source "${z_profile_file}" || buc_die "Failed to source BURN: ${z_profile_file}"
    zburn_kindle
    zburn_enforce
  fi
}

buc_execute burn_ "Bash Utility Node Regime" zburn_furnish "$@"

# eof
