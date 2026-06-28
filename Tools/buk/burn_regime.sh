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
# BURN Regime - Bash Utility Regime Node Module
#
# BURN is a multi-instance regime — one file per node investiture.
# Each instance lives at rbmm_moorings/rbmn_nodes/<investiture>/burn.env and is
# project-global (git-tracked, shared across station users).

set -euo pipefail

# Multiple inclusion detection
test -z "${ZBURN_SOURCED:-}" || buc_die "Module burn multiply sourced - check sourcing hierarchy"
ZBURN_SOURCED=1

######################################################################
# Internal Functions (zburn_*)

zburn_kindle() {
  test -z "${ZBURN_KINDLED:-}" || buc_die "Module burn already kindled"

  # No defaults set — buv uses ${!varname:-} for safe indirect expansion under set -u.
  # Unset variables are detected distinctly from empty by zbuv_check_capture.

  buv_regime_enroll BURN

  buv_group_enroll "Node Identity"
  buv_string_enroll  BURN_HOST      1  253  "IP address or hostname of the remote node"
  buv_enum_enroll    BURN_PLATFORM  "OS family of the node (bunne_* identifier)"  bunne_linux bunne_mac bunne_windows

  # Guard against unexpected BURN_ variables not in enrollment
  buv_scope_sentinel BURN BURN_

  # Lock all enrolled BURN_ variables against mutation
  buv_lock BURN

  readonly ZBURN_KINDLED=1
}

zburn_sentinel() {
  test "${ZBURN_KINDLED:-}" = "1" || buc_die "Module burn not kindled - call zburn_kindle first"
}

# Enforce all BURN enrollment validations
zburn_enforce() {
  zburn_sentinel

  buv_vet BURN
}

######################################################################
# Public Functions (burn_*)

# List available investiture names as space-separated tokens.
# Emits one <investiture>.${BUF_EXT_ALIAS} observation fact per profile
# (empty content; presence is the fact).
# Returns non-zero if no profiles are present.
# Prerequisite: BURD kindled (BURD_CONFIG_DIR)
burn_list_capture() {
  zburd_sentinel

  local -r z_nodes_dir="${BURD_CONFIG_DIR}/${BUBC_rbmn_nodes_subdir}"
  test -d "${z_nodes_dir}" || return 1

  local z_result=""
  local z_files=("${z_nodes_dir}"/*/burn.env)
  local z_i=""
  for z_i in "${!z_files[@]}"; do
    test -f "${z_files[$z_i]}" || continue
    local z_dir="${z_files[$z_i]%/*}"
    local z_investiture="${z_dir##*/}"
    buf_write_fact_multi "${z_investiture}" "${BUF_EXT_ALIAS}" ""
    z_result="${z_result}${z_result:+ }${z_investiture}"
  done
  test -n "${z_result}" || return 1
  echo "${z_result}"
}

# Friendly-error die: emit "no folio supplied" message followed by available
# investitures (or a "no profiles" hint when the directory is empty).
# Prerequisite: BURD kindled (BURD_CONFIG_DIR)
burn_die_no_folio() {
  zburd_sentinel
  local z_aliases=""
  if z_aliases=$(burn_list_capture 2>/dev/null); then
    buc_warn "BURN investiture required as first argument."
    buc_step "Available investitures under ${BURD_MOORINGS_DIR}/${BUBC_rbmn_nodes_subdir}/:"
    local z_v=""
    for z_v in ${z_aliases}; do
      buc_bare "        ${z_v}"
    done
  else
    buc_warn "BURN investiture required as first argument."
    buc_step "No profiles found under ${BURD_MOORINGS_DIR}/${BUBC_rbmn_nodes_subdir}/."
    buc_bare "        Author one at ${BURD_MOORINGS_DIR}/${BUBC_rbmn_nodes_subdir}/<investiture>/burn.env"
  fi
  buc_die "No BURN investiture supplied."
}

# eof
