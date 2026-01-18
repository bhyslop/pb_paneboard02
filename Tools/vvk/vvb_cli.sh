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
# VVB CLI - Command line interface for VVX binary execution

set -euo pipefail

ZVVB_CLI_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${ZVVB_CLI_SCRIPT_DIR}/../buk/buc_command.sh"
source "${ZVVB_CLI_SCRIPT_DIR}/vvb_bash.sh"

zvvb_furnish() {
  zvvb_kindle
}

buc_execute vvb_ "VVX Binary Execution" zvvb_furnish "$@"

# eof
