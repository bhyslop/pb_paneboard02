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
source "${PBW_SCRIPT_DIR}/../buk/bug_git.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Verbose output if BURE_VERBOSE is set
pbw_show() {
  test "${BURE_VERBOSE:-0}" != "1" || echo "PBWSHOW: $*"
}

# Assemble the launchd-launchable .app bundle around the freshly built viewer
# binary, then export its absolute path for the PoC conductor to open.
#
# The viewer must be launched via launchd (NSWorkspace/open of a bundle) so it
# escapes paneboard's (deny network*) seatbelt sandbox and can listen on its
# advertised port; a direct child would inherit the sandbox and be network-
# denied (verified 2026-06-23). launchd cannot open a bare binary, hence the
# bundle. The conductor reads PBGV_VIEWER_APP from its environment.
pbw_bundle_viewer() {
  local z_profile="debug"
  case " $* " in *" --release "*) z_profile="release" ;; esac
  local z_bin="viewer/target/${z_profile}/paneboard-viewer"
  test -x "${z_bin}" || buc_die "viewer binary not found at ${z_bin}"
  local z_app="viewer/target/${z_profile}/PaneboardViewer.app"
  rm -rf "${z_app}"
  mkdir -p "${z_app}/Contents/MacOS"
  cp "${z_bin}"              "${z_app}/Contents/MacOS/paneboard-viewer"
  cp viewer/macos/Info.plist "${z_app}/Contents/Info.plist"
  export PBGV_VIEWER_APP="${PWD}/${z_app}"
  echo "Viewer bundle: ${PBGV_VIEWER_APP}"
}

# Simple routing function
pbw_route() {
  local z_command="$1"
  shift
  local z_args="$*"

  pbw_show "Routing command: ${z_command} with args: ${z_args}"

  # Verify BURD environment variables are present
  test -n "${BURD_TEMP_DIR:-}" || buc_die "BURD_TEMP_DIR not set - must be called from BURD"
  test -n "${BURD_NOW_STAMP:-}" || buc_die "BURD_NOW_STAMP not set - must be called from BURD"

  pbw_show "BURD environment verified"

  # Route based on command
  case "${z_command}" in

    # Build both crates (viewer + PoC), then launch the standing PoC overlay
    pbw-b)
      # A debugging session is only worth as much as its provenance: gate the
      # build so the running binary always corresponds to a commit, and a log
      # captured hours later can be traced to exact source.
      bug_require_clean_tree "running the PoC"
      echo "Building viewer + PaneBoard PoC, then launching..."
      cargo build --manifest-path viewer/Cargo.toml "$@" || buc_die "viewer build failed"
      pbw_bundle_viewer "$@"
      cd poc
      cargo build "$@" && cargo run "$@"
      ;;

    # Build both crates (viewer + PoC), then run the timed PoC overlay (BURD_TOKEN_3 = seconds)
    pbw-t)
      bug_require_clean_tree "running the timed PoC"
      local z_timeout="${BURD_TOKEN_3:-10}"
      echo "Building viewer + PaneBoard PoC, then running timed (timeout=${z_timeout}s)..."
      cargo build --manifest-path viewer/Cargo.toml "$@" || buc_die "viewer build failed"
      pbw_bundle_viewer "$@"
      cd poc
      cargo build "$@" && cargo run "$@" -- --timeout "${z_timeout}"
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
