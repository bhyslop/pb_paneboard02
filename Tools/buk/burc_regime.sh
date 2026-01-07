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
# BURC Regime - Bash Utility Regime Configuration Module

set -euo pipefail

# Multiple inclusion detection
test -z "${ZBURC_SOURCED:-}" || buc_die "Module burc multiply sourced - check sourcing hierarchy"
ZBURC_SOURCED=1

######################################################################
# Internal Functions (zburc_*)

zburc_kindle() {
  test -z "${ZBURC_KINDLED:-}" || buc_die "Module burc already kindled"

  # Validate all required BURC variables
  test -n "${BURC_STATION_FILE:-}" || buc_die "BURC_STATION_FILE is not set"
  test -n "${BURC_TABTARGET_DIR:-}" || buc_die "BURC_TABTARGET_DIR is not set"
  test -n "${BURC_TABTARGET_DELIMITER:-}" || buc_die "BURC_TABTARGET_DELIMITER is not set"
  test -n "${BURC_TOOLS_DIR:-}" || buc_die "BURC_TOOLS_DIR is not set"
  test -n "${BURC_TEMP_ROOT_DIR:-}" || buc_die "BURC_TEMP_ROOT_DIR is not set"
  test -n "${BURC_OUTPUT_ROOT_DIR:-}" || buc_die "BURC_OUTPUT_ROOT_DIR is not set"
  test -n "${BURC_LOG_LAST:-}" || buc_die "BURC_LOG_LAST is not set"
  test -n "${BURC_LOG_EXT:-}" || buc_die "BURC_LOG_EXT is not set"

  # Validate delimiter is exactly one character
  test "${#BURC_TABTARGET_DELIMITER}" -eq 1 || buc_die "BURC_TABTARGET_DELIMITER must be exactly one character"

  ZBURC_KINDLED=1
}

zburc_sentinel() {
  test "${ZBURC_KINDLED:-}" = "1" || buc_die "Module burc not kindled - call zburc_kindle first"
}

# eof
