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
# BUUT - TabTarget Operations - Command Line Interface

set -euo pipefail

source "${BASH_SOURCE[0]%/*}/buc_command.sh" || exit 1
source "${BASH_SOURCE[0]%/*}/buym_yelp.sh" || buc_die_now "Failed to source buym_yelp.sh"

zbuut_furnish() {
  buc_doc_env_row "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_row "BURD_TEMP_DIR         " "Temporary directory for intermediate files"
  buc_doc_env_row "BURC_TABTARGET_DIR    " "Directory for tabtarget scripts"
  buc_doc_env_row "BURC_TOOLS_DIR        " "Directory for tools"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/buut_tabtarget.sh" || buc_die_now "Failed to source buut_tabtarget.sh"

  zbuut_kindle
}

buc_execute buut_ "TabTarget Operations" zbuut_furnish "$@"

# eof
