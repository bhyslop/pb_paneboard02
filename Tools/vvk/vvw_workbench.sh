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
# VVW Workbench - Routes VVK management commands

set -euo pipefail

# Get script directory
VVW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${BURD_BUK_DIR}/buc_command.sh"
source "${BURD_BUK_DIR}/buv_validation.sh"
source "${BURD_BUK_DIR}/burd_regime.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Verify dispatch completed
zbuv_kindle
zburd_kindle

# Simple routing function
vvw_route() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  zburd_sentinel

  # Route based on command
  local z_vvb_cli="${VVW_SCRIPT_DIR}/vvb_cli.sh"

  case "${z_command}" in

    # Run VVX binary - primary command
    vvw-r)  exec "${z_vvb_cli}" vvb_run "$@" ;;

    # Show platform
    vvx-p)  exec "${z_vvb_cli}" vvb_platform "$@" ;;

    # Unknown command
    *)   buc_die "Unknown command: ${z_command}" ;;
  esac
}

vvw_main() {
  local z_command="${1:-}"
  shift || true

  vvw_route "${z_command}" "$@"
}

vvw_main "$@"

# eof
