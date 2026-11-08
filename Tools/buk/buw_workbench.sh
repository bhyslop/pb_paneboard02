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
# BUK Workbench - Routes BUK management commands via zipper registry
#
# All commands dispatch via buz_exec_lookup (see buwz_zipper.sh for colophon mapping).

set -euo pipefail

# Get script directory
BUW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${BUW_SCRIPT_DIR}/buc_command.sh" || exit 1
source "${BUW_SCRIPT_DIR}/buym_yelp.sh" || buc_die_now "Failed to source buym_yelp.sh"

# The band's range, its gate codes and the verdict codes, from the substrate's
# generated constants, sourced at this process's entry. The sourced file carries
# its own inclusion guard, so a sibling sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"
source "${BUW_SCRIPT_DIR}/buz_zipper.sh" || buc_die_now "Failed to source buz_zipper.sh"
source "${BUW_SCRIPT_DIR}/buwz_zipper.sh" || buc_die_now "Failed to source buwz_zipper.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# The workbench's head: a name of the kit standing exported is refused save
# the hand-offs every level declares.
buv_export_sentinel "${BURD_TARGET}"

# Kindle the zipper registry; the command module kindled the dispatch regime
zbuz_kindle
zbuwz_kindle

# Verbose output if BURE_VERBOSE is set
buw_show() {
  test "${BURE_VERBOSE:-0}" != "1" || echo "BUWSHOW: $*"
}

######################################################################
# Routing

buw_route() {
  local z_command="${1}"
  test "$#" -eq 0 || shift

  buw_show "Routing command: ${z_command} with args: $*"

  zburd_sentinel

  buw_show "BURD environment verified"

  buz_exec_lookup "${z_command}" "${BUW_SCRIPT_DIR}" "$@"
}

buw_main() {
  local z_command="${1:-}"
  test "$#" -eq 0 || shift

  test -n "${z_command}" || buc_die_now "No command specified"

  buw_route "${z_command}" "$@"
}

buw_main "$@"

# eof
