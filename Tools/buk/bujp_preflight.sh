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
# BUJP Preflight Module — garrison step-1 precondition gate.

set -euo pipefail

test -z "${ZBUJP_SOURCED:-}" || buc_die "Module bujp multiply sourced - check sourcing hierarchy"
ZBUJP_SOURCED=1

######################################################################
# Internal Functions (zbujp_*)

zbujp_kindle() {
  test -z "${ZBUJP_KINDLED:-}" || buc_die "Module bujp already kindled"

  readonly ZBUJP_SSH_PROBE_PREFIX="${BURD_TEMP_DIR}/bujp_ssh_probe_"

  readonly ZBUJP_KINDLED=1
}

zbujp_sentinel() {
  test "${ZBUJP_KINDLED:-}" = "1" || buc_die "Module bujp not kindled - call zbujp_kindle first"
}

# zbujp_probe_ssh_connect LETTER -- exit 0 if admin SSH reaches the
# letter's shell-environment under key-only auth; die with a platform-
# specific recovery hint otherwise.
zbujp_probe_ssh_connect() {
  zbujp_sentinel
  local z_letter="${1:-}"

  local z_exit=0
  case "${z_letter}" in
    b)
      zbujb_admin_exec_native 'exit 0' \
          > "${ZBUJP_SSH_PROBE_PREFIX}stdout.txt" \
          2> "${ZBUJP_SSH_PROBE_PREFIX}stderr.txt" \
        || z_exit=$?
      ;;
    c)
      zbujb_admin_exec_cygwin 'exit 0' \
          > "${ZBUJP_SSH_PROBE_PREFIX}stdout.txt" \
          2> "${ZBUJP_SSH_PROBE_PREFIX}stderr.txt" \
        || z_exit=$?
      ;;
    w)
      zbujb_admin_exec_wsl 'exit 0' \
          > "${ZBUJP_SSH_PROBE_PREFIX}stdout.txt" \
          2> "${ZBUJP_SSH_PROBE_PREFIX}stderr.txt" \
        || z_exit=$?
      ;;
    *)
      buc_die "zbujp_probe_ssh_connect: invalid shell-letter '${z_letter}'"
      ;;
  esac

  test "${z_exit}" -eq 0 && return 0

  case "${BURN_PLATFORM}" in
    bunne_windows)
      buc_die "Admin SSH unreachable for ${BURP_PRIVILEGED_USER}@${BURN_HOST} (key=${BURP_PRIVILEGED_KEY_FILE}, exit ${z_exit}) — run caparison-windows first (see ${ZBUJP_SSH_PROBE_PREFIX}stderr.txt)"
      ;;
    *)
      buc_die "Admin SSH unreachable for ${BURP_PRIVILEGED_USER}@${BURN_HOST} (key=${BURP_PRIVILEGED_KEY_FILE}, exit ${z_exit}) — place admin pubkey via ssh-copy-id (see ${ZBUJP_SSH_PROBE_PREFIX}stderr.txt)"
      ;;
  esac
}

######################################################################
# Public: Preflight ceremony

# bujp_preflight LETTER -- garrison step-1 gate. Two-part shape:
#   (a) Workload shell-environment reachability per letter (b/c/w) —
#       not host-posture; gates per-letter transport before invigilate.
#   (b) Host-posture verification per platform — delegates to invigilate
#       (single source of truth for "correctly-configured", BUSJI{W,M,L},
#       including operator-managed precondition facts).
bujp_preflight() {
  zbujp_sentinel
  local z_letter="${1:-}"

  buc_step "  [1/6] Preflight (${BURP_PRIVILEGED_USER}@${BURN_HOST}, letter=${z_letter})"

  zbujp_probe_ssh_connect "${z_letter}"

  case "${BURN_PLATFORM}" in
    bunne_linux)   bujb_invigilate_linux   ;;
    bunne_mac)     bujb_invigilate_macos   ;;
    bunne_windows) bujb_invigilate_windows ;;
    *) buc_die "bujp_preflight: unsupported BURN_PLATFORM '${BURN_PLATFORM}'" ;;
  esac
}

# eof
