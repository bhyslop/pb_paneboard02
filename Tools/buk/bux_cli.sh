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
# BUX CLI - General-purpose test fixtures for BUK dispatch

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"

######################################################################
# Command Functions

bux_delay() {
  buc_doc_brief "Sleep 20 seconds (timing fixture for concurrent dispatch testing)"
  buc_doc_shown || return 0

  buc_step "Delay: sleeping 20 seconds"
  sleep 20
  buc_step "Delay: complete"
}

######################################################################
# Furnish and Main

zbux_furnish() {
  buc_doc_env "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_done || return 0
}

buc_execute bux_ "BUK Test Fixtures" zbux_furnish "$@"

# eof
