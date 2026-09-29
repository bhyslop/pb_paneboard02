#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
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
# JJFP CLI - Command line interface for fundus operations

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"
source "${BURD_BUK_DIR}/buym_yelp.sh"

######################################################################
# Furnish and Main

zjjfp_furnish() {
  buc_doc_env_row "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_row "BURD_TOOLS_DIR        " "Project tools root directory (dispatch-provided)"
  buc_doc_env_row "BURD_TABTARGET_DIR    " "Tabtarget directory, where the kennel's whistle resolves by colophon (dispatch-provided)"
  buc_doc_env_row "BURD_TEMP_DIR         " "Dispatch temp directory (dispatch-provided)"
  buc_doc_env_row "BURD_TACKROOM         " "The station's shared toolchain and registry store (dispatch-provided)"
  buc_doc_env_row "BUZ_FOLIO             " "Target host (from zipper imprint channel)"
  buc_doc_env_done || return 0

  local -r z_jjk_dir="${BURD_TOOLS_DIR}/jjk"

  source "${BURD_BUK_DIR}/buv_validation.sh"
  source "${BURD_BUK_DIR}/burd_regime.sh"
  # The kennel's shared readings, reached through this furnish because the gateway
  # admits another CLI's furnish and nothing further in. The scenario doors DRIVE
  # the kennel rather than building it, so what they take from the kit is the door
  # law and the currency question - never a kennel door.
  source "${BURD_TOOLS_DIR}/bkk/bk0/bkcp_position.sh"
  # The fence VOK already states, stood on rather than rebuilt. The compiled leash
  # INHERITS the homes redirect this exports and refuses where it did not hold, so
  # a scenario run never resolves the pinned channel or the crate registry from
  # the station user's own homes.
  source "${BURD_TOOLS_DIR}/vok/vot_toolchain.sh"

  source "${z_jjk_dir}/jjfp_fundus.sh"

  zbuv_kindle
  zburd_kindle

  # BURC_TOOLS_DIR is the fence's own coordinate, and the scenario doors are the
  # first in this CLI to need one. BURD_REGIME_FILE is the dispatch-resolved
  # burc.env path.
  local z_burc_file="${BURD_REGIME_FILE}"
  buv_file_exists "${z_burc_file}"
  source "${z_burc_file}" || buc_die_now "Failed to source BURC file"

  zvot_kindle
  zjjfp_kindle
}

buc_execute jjfp_ "Fundus Operations" zjjfp_furnish "$@"

# eof
