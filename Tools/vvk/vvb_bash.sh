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
# VVB Bash - Platform detection and VVX binary execution

set -euo pipefail

# Multiple inclusion detection
test -z "${ZVVB_SOURCED:-}" || buc_die "Module vvb multiply sourced - check sourcing hierarchy"
ZVVB_SOURCED=1

######################################################################
# Internal Functions (zvvb_*)

zvvb_platform_capture() {
  local z_os
  local z_arch
  local z_platform

  z_os=$(uname -s) || return 1
  z_arch=$(uname -m) || return 1

  case "${z_os}-${z_arch}" in
    Darwin-arm64)                      z_platform="darwin-arm64" ;;
    Darwin-x86_64)                     z_platform="darwin-x86_64" ;;
    Linux-x86_64)                      z_platform="linux-x86_64" ;;
    Linux-aarch64)                     z_platform="linux-aarch64" ;;
    MINGW*-x86_64|MSYS*-x86_64)        z_platform="windows-x86_64" ;;
    *)                                 return 1 ;;
  esac

  echo "${z_platform}"
}

zvvb_kindle() {
  test -z "${ZVVB_KINDLED:-}" || buc_die "Module vvb already kindled"

  # Locate VVK directory (parent of this script)
  ZVVB_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

  # Public export - binary directory (may not exist until first build)
  VVB_BIN_DIR="${ZVVB_SCRIPT_DIR}/bin"

  # Public export - platform identifier (use capture function)
  VVB_PLATFORM=""
  VVB_PLATFORM=$(zvvb_platform_capture) || buc_die "Failed to detect platform"

  # Public export - full path to platform-specific VVX binary
  VVB_VVX_BINARY="${VVB_BIN_DIR}/vvx-${VVB_PLATFORM}"

  ZVVB_KINDLED=1
}

zvvb_sentinel() {
  test "${ZVVB_KINDLED:-}" = "1" || buc_die "Module vvb not kindled - call zvvb_kindle first"
}

zvvb_binary_path_capture() {
  zvvb_sentinel

  test -f "${VVB_VVX_BINARY}" || return 1
  test -x "${VVB_VVX_BINARY}" || return 1

  echo "${VVB_VVX_BINARY}"
}

######################################################################
# External Functions (vvb_*)

vvb_run() {
  zvvb_sentinel

  buc_doc_brief "Execute VVX binary with provided arguments"
  buc_doc_param "..." "Arguments passed to vvx"
  buc_doc_shown || return 0

  buc_step "Locating VVX binary"

  local z_binary=""
  z_binary=$(zvvb_binary_path_capture) || buc_die "VVX binary not found for platform $(uname -s)-$(uname -m)"

  buc_log_args "Binary: ${z_binary}"
  buc_log_args "Arguments: $*"

  exec "${z_binary}" "$@"
}

vvb_platform() {
  zvvb_sentinel

  buc_doc_brief "Display detected platform identifier"
  buc_doc_shown || return 0

  local z_platform=""
  z_platform=$(zvvb_platform_capture) || buc_die "Unsupported platform: $(uname -s)-$(uname -m)"

  echo "${z_platform}"
}

# eof
