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
# JJW Workbench - Routes Job Jockey commands to CLIs via zipper registry
#
# All commands dispatch via buz_exec_lookup (see jjz_zipper.sh for colophon mapping).

set -euo pipefail

# Get script directory
JJW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${BURD_BUK_DIR}/buc_command.sh"
source "${BURD_BUK_DIR}/buv_validation.sh"
source "${BURD_BUK_DIR}/burd_regime.sh"
source "${BURD_BUK_DIR}/buz_zipper.sh"
source "${JJW_SCRIPT_DIR}/jjz_zipper.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Kindle dispatch and zipper registry
zbuv_kindle
zburd_kindle
zbuz_kindle
zjjz_kindle

# Verbose output if BURE_VERBOSE is set
jjw_show() {
  test "${BURE_VERBOSE:-0}" != "1" || echo "JJWSHOW: $*"
}

######################################################################
# Routing

jjw_route() {
  local z_command="$1"
  shift

  jjw_show "Routing command: ${z_command} with args: $*"

  zburd_sentinel
  zjjz_healthcheck

  jjw_show "BURD environment verified"

  buz_exec_lookup "${z_command}" "${JJW_SCRIPT_DIR}" "$@"
}

jjw_main() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  jjw_route "${z_command}" "$@"
}

jjw_main "$@"

# eof
