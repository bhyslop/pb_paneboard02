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
# VVU Uninstall - Bootstrap script for VVK removal
#
# Thin bootstrap: detect platform, exec vvx_vacate.
# All logic (git checks, path safety) is in Rust.
#
# Usage: ./vvu_uninstall.sh /path/to/target/<moorings-dir>/burc.env
#        the path is the consumer's own BURC file — its moorings dirname is
#        that consumer's choice (e.g. rbmm_moorings, jjmm_moorings), never
#        this script's business.
#
# This script stands at two seats and resolves its binary from its own
# location at both, never from the process working directory:
#
#   parcel root      -> kits/vvk/bin/vvx-{platform}, the platform-suffixed
#                       binary every parcel bundles whatever its kit set
#   Tools/vvk/ in a   -> bin/vvx, the canonical binary install emplaces
#   target repo          beside this script when vvk rides the parcel
#
# The parcel seat is what makes uninstall reachable for every kit set: a
# target whose parcel carried no vvk holds neither this script nor a binary,
# so the parcel is the only seat that always exists. The two cannot be
# confused — a parcel root holds no bin/ beside this script, and Tools/vvk/
# holds no kits/.
#
# Note: This is a standalone bootstrap - cannot depend on BUK.
# Local functions follow the same console conventions without sourcing dependencies.

set -euo pipefail

######################################################################
# Constants

# Example relpath for the usage message only — the real path always arrives
# as $1; no consumer moorings dirname is assumed or required.
readonly ZVVU_BURC_RELPATH_EXAMPLE="<moorings-dir>/burc.env"

readonly ZVVU_PARCEL_BIN_RELDIR="kits/vvk/bin"
readonly ZVVU_TARGET_BIN_RELDIR="bin"
readonly ZVVU_CANONICAL_BINARY="vvx"

######################################################################
# Local console-style functions

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
  local z_burc_path="${1:-}"

  if [[ -z "${z_burc_path}" ]]; then
    echo "vvu_uninstall: Remove VVK integration from a target repository" >&2
    echo "" >&2
    echo "Usage: $0 /path/to/target/${ZVVU_BURC_RELPATH_EXAMPLE}" >&2
    echo "" >&2
    echo "Run from an extracted parcel, or from Tools/vvk/ in an installed repo." >&2
    exit 1
  fi

  test -f "${z_burc_path}" || zvvu_die "BURC file not found: ${z_burc_path}"
  test -r "${z_burc_path}" || zvvu_die "BURC file not readable: ${z_burc_path}"

  local z_platform
  z_platform=$(zvvu_platform_capture) || zvvu_die "Unsupported platform: $(uname -s)-$(uname -m)"

  local z_script_dir="${BASH_SOURCE[0]%/*}"

  local z_parcel_binary="${z_script_dir}/${ZVVU_PARCEL_BIN_RELDIR}/${ZVVU_CANONICAL_BINARY}-${z_platform}"
  local z_target_binary="${z_script_dir}/${ZVVU_TARGET_BIN_RELDIR}/${ZVVU_CANONICAL_BINARY}"

  local z_binary=""
  local z_seat=""

  if [[ -f "${z_parcel_binary}" ]]; then
    z_binary="${z_parcel_binary}"
    z_seat="parcel"
  elif [[ -f "${z_target_binary}" ]]; then
    z_binary="${z_target_binary}"
    z_seat="target"
  else
    zvvu_die "VVX binary not found at either seat: ${z_parcel_binary} (parcel) or ${z_target_binary} (installed repo)"
  fi

  test -x "${z_binary}" || chmod +x "${z_binary}" || zvvu_die "Cannot make binary executable: ${z_binary}"

  zvvu_step "Uninstalling VVK..."
  zvvu_step "  Platform: ${z_platform}"
  zvvu_step "  Seat: ${z_seat}"
  zvvu_step "  Target: ${z_burc_path}"

  exec "${z_binary}" vvx_vacate --burc "${z_burc_path}"
}

zvvu_main "$@"

# eof
