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
# PBK Workbench - Routes PaneBoard Cargo commands

set -euo pipefail

# Get script directory
PBW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${PBW_SCRIPT_DIR}/../buk/buc_command.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Verbose output if BUD_VERBOSE is set
pbw_show() {
  test "${BUD_VERBOSE:-0}" != "1" || echo "PBWSHOW: $*"
}

# Simple routing function
pbw_route() {
  local z_command="$1"
  shift
  local z_args="$*"

  pbw_show "Routing command: ${z_command} with args: ${z_args}"

  # Verify BUD environment variables are present
  test -n "${BUD_TEMP_DIR:-}" || buc_die "BUD_TEMP_DIR not set - must be called from BUD"
  test -n "${BUD_NOW_STAMP:-}" || buc_die "BUD_NOW_STAMP not set - must be called from BUD"

  pbw_show "BUD environment verified"

  # Route based on command
  case "${z_command}" in

    # Proof of Concept - build and run
    pbw-p)
      echo "Building and running PaneBoard PoC..."
      cd poc
      cargo build "$@" && cargo run "$@"
      ;;

    *)
      buc_die "Unknown command: ${z_command}"
      ;;
  esac
}

# Main entry point
pbw_main() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  pbw_route "${z_command}" "$@"
}

pbw_main "$@"

# eof
