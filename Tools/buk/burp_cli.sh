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
# BURP CLI - Command line interface for BURP privileged regime operations
#
#   burp_validate/render/list  — regime read operations
#       validate/render require BUZ_FOLIO (the investiture)
#       list enumerates the per-station-user investiture subtree

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"

######################################################################
# Command Functions — Regime Operations

burp_validate() {
  buc_doc_brief "Validate BURP privileged regime profile via enrollment report"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  buc_step "Validating BURP privileged regime"
  buv_report BURP "Privileged Regime"
  buc_step "BURP privileged regime valid"
}

burp_render() {
  buc_doc_brief "Display diagnostic view of BURP privileged regime profile"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  local z_profile_file="${BURD_CONFIG_DIR}/${BUBC_rbmu_users_subdir}/${BURS_USER}/${BUZ_FOLIO}/burp.env"
  buv_render BURP "BURP - Bash Utility Privileged Regime" "${z_profile_file}"
}

burp_list() {
  buc_doc_brief "List available BURP investitures for the current station user"
  buc_doc_shown || return 0

  local z_aliases
  z_aliases=$(burp_list_capture) || buc_die "No BURP profiles under ${BURD_MOORINGS_DIR}/${BUBC_rbmu_users_subdir}/${BURS_USER}/"
  buc_step "Available investitures for ${BURS_USER}:"
  local z_alias=""
  for z_alias in ${z_aliases}; do
    buc_bare "        ${z_alias}"
  done
}

######################################################################
# Furnish and Main

zburp_furnish() {
  buc_doc_env "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env "BURD_CONFIG_DIR       " "BUK config directory (dispatch-provided)"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/buv_validation.sh"
  source "${BURD_BUK_DIR}/burd_regime.sh"
  source "${BURD_BUK_DIR}/burc_regime.sh"
  source "${BURD_BUK_DIR}/burs_regime.sh"
  source "${BURD_BUK_DIR}/buf_fact.sh"
  source "${BURD_BUK_DIR}/bubc_constants.sh"
  source "${BURD_BUK_DIR}/burp_regime.sh"
  source "${BURD_BUK_DIR}/bupr_regime.sh"
  source "${BURD_BUK_DIR}/buym_yelp.sh"
  source "${BURD_BUK_DIR}/buh_handbook.sh"
  source "${BURD_BUK_DIR}/buz_zipper.sh"
  source "${BURD_BUK_DIR}/buwz_zipper.sh"

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
  zbuz_kindle
  zbuwz_kindle

  # If BUZ_FOLIO is set, load and kindle the specified investiture profile
  if test -n "${BUZ_FOLIO:-}"; then
    local -r z_profile_file="${BURD_CONFIG_DIR}/${BUBC_rbmu_users_subdir}/${BURS_USER}/${BUZ_FOLIO}/burp.env"
    test -f "${z_profile_file}" || buc_die "BURP profile not found: ${z_profile_file}"
    source "${z_profile_file}" || buc_die "Failed to source BURP: ${z_profile_file}"
    zburp_kindle
    zburp_enforce
  fi
}

buc_execute burp_ "Bash Utility Privileged Regime" zburp_furnish "$@"

# eof
