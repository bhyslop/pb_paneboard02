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
# BURC CLI - Command line interface for BURC regime operations

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh" || exit 1
source "${BURD_BUK_DIR}/buym_yelp.sh" || buc_die_now "Failed to source buym_yelp.sh"

######################################################################
# Command Functions

burc_validate() {
  buc_doc_brief "Validate BURC configuration regime via enrollment report"
  buc_doc_shown || return 0

  buc_step "Validating BURC configuration regime: ${BURD_REGIME_FILE}"
  buv_report BURC "Configuration Regime"
  buc_step "BURC configuration valid"
}

burc_render() {
  buc_doc_brief "Display diagnostic view of BURC configuration regime"
  buc_doc_shown || return 0

  buv_render BURC "BURC - Bash Utility Configuration Regime" "${BURD_REGIME_FILE}"
}

######################################################################
# Furnish and Main

zburc_furnish() {
  buc_doc_env_row "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/bupr_regime.sh" || buc_die_now "Failed to source bupr_regime.sh"
  zburd_enforce

  zburc_enforce

  zbupr_kindle
}

buc_execute burc_ "Bash Utility Configuration Regime" zburc_furnish "$@"

# eof
