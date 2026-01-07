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
# BUUT - TabTarget Operations - Command Line Interface

set -euo pipefail

ZBUUT_CLI_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source all dependencies
source "${ZBUUT_CLI_SCRIPT_DIR}/buc_command.sh"
source "${ZBUUT_CLI_SCRIPT_DIR}/buv_validation.sh"
source "${ZBUUT_CLI_SCRIPT_DIR}/buut_tabtarget.sh"

zbuut_furnish() {

  buc_doc_env "BUD_TEMP_DIR         " "Temporary directory for intermediate files"
  buc_doc_env "BURC_TABTARGET_DIR   " "Directory for tabtarget scripts"
  buc_doc_env "BURC_TOOLS_DIR       " "Directory for tools"

  # Load BURC configuration
  local z_burc_file="${PWD}/.buk/burc.env"
  buv_file_exists "${z_burc_file}"
  source "${z_burc_file}" || buc_die "Failed to source BURC file"

  zbuut_kindle
}

buc_execute buut_ "TabTarget Operations" zbuut_furnish "$@"

# eof
