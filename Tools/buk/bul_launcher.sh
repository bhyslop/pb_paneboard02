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
# BUL Launcher - Shared launcher logic for BUK workbenches.
# Sourced by individual launcher stubs in .buk/
# Compatible with Bash 3.2 (e.g., macOS default shell)
#
# NOTE: This is bootstrap infrastructure, not a full BCG module.
# No kindle/sentinel pattern - this runs before BCG modules are loaded.

# Guard against multiple inclusion
test -z "${ZBUL_LAUNCHER_SOURCED:-}" || return 0
ZBUL_LAUNCHER_SOURCED=1

# Establish project root from the sourcing launcher's location
ZBUL_PROJECT_ROOT="${BASH_SOURCE[1]%/*}/.."
cd "${ZBUL_PROJECT_ROOT}" || exit 1

# Load BURC configuration
export BUD_REGIME_FILE="${ZBUL_PROJECT_ROOT}/.buk/burc.env"
source "${BUD_REGIME_FILE}" || exit 1

# Source BUK modules and kindle BURC
export BUD_STATION_FILE="${ZBUL_PROJECT_ROOT}/${BURC_STATION_FILE}"
source "${BURC_TOOLS_DIR}/buk/buc_command.sh"
source "${BURC_TOOLS_DIR}/buk/burc_regime.sh"
zburc_kindle

# Load BURS configuration and kindle
z_station_file="${ZBUL_PROJECT_ROOT}/${BURC_STATION_FILE}"
source "${z_station_file}" || exit 1
source "${BURC_TOOLS_DIR}/buk/burs_regime.sh"
zburs_kindle

# Helper function to delegate to BUD
# Usage: bul_launch "path/to/workbench.sh" "$@"
bul_launch() {
  local z_coordinator="$1"
  shift
  export BUD_COORDINATOR_SCRIPT="${z_coordinator}"
  exec "${BURC_TOOLS_DIR}/buk/bud_dispatch.sh" "${1##*/}" "${@:2}"
}
