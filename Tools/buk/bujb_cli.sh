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
# BUJB CLI - Command line interface for the jurisdiction module
#
# Furnish loads BURC, BURS, BURP (per investiture folio), and the cross-
# referenced BURN profile, then kindles bujb. Command functions call
# bujb_resolve_investiture before doing any work; per-verb platform
# invariants are asserted inline at the command body.

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"

######################################################################
# Command Functions

# bujb_resolve - diagnostic: load investiture and print resolved fields.
# No remote action; verifies regime + key-file health for a target.
bujb_resolve() {
  zbujb_sentinel
  buc_doc_brief "Cross-validate an investiture and display the regime fields it resolves"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio

  bujb_resolve_investiture

  buc_step "Resolved investiture ${BUZ_FOLIO}:"
  buc_bare "  BURN_HOST               = ${BURN_HOST}"
  buc_bare "  BURN_PLATFORM           = ${BURN_PLATFORM}"
  buc_bare "  BURP_PRIVILEGED_USER    = ${BURP_PRIVILEGED_USER}"
  buc_bare "  BURP_PRIVILEGED_KEY_FILE= ${BURP_PRIVILEGED_KEY_FILE}"
  buc_bare "  BURP_WORKLOAD_KEY_FILE  = ${BURP_WORKLOAD_KEY_FILE}"
  buc_bare "  BUJB_workload_user      = ${BUJB_workload_user}"
}

# bujb_knock - probe workload reachability (workload SSH + remote no-op).
bujb_knock() {
  zbujb_sentinel
  buc_doc_brief "Probe workload SSH reachability for an investiture"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio

  bujb_resolve_investiture

  buc_step "Knocking ${BUJB_workload_user}@${BURN_HOST} (${BUZ_FOLIO})"

  ssh -i "${BURP_WORKLOAD_KEY_FILE}"     \
      -o IdentitiesOnly=yes                       \
      -o BatchMode=yes                            \
      -o StrictHostKeyChecking=accept-new         \
      -o ConnectTimeout=10                        \
      "${BUJB_workload_user}@${BURN_HOST}" \
      true                                        \
    || buc_die "Knock failed for ${BUZ_FOLIO}"

  buc_step "Knock succeeded"
}

# bujb_command_file - stream a local command file's contents to the workload
# remote shell. Captures stdout/stderr/exit to BURD_OUTPUT_DIR. Per spec:
# returns 0 when dispatch + capture complete (independent of remote exit);
# non-zero on SSH-level failure (exit 255).
bujb_command_file() {
  zbujb_sentinel
  buc_doc_brief "Execute a local command file as workload; capture stdout/stderr/exit"
  buc_doc_param "command_file" "Local file streamed as the remote command body"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio

  local -r z_command_file="${1:-}"
  test -n "${z_command_file}"   || buc_usage_die
  test -f "${z_command_file}"   || buc_die "Command file not found: ${z_command_file}"
  test -r "${z_command_file}"   || buc_die "Command file not readable: ${z_command_file}"

  bujb_resolve_investiture

  buc_step "Streaming ${z_command_file} to ${BUJB_workload_user}@${BURN_HOST}"
  buc_step "Output dir: ${BURD_OUTPUT_DIR}"

  local z_exit=0
  ssh -i "${BURP_WORKLOAD_KEY_FILE}"     \
      -o IdentitiesOnly=yes                       \
      -o BatchMode=yes                            \
      -o StrictHostKeyChecking=accept-new         \
      -o ConnectTimeout=10                        \
      "${BUJB_workload_user}@${BURN_HOST}" \
      'bash -s'                                   \
      < "${z_command_file}"                       \
      > "${ZBUJB_OUTPUT_STDOUT}"                  \
      2> "${ZBUJB_OUTPUT_STDERR}"                 \
    || z_exit=$?

  echo "${z_exit}" > "${ZBUJB_OUTPUT_EXITCODE}" \
    || buc_die "Failed to write exit-code capture: ${ZBUJB_OUTPUT_EXITCODE}"

  test "${z_exit}" -ne 255 \
    || buc_die "SSH connection or authentication failed (exit 255). See ${ZBUJB_OUTPUT_STDERR}"

  buc_step "Remote exit code: ${z_exit}"
  buc_step "Capture complete"
}

# bujb_privileged_ssh_command - run an arbitrary command as BURP_PRIVILEGED_USER.
# Pass-through: argv joined into ssh's remote-command position; no shell wrapping.
bujb_privileged_ssh_command() {
  zbujb_sentinel
  buc_doc_brief "Privileged SSH — run a command on a node as BURP_PRIVILEGED_USER"
  buc_doc_param "command..." "Command tokens executed on the remote node (pass-through)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  test $# -ge 1            || buc_usage_die

  bujb_resolve_investiture
  bujb_privileged_ssh "$@"
}

# bujb_caparison_windows_command - caparison ceremony, Windows admin host posture.
bujb_caparison_windows_command() {
  zbujb_sentinel
  buc_doc_brief "Caparison — admin host posture for a bunne_windows node (admin SSH trust, sshd harden, WSL stage, sleep disable, Tailscale auto-start)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  bujb_resolve_investiture
  bujb_caparison_windows
}

# bujb_caparison_macos_command - caparison ceremony, macOS admin host posture.
bujb_caparison_macos_command() {
  zbujb_sentinel
  buc_doc_brief "Caparison — admin host posture for a bunne_mac node (Remote Login, pmset, tailscaled)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  bujb_resolve_investiture
  bujb_caparison_macos
}

# bujb_caparison_linux_command - caparison ceremony, Linux admin host posture.
bujb_caparison_linux_command() {
  zbujb_sentinel
  buc_doc_brief "Caparison — admin host posture for a bunne_linux node (sshd, sleep mask, tailscaled)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  bujb_resolve_investiture
  bujb_caparison_linux
}

# bujb_garrison_bash - garrison ceremony, native bash workload shell (Linux/Mac).
bujb_garrison_bash() {
  zbujb_sentinel
  buc_doc_brief "Garrison workload account on a bunne_linux/bunne_mac node (shell-letter b)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  bujb_resolve_investiture
  bujb_garrison b
}

# bujb_garrison_cygwin - garrison ceremony, Cygwin bash workload shell (Windows).
bujb_garrison_cygwin() {
  zbujb_sentinel
  buc_doc_brief "Garrison workload account on a bunne_windows node via Cygwin (shell-letter c)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  bujb_resolve_investiture
  bujb_garrison c
}

# bujb_garrison_wsl - garrison ceremony, WSL bash workload shell (Windows).
bujb_garrison_wsl() {
  zbujb_sentinel
  buc_doc_brief "Garrison workload account on a bunne_windows node via WSL (shell-letter w)"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio
  bujb_resolve_investiture
  bujb_garrison w
}

# bujb_interactive_session - hand control to ssh as workload.
bujb_interactive_session() {
  zbujb_sentinel
  buc_doc_brief "Interactive SSH session as workload"
  buc_doc_shown || return 0

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio

  bujb_resolve_investiture

  buc_step "Opening interactive session: ${BUJB_workload_user}@${BURN_HOST} (${BUZ_FOLIO})"

  exec ssh -t                                     \
      -i "${BURP_WORKLOAD_KEY_FILE}"     \
      -o IdentitiesOnly=yes                       \
      -o StrictHostKeyChecking=accept-new         \
      "${BUJB_workload_user}@${BURN_HOST}" \
      "bash -i"
}

######################################################################
# Furnish and Main

zbujb_furnish() {
  buc_doc_env "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env "BURD_CONFIG_DIR       " "BUK config directory (dispatch-provided)"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/buv_validation.sh"
  source "${BURD_BUK_DIR}/burd_regime.sh"
  source "${BURD_BUK_DIR}/burc_regime.sh"
  source "${BURD_BUK_DIR}/burs_regime.sh"
  source "${BURD_BUK_DIR}/buf_fact.sh"
  source "${BURD_BUK_DIR}/bubc_constants.sh"
  source "${BURD_BUK_DIR}/burn_regime.sh"
  source "${BURD_BUK_DIR}/burp_regime.sh"
  source "${BURD_BUK_DIR}/bupr_PresentationRegime.sh"
  source "${BURD_BUK_DIR}/buym_yelp.sh"
  source "${BURD_BUK_DIR}/buh_handbook.sh"
  source "${BURD_BUK_DIR}/buz_zipper.sh"
  source "${BURD_BUK_DIR}/buwz_zipper.sh"
  source "${BURD_BUK_DIR}/bujb_jurisdiction.sh"
  source "${BURD_BUK_DIR}/bujp_preflight.sh"

  zbuv_kindle
  zburd_kindle
  zburd_enforce

  source "${BURD_REGIME_FILE}" || buc_die "Failed to source BURC: ${BURD_REGIME_FILE}"

  zburc_kindle
  zburc_enforce

  source "${BURD_STATION_FILE}" || buc_die "Failed to source BURS: ${BURD_STATION_FILE}"

  zburs_kindle
  zburs_enforce

  zbupr_kindle
  zbuz_kindle
  zbuwz_kindle
  zbujb_kindle
  zbujp_kindle

  test -n "${BUZ_FOLIO:-}" || burp_die_no_folio

  local -r z_burp_file="${BURD_CONFIG_DIR}/${BUBC_rbmu_users_subdir}/${BURS_USER}/${BUZ_FOLIO}/burp.env"
  if ! test -f "${z_burp_file}"; then
    buc_warn "Unknown BURP investiture: '${BUZ_FOLIO}'."
    burp_emit_available_investitures
    buc_die "Unknown BURP investiture: '${BUZ_FOLIO}'."
  fi
  source "${z_burp_file}"  || buc_die "Failed to source BURP: ${z_burp_file}"
  zburp_kindle
  zburp_enforce

  # Cross-reference: investiture name (BUZ_FOLIO) must equal a registered investiture.
  # The 1:1 constraint is enforced by file presence — the BURN profile directory
  # name IS the investiture, and it must match BUZ_FOLIO exactly.
  local -r z_burn_file="${BURD_CONFIG_DIR}/${BUBC_rbmn_nodes_subdir}/${BUZ_FOLIO}/burn.env"
  test -f "${z_burn_file}" || buc_die "Investiture ${BUZ_FOLIO} has no matching investiture (BURN profile not found): ${z_burn_file}"
  source "${z_burn_file}"  || buc_die "Failed to source BURN: ${z_burn_file}"
  zburn_kindle
  zburn_enforce
}

buc_execute bujb_ "Bash Utility Jurisdiction" zbujb_furnish "$@"

# eof
