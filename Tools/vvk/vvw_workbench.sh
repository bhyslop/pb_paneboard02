#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
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
# VVW Workbench - Routes VVK management commands via zipper registry
#
# All commands dispatch via buz_exec_lookup (see vvz_zipper.sh for colophon mapping).

set -euo pipefail

# Get script directory
VVW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${BURD_BUK_DIR}/buc_command.sh" || exit 1
source "${BURD_BUK_DIR}/buym_yelp.sh" || exit 1

# The band's range, its gate codes and the verdict codes, from the substrate's
# generated constants, sourced at this process's entry. The sourced file carries
# its own inclusion guard, so a sibling sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/../buk/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"
source "${BURD_BUK_DIR}/buz_zipper.sh" || buc_die_now "Failed to source buz_zipper.sh"
source "${VVW_SCRIPT_DIR}/vvz_zipper.sh" || buc_die_now "Failed to source vvz_zipper.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# The workbench's head: a name of the kit standing exported is refused save
# the hand-offs every level declares.
buv_export_sentinel "${BURD_TARGET}"

# Kindle the zipper registry; the command module kindled the dispatch regime
zbuz_kindle
zvvz_kindle

vvw_main() {
  local -r z_command="${1:-}"
  test "$#" -eq 0 || shift
  test -n "${z_command}" || buc_die_now "No command specified"

  zburd_sentinel
  buz_exec_lookup "${z_command}" "${VVW_SCRIPT_DIR}" "$@"
}

vvw_main "$@"

# eof
