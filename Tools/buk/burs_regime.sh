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
# BURS Regime - Bash Utility Regime Station Module

set -euo pipefail

# Multiple inclusion detection
test -z "${ZBURS_SOURCED:-}" || buc_die "Module burs multiply sourced - check sourcing hierarchy"
ZBURS_SOURCED=1

######################################################################
# Internal Functions (zburs_*)

zburs_kindle() {
  test -z "${ZBURS_KINDLED:-}" || buc_die "Module burs already kindled"

  # Validate all required BURS variables
  test -n "${BURS_LOG_DIR:-}" || buc_die "BURS_LOG_DIR is not set"

  ZBURS_KINDLED=1
}

zburs_sentinel() {
  test "${ZBURS_KINDLED:-}" = "1" || buc_die "Module burs not kindled - call zburs_kindle first"
}

# eof
