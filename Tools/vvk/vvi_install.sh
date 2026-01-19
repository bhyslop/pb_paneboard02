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
# VVI Install - Bootstrap script for VVK parcel installation
#
# This script lives at the root of an extracted parcel. It validates
# the target environment and invokes the appropriate platform binary.
#
# Usage: ./vvi_install.sh /path/to/target/<BURC_RELPATH>
#        where BURC_RELPATH is defined as ZVVI_BURC_RELPATH below
#
# Note: This is a standalone bootstrap - cannot depend on BUK.
# Local functions follow BCG patterns without sourcing dependencies.

set -euo pipefail

######################################################################
# Constants

# Canonical BURC relative path - single definition for this script
readonly ZVVI_BURC_RELPATH=".buk/burc.env"

######################################################################
# Local BCG-style functions (cannot source BUK)

zvvi_die() {
  echo "vvi_install: error: ${1}" >&2
  exit 1
}

zvvi_step() {
  echo "${1}" >&2
}

######################################################################
# Internal functions

zvvi_platform_capture() {
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

zvvi_main() {
  local z_burc_path="${1:-}"

  if [[ -z "${z_burc_path}" ]]; then
    echo "vvi_install: Install VVK parcel to a target repository" >&2
    echo "" >&2
    echo "Usage: $0 /path/to/target/${ZVVI_BURC_RELPATH}" >&2
    echo "" >&2
    echo "The target repository must have BURC configured (${ZVVI_BURC_RELPATH})." >&2
    exit 1
  fi

  test -f "${z_burc_path}" || zvvi_die "BURC file not found: ${z_burc_path}"
  test -r "${z_burc_path}" || zvvi_die "BURC file not readable: ${z_burc_path}"

  local z_platform
  z_platform=$(zvvi_platform_capture) || zvvi_die "Unsupported platform: $(uname -s)-$(uname -m)"

  local z_script_dir="${BASH_SOURCE[0]%/*}"

  local z_binary="${z_script_dir}/kits/vvk/bin/vvx-${z_platform}"

  test -f "${z_binary}" || zvvi_die "Platform binary not found: ${z_binary}"

  test -x "${z_binary}" || chmod +x "${z_binary}" || zvvi_die "Cannot make binary executable: ${z_binary}"

  zvvi_step "Installing VVK parcel..."
  zvvi_step "  Platform: ${z_platform}"
  zvvi_step "  Target: ${z_burc_path}"

  exec "${z_binary}" vvx_emplace --parcel "${z_script_dir}" --burc "${z_burc_path}"
}

zvvi_main "$@"

# eof
