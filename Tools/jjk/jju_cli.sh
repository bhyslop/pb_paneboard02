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
# JJU CLI - Job Jockey Utility command-line interface

set -euo pipefail

ZJJU_CLI_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source all dependencies
source "${ZJJU_CLI_SCRIPT_DIR}/../buk/buc_command.sh"
source "${ZJJU_CLI_SCRIPT_DIR}/../buk/buv_validation.sh"
source "${ZJJU_CLI_SCRIPT_DIR}/jju_utility.sh"

######################################################################
# Furnish

zjju_furnish() {
  buc_doc_env "BUD_TEMP_DIR         " "Temporary directory for intermediate files"
  buc_doc_env "BUD_NOW_STAMP        " "Unique timestamp for this invocation"

  # Validate BUD environment
  buv_dir_exists "${BUD_TEMP_DIR}"
  test -n "${BUD_NOW_STAMP:-}" || buc_die "BUD_NOW_STAMP is unset"

  zjju_kindle
}

buc_execute jju_ "Job Jockey Utility Functions" zjju_furnish "$@"

# eof
