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
# VVU Uninstall - Bootstrap script for VVK removal
#
# Thin bootstrap: detect platform, exec vvx_vacate.
# All logic (git checks, commits) is in Rust.
#
# Usage: ./Tools/vvk/vvu_uninstall.sh

set -euo pipefail

######################################################################
# Constants

readonly ZVVU_BURC_RELPATH=".buk/burc.env"

######################################################################
# Local BCG-style functions

zvvu_die() {
  echo "vvu_uninstall: error: ${1}" >&2
  exit 1
}

zvvu_step() {
  echo "${1}" >&2
}

######################################################################
# Internal functions

zvvu_platform_capture() {
  local z_os
  local z_arch
  local z_platform

  z_os=$(uname -s) || return 1
  z_arch=$(uname -m) || return 1

  case "${z_os}-${z_arch}" in
    Darwin-arm64)   z_platform="darwin-arm64" ;;
    Darwin-x86_64)  z_platform="darwin-x86_64" ;;
    Linux-x86_64)   z_platform="linux-x86_64" ;;
    Linux-aarch64)  z_platform="linux-aarch64" ;;
    *)              return 1 ;;
  esac

  echo "${z_platform}"
}

######################################################################
# Main

zvvu_main() {
  local z_burc_path="${ZVVU_BURC_RELPATH}"

  # Verify we're in a VVK-enabled repo
  test -f "${z_burc_path}" || zvvu_die "Not in a VVK-enabled repo (missing ${z_burc_path})"

  # Get platform and find binary
  local z_platform
  z_platform=$(zvvu_platform_capture) || zvvu_die "Unsupported platform: $(uname -s)-$(uname -m)"

  local z_binary="Tools/vvk/bin/vvx-${z_platform}"
  test -f "${z_binary}" || zvvu_die "VVX binary not found: ${z_binary}"
  test -x "${z_binary}" || zvvu_die "VVX binary not executable: ${z_binary}"

  zvvu_step "Uninstalling VVK..."
  zvvu_step "  Platform: ${z_platform}"

  exec "${z_binary}" vvx_vacate --burc "${z_burc_path}"
}

zvvu_main "$@"

# eof
