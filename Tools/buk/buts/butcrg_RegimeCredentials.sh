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
# BUTCRG - Regime credential test cases
#
# Tests external regime files that require credential files on the
# developer workstation. These are NOT CI-safe — they require a fully
# configured workstation with credential files present.

set -euo pipefail

######################################################################
# RBRA credential cases (requires RBRR with RBRA file paths)

butcrg_rbra_tcase() {
  source "${RBCC_rbrr_file}" || buc_die "Failed to source ${RBCC_rbrr_file}"
  zrbrr_kindle
  zrbrr_enforce
  zrbdc_kindle

  local z_roles=("governor" "retriever" "director")
  local z_vars=("RBDC_GOVERNOR_RBRA_FILE" "RBDC_RETRIEVER_RBRA_FILE" "RBDC_DIRECTOR_RBRA_FILE")

  local z_i
  for z_i in "${!z_roles[@]}"; do
    local z_role="${z_roles[$z_i]}"
    local z_var="${z_vars[$z_i]}"
    local z_path="${!z_var:-}"

    test -n "${z_path}" || buto_fatal "RBRR variable ${z_var} is empty"
    test -f "${z_path}" || buto_fatal "RBRA credential file not found for ${z_role}: ${z_path}. This suite requires a fully configured workstation."

    buto_tt_expect_ok "rbw-rav" "${z_role}"
    buto_tt_expect_ok "rbw-rar" "${z_role}"
  done

  buto_success "RBRA credential render+validate passed (all roles)"
}

######################################################################
# RBRO OAuth credential case

butcrg_rbro_tcase() {
  source "${RBCC_rbrr_file}" || buc_die "Failed to source ${RBCC_rbrr_file}"
  zrbrr_kindle
  zrbrr_enforce
  zrbdc_kindle

  local z_file="${RBDC_PAYOR_RBRO_FILE}"
  test -f "${z_file}" || buto_fatal "RBRO credential file not found: ${z_file}. This suite requires a fully configured workstation."

  buto_tt_expect_ok "rbw-rov"
  buto_tt_expect_ok "rbw-ror"

  buto_success "RBRO OAuth regime render+validate passed"
}

######################################################################
# RBRS station credential case

butcrg_rbrs_tcase() {
  local z_file="../station-files/rbrs.env"
  test -f "${z_file}" || buto_fatal "RBRS station file not found: ${z_file}. This suite requires a fully configured workstation."

  buto_tt_expect_ok "rbw-rsv"
  buto_tt_expect_ok "rbw-rsr"

  buto_success "RBRS station regime render+validate passed"
}

# eof
