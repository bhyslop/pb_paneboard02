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
# JJFP CLI - Command line interface for fundus operations

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"

######################################################################
# Furnish and Main

zjjfp_furnish() {
  buc_doc_env "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env "BURD_TOOLS_DIR        " "Project tools root directory (dispatch-provided)"
  buc_doc_env "BURD_TEMP_DIR         " "Dispatch temp directory (dispatch-provided)"
  buc_doc_env "BUZ_FOLIO             " "Target host (from zipper imprint channel)"
  buc_doc_env_done || return 0

  local -r z_jjk_dir="${BURD_TOOLS_DIR}/jjk"
  source "${z_jjk_dir}/jjfp_fundus.sh"

  zjjfp_kindle
}

buc_execute jjfp_ "Fundus Operations" zjjfp_furnish "$@"

# eof
