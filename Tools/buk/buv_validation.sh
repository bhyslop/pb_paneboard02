#!/bin/bash
# Copyright 2025 Scale Invariant, Inc.
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
# Bash Validation Utility Library
# Compatible with Bash 3.2 (e.g., macOS default shell)

# The gate codes this module rejects with, from the substrate's generated
# constants, sourced above the inclusion guard so the tinder block stays the run
# behind it. The sourced file carries its own inclusion guard, so a sibling
# sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"

# Multiple inclusion guard
test -z "${ZBUV_SOURCED:-}" || buc_die_now "Module buv multiply sourced - check sourcing hierarchy"
ZBUV_SOURCED=1

# Literal constants — check capture output protocol markers
readonly BUV_check_gated="gated"
readonly BUV_check_fail="fail:"

# The regime-poison tweak name: the seam below references a BUBC_* constant at
# runtime, so every top file sourcing this module sources the tinder beside it.

buv_file_exists() {
  zbuv_sentinel
  local z_filepath="${1:-}"
  test -f "${z_filepath}" || buc_die_now "Required file not found: ${z_filepath}"
}

buv_dir_exists() {
  zbuv_sentinel
  local z_dirpath="${1:-}"
  test -d "${z_dirpath}" || buc_die_now "Required directory not found: ${z_dirpath}"
}

buv_dir_empty() {
  zbuv_sentinel
  local z_dirpath="${1:-}"
  test -d "${z_dirpath}" || buc_die_now "Required directory not found: ${z_dirpath}"
  # Per-call scratch name under BURD_TEMP_DIR: a monotonic counter, not mktemp
  # (BUV's first BURD_TEMP_DIR dependency, taken on deliberately) — never
  # deleted after — left for forensic debugging.
  z_buv_dir_empty_seq=$((${z_buv_dir_empty_seq:-0} + 1))
  local -r z_check_file="${BURD_TEMP_DIR}/buv-dir-empty-${z_buv_dir_empty_seq}.txt"
  find "${z_dirpath}" -maxdepth 1 -mindepth 1 -print -quit > "${z_check_file}" \
    || buc_die_now "Failed to probe directory: ${z_dirpath}"
  test ! -s "${z_check_file}" || buc_die_now "Directory must be empty: ${z_dirpath}"
}

# ---------------------------------------------------------------------------
# Enrollment infrastructure
# ---------------------------------------------------------------------------

zbuv_kindle() {
  test -z "${ZBUV_KINDLED:-}" || buc_die_now "Module buv already kindled"

  # Enrollment rolls (9 parallel arrays)
  z_buv_scope_roll=()
  z_buv_varname_roll=()
  z_buv_type_roll=()
  z_buv_gate_var_roll=()
  z_buv_gate_val_roll=()
  z_buv_p1_roll=()
  z_buv_p2_roll=()
  z_buv_group_roll=()
  z_buv_desc_roll=()

  # Group registry rolls (4 parallel arrays, foreign-keyed by group title)
  z_buv_grp_scope_roll=()
  z_buv_grp_title_roll=()
  z_buv_grp_gate_var_roll=()
  z_buv_grp_gate_val_roll=()

  # Koine registry rolls (2 parallel arrays): each scope handed to docker compose, and its carrier
  z_buv_koine_scope_roll=()
  z_buv_koine_carrier_roll=()

  # Mutable kindle state: regime context (set by buv_regime_enroll / buv_group_enroll / buv_gate_enroll)
  z_buv_current_scope=""
  z_buv_current_group=""
  z_buv_current_group_idx=-1
  z_buv_current_gate_var=""
  z_buv_current_gate_val=""

  readonly ZBUV_KINDLED=1
}

zbuv_sentinel() {
  test "${ZBUV_KINDLED:-}" = "1" || buc_die_now "Module buv not kindled - call zbuv_kindle first"
}

# Test support: reset enrollment state without re-kindling
zbuv_reset_enrollment() {
  zbuv_sentinel

  # Clear enrollment rolls
  z_buv_scope_roll=()
  z_buv_varname_roll=()
  z_buv_type_roll=()
  z_buv_gate_var_roll=()
  z_buv_gate_val_roll=()
  z_buv_p1_roll=()
  z_buv_p2_roll=()
  z_buv_group_roll=()
  z_buv_desc_roll=()

  # Clear group registry rolls
  z_buv_grp_scope_roll=()
  z_buv_grp_title_roll=()
  z_buv_grp_gate_var_roll=()
  z_buv_grp_gate_val_roll=()

  # Clear koine registry rolls
  z_buv_koine_scope_roll=()
  z_buv_koine_carrier_roll=()

  # Reset regime context state
  z_buv_current_scope=""
  z_buv_current_group=""
  z_buv_current_group_idx=-1
  z_buv_current_gate_var=""
  z_buv_current_gate_val=""
}

# Regime context setters — called during kindle to establish enrollment scope

# Regime-poison seam — the one membrane in the
# regime-load path, crossed at every regime kindle post-source pre-validate.
# Under BUBC_tweak_regime_poison, BURE_TWEAK_VALUE names one variable to
# corrupt: "VAR=value" sets, bare "VAR" unsets. Applies only when VAR carries
# this scope's prefix ("${z_scope}_"), so the poison rides inert through a
# dispatch's host regimes and lands exactly once, on its target — before the
# scope's enrollments, sentinel, vet, and lock ever see the environment.
# BURE_TWEAK_NAME is the optional test-seam slot, so its presence check is
# guarded. The poison name is a bubc tinder constant sourced at module top, so
# its reference stays unguarded — a typo dies under set -u rather than silently
# matching nothing. Any other tweak occupying the slot — notably the reveille-tier
# credless guard — compares unequal here and rides inert.
zbuv_poison_apply() {
  zbuv_sentinel
  local z_scope="${1:-}"
  test -n "${BURE_TWEAK_NAME:-}" || return 0
  test "${BURE_TWEAK_NAME}" = "${BUBC_tweak_regime_poison}" || return 0

  local z_spec="${BURE_TWEAK_VALUE:-}"
  test -n "${z_spec}" || buc_die_now "regime poison: BURE_TWEAK_VALUE required ('VAR=value' to set, 'VAR' to unset)"
  local -r z_var="${z_spec%%=*}"
  local -r z_name_lead="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
  [[ "${z_var}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] \
    || buc_die_now "regime poison: invalid variable name '${z_var}'"
  case "${z_var}" in
    [ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) : ;;
    *) buc_die_now "regime poison: invalid variable name '${z_var}'" ;;
  esac

  case "${z_var}" in
    "${z_scope}_"*) : ;;
    *) return 0 ;;
  esac

  # The set form assigns without the export attribute, as the file the poison
  # stands in for would, so the scope sentinel's exported-name rule never
  # refuses the seam's own poison. printf -v assigns at global scope where a
  # declare inside this function would scope the name local.
  if test "${z_spec}" = "${z_var}"; then
    unset "${z_var}" || buc_die_now "regime poison: cannot unset ${z_var}"
    buc_log_args "regime poison: unset ${z_var} (scope ${z_scope})"
  else
    printf -v "${z_var}" '%s' "${z_spec#*=}" || buc_die_now "regime poison: cannot set ${z_var}"
    buc_log_args "regime poison: set ${z_var} (scope ${z_scope})"
  fi
}

# buv_regime_enroll SCOPE — set current enrollment scope
# Validates that SCOPE is non-empty. All subsequent enroll calls use this scope
# until another buv_regime_enroll is called.
buv_regime_enroll() {
  zbuv_sentinel

  local z_scope="${1:-}"
  test -n "${z_scope}" || buc_die_now "buv_regime_enroll: scope required"
  z_buv_current_scope="${z_scope}"
  z_buv_current_group=""
  z_buv_current_group_idx=-1
  z_buv_current_gate_var=""
  z_buv_current_gate_val=""

  zbuv_poison_apply "${z_scope}"
}

# buv_koine_enroll CARRIER — declare the current scope a koine handed to docker compose
# Compose decodes CARRIER as its env file under a grammar of its own, and no
# reference fixes where compose resolves a ${ reference, so buv_vet refuses any
# carrier line carrying one. The declaration is the regime's, never a field's.
buv_koine_enroll() {
  zbuv_sentinel

  test -n "${z_buv_current_scope}" || buc_die_now "buv_koine_enroll: call buv_regime_enroll first"

  local -r z_carrier="${1:-}"
  test -n "${z_carrier}" || buc_die_now "buv_koine_enroll: carrier required"
  test -f "${z_carrier}" || buc_die_now "buv_koine_enroll: carrier not found: ${z_carrier}"

  z_buv_koine_scope_roll+=("${z_buv_current_scope}")
  z_buv_koine_carrier_roll+=("${z_carrier}")
}

# buv_group_enroll TITLE — set current group context
# Creates a group registry entry. All subsequent enroll calls are tagged with
# this group title until the next buv_group_enroll call.
# Resets gate context — use buv_gate_enroll after this to gate items.
buv_group_enroll() {
  zbuv_sentinel

  test -n "${z_buv_current_scope}" || buc_die_now "buv_group_enroll: call buv_regime_enroll first"

  local z_title="${1:-}"
  test -n "${z_title}" || buc_die_now "buv_group_enroll: title required"

  z_buv_grp_scope_roll+=("${z_buv_current_scope}")
  z_buv_grp_title_roll+=("${z_title}")
  z_buv_grp_gate_var_roll+=("")
  z_buv_grp_gate_val_roll+=("")

  z_buv_current_group="${z_title}"
  z_buv_current_group_idx=$(( ${#z_buv_grp_scope_roll[@]} - 1 ))
  z_buv_current_gate_var=""
  z_buv_current_gate_val=""
}

# buv_gate_enroll GATE_VAR GATE_VAL — set gate context within current group
# All subsequent variable enrolls in this group are gated by this condition.
# Also registers the gate on the current group for render section headers.
buv_gate_enroll() {
  zbuv_sentinel

  test -n "${z_buv_current_group}" || buc_die_now "buv_gate_enroll: call buv_group_enroll first"

  local z_gate_var="${1:-}"
  local z_gate_val="${2:-}"
  test -n "${z_gate_var}" || buc_die_now "buv_gate_enroll: gate variable required"
  test -n "${z_gate_val}" || buc_die_now "buv_gate_enroll: gate value required"

  z_buv_current_gate_var="${z_gate_var}"
  z_buv_current_gate_val="${z_gate_val}"

  z_buv_grp_gate_var_roll[z_buv_current_group_idx]="${z_gate_var}"
  z_buv_grp_gate_val_roll[z_buv_current_group_idx]="${z_gate_val}"
}

# Internal enrollment helper — all public enroll functions delegate here
# Usage: zbuv_enroll VARNAME TYPE P1 P2 DESC
# Gate context inherited from buv_gate_enroll; group from buv_group_enroll.
zbuv_enroll() {
  zbuv_sentinel

  local z_varname="${1:-}"
  local z_type="${2:-}"
  local z_p1="${3:-}"
  local z_p2="${4:-}"
  local z_desc="${5:-}"

  test -n "${z_buv_current_scope}" || buc_die_now "zbuv_enroll: call buv_regime_enroll first"
  [[ "${z_varname}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || buc_die_now "zbuv_enroll: invalid variable name: '${z_varname}'"

  z_buv_scope_roll+=("${z_buv_current_scope}")
  z_buv_varname_roll+=("${z_varname}")
  z_buv_type_roll+=("${z_type}")
  z_buv_gate_var_roll+=("${z_buv_current_gate_var}")
  z_buv_gate_val_roll+=("${z_buv_current_gate_val}")
  z_buv_p1_roll+=("${z_p1}")
  z_buv_p2_roll+=("${z_p2}")
  z_buv_group_roll+=("${z_buv_current_group}")
  z_buv_desc_roll+=("${z_desc}")
}

# Public enrollment functions — scalar types
#
# Signature: buv_TYPE_enroll VARNAME P1 P2 "description"
# Scope from buv_regime_enroll; group from buv_group_enroll; gate from buv_gate_enroll.

buv_string_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "string" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_secret_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "secret" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_xname_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "xname" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_gname_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "gname" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_fqin_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "fqin" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_bool_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "bool" "" "" "${z_desc}"
}

buv_enum_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  test "$#" -lt 2 || shift 2
  zbuv_enroll "${z_varname}" "enum" "$*" "" "${z_desc}"
}

buv_decimal_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "decimal" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_odref_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "odref" "" "" "${z_desc}"
}

buv_ipv4_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "ipv4" "" "" "${z_desc}"
}

buv_port_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "port" "" "" "${z_desc}"
}

# Public enrollment functions — list types

buv_list_string_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "list_string" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_list_ipv4_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "list_ipv4" "" "" "${z_desc}"
}

buv_list_gname_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_p1="${2:-}"
  local z_p2="${3:-}"
  local z_desc="${4:-}"
  zbuv_enroll "${z_varname}" "list_gname" "${z_p1}" "${z_p2}" "${z_desc}"
}

buv_list_cidr_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "list_cidr" "" "" "${z_desc}"
}

buv_list_domain_enroll() {
  zbuv_sentinel
  local z_varname="${1:-}"
  local z_desc="${2:-}"
  zbuv_enroll "${z_varname}" "list_domain" "" "" "${z_desc}"
}

# Internal check capture — validates a single enrolled variable by roll index.
# Returns error detail on stdout (empty = pass), written once at the end.
# Writes "${BUV_check_gated}" when gate doesn't match (caller decides skip behavior).
# Writes "${BUV_check_fail}<detail>" on validation failure.
zbuv_check_capture() {
  zbuv_sentinel

  local -r z_idx="${1:-}"
  case "${z_idx}" in ''|*[!0123456789]*) return 1 ;; esac
  local -r z_varname="${z_buv_varname_roll[10#${z_idx}]}"
  local -r z_type="${z_buv_type_roll[10#${z_idx}]}"
  local -r z_gate_var="${z_buv_gate_var_roll[10#${z_idx}]}"
  local -r z_gate_val="${z_buv_gate_val_roll[10#${z_idx}]}"
  local -r z_p1="${z_buv_p1_roll[10#${z_idx}]}"
  local -r z_p2="${z_buv_p2_roll[10#${z_idx}]}"

  local -r z_name_lead="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
  [[ "${z_varname}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] || return 1
  local z_gate_actual=""
  if test -n "${z_gate_var}"; then
    [[ "${z_gate_var}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] || return 1
    z_gate_actual="${!z_gate_var:-}"
  fi

  # One IPv4 octet, 0 to 255 with no leading zero, so a value this gate admits
  # reads the same under any arithmetic that consumes it. The digits are spelled
  # out because a range follows the locale's collation.
  local -r z_octet_re='(25[012345]|2[01234][0123456789]|1[0123456789][0123456789]|[123456789][0123456789]|[0123456789])'
  local -r z_ipv4_re='^('"${z_octet_re}"'\.){3}'"${z_octet_re}"'$'
  local -r z_cidr_re='^('"${z_octet_re}"'\.){3}'"${z_octet_re}"'/([0123456789]|[12][0123456789]|3[012])$'

  local z_verdict=""
  local z_val=""
  local z_items=()
  local z_ii=0
  local z_item=""
  local z_item_num=0
  local z_read_status=0

  if test -n "${z_gate_var}" && test "${z_gate_actual}" != "${z_gate_val}"; then
    # Gating check — gated and the gate doesn't match: skip (pass)
    z_verdict="${BUV_check_gated}"
  elif test -z "${!z_varname+x}"; then
    # Unset detection — distinguish "not set" from "set but empty".
    # A min-0 scalar (string|secret|gname|fqin) and every list type pass when
    # unset: an omitted line reads as a declared vacancy, uniformly across the
    # four scalar types. A min-1 field that is unset fails loud. Set-empty is
    # handled per-type below.
    case "${z_type}" in
      string|secret|gname|fqin)
        test "${z_p1}" = "0" || z_verdict="${BUV_check_fail}${z_varname} is not set (missing from .env?)" ;;
      list_string|list_ipv4|list_gname|list_cidr|list_domain)
        : ;;
      *)
        z_verdict="${BUV_check_fail}${z_varname} is not set (missing from .env?)" ;;
    esac
  else
    z_val="${!z_varname:-}"
    case "${z_type}" in
      list_string|list_ipv4|list_gname|list_cidr|list_domain)
        # The whole value is read, every line of it, and split into words.
        read -r -d '' -a z_items <<< "${z_val}" || z_read_status=$?
        test "${z_read_status}" -le 1 || return 1
        ;;
    esac

    case "${z_type}" in

      string|secret)
        if test "${z_p1}" = "0" && test -z "${z_val}"; then
          :
        elif test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif test "${#z_val}" -lt "${z_p1}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be at least ${z_p1} chars, got '${z_val}' (${#z_val})"
        elif test "${#z_val}" -gt "${z_p2}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be no more than ${z_p2} chars, got '${z_val}' (${#z_val})"
        fi
        ;;

      xname)
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif test "${#z_val}" -lt "${z_p1}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be at least ${z_p1} chars, got '${z_val}' (${#z_val})"
        elif test "${#z_val}" -gt "${z_p2}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be no more than ${z_p2} chars, got '${z_val}' (${#z_val})"
        elif ! [[ "${z_val}" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
          z_verdict="${BUV_check_fail}${z_varname} must start with letter and contain only letters, numbers, underscore, hyphen, got '${z_val}'"
        fi
        ;;

      gname)
        if test -z "${z_val}"; then
          if test "${z_p1}" -gt 0; then
            z_verdict="${BUV_check_fail}${z_varname} must not be empty"
          fi
        elif test "${#z_val}" -lt "${z_p1}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be at least ${z_p1} chars, got '${z_val}' (${#z_val})"
        elif test "${#z_val}" -gt "${z_p2}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be no more than ${z_p2} chars, got '${z_val}' (${#z_val})"
        elif ! [[ "${z_val}" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
          z_verdict="${BUV_check_fail}${z_varname} must match ^[a-z][a-z0-9-]*[a-z0-9]$ (lowercase letters, digits, hyphens; start with a letter; end with letter/digit), got '${z_val}'"
        fi
        ;;

      fqin)
        if test -z "${z_val}"; then
          if test "${z_p1}" -gt 0; then
            z_verdict="${BUV_check_fail}${z_varname} must not be empty"
          fi
        elif test "${#z_val}" -lt "${z_p1}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be at least ${z_p1} chars, got '${z_val}' (${#z_val})"
        elif test "${#z_val}" -gt "${z_p2}"; then
          z_verdict="${BUV_check_fail}${z_varname} must be no more than ${z_p2} chars, got '${z_val}' (${#z_val})"
        elif ! [[ "${z_val}" =~ ^[a-zA-Z0-9][a-zA-Z0-9:._/@-]*$ ]]; then
          z_verdict="${BUV_check_fail}${z_varname} must start with letter/number and contain only letters, numbers, colons, dots, underscores, hyphens, forward slashes, at-signs, got '${z_val}'"
        fi
        ;;

      bool)
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif test "${z_val}" != "0" && test "${z_val}" != "1"; then
          z_verdict="${BUV_check_fail}${z_varname} must be 0 or 1, got: '${z_val}'"
        fi
        ;;

      enum)
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        else
          local z_choices=()
          read -r -a z_choices <<< "${z_p1}" || return 1
          local z_ci=0
          local z_found=0
          for z_ci in "${!z_choices[@]}"; do
            test "${z_val}" != "${z_choices[${z_ci}]}" || z_found=1
          done
          test "${z_found}" = "1" || z_verdict="${BUV_check_fail}${z_varname} must be one of: ${z_p1}, got '${z_val}'"
        fi
        ;;

      decimal)
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif test "${z_val}" -ge "${z_p1}" && test "${z_val}" -le "${z_p2}"; then
          :
        else
          z_verdict="${BUV_check_fail}${z_varname} value '${z_val}' must be between ${z_p1} and ${z_p2}"
        fi
        ;;

      odref)
        local -r z_re='^[a-z0-9.-]+(:[0-9]{2,5})?/([a-z0-9._-]+/)*[a-z0-9._-]+@sha256:[0-9a-f]{64}$'
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif ! [[ "${z_val}" =~ ${z_re} ]]; then
          z_verdict="${BUV_check_fail}${z_varname} has invalid image reference format (require host[:port]/repo@sha256:<64hex>), got '${z_val}'"
        fi
        ;;

      ipv4)
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif ! [[ "${z_val}" =~ ${z_ipv4_re} ]]; then
          z_verdict="${BUV_check_fail}${z_varname} has invalid IPv4 format (four octets of 0 to 255, no leading zero): '${z_val}'"
        fi
        ;;

      port)
        if test -z "${z_val}"; then
          z_verdict="${BUV_check_fail}${z_varname} must not be empty"
        elif test "${z_val}" -ge 1 && test "${z_val}" -le 65535; then
          :
        else
          z_verdict="${BUV_check_fail}${z_varname} value '${z_val}' must be between 1 and 65535"
        fi
        ;;

      list_string)
        for z_ii in "${!z_items[@]}"; do
          z_item="${z_items[${z_ii}]}"
          z_item_num=$((z_item_num + 1))
          if test "${#z_item}" -lt "${z_p1}"; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} must be at least ${z_p1} chars, got '${z_item}' (${#z_item})"
            break
          fi
          if test "${#z_item}" -gt "${z_p2}"; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} must be no more than ${z_p2} chars, got '${z_item}' (${#z_item})"
            break
          fi
        done
        ;;

      list_ipv4)
        for z_ii in "${!z_items[@]}"; do
          z_item="${z_items[${z_ii}]}"
          z_item_num=$((z_item_num + 1))
          if ! [[ "${z_item}" =~ ${z_ipv4_re} ]]; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} has invalid IPv4 format (four octets of 0 to 255, no leading zero): '${z_item}'"
            break
          fi
        done
        ;;

      list_gname)
        for z_ii in "${!z_items[@]}"; do
          z_item="${z_items[${z_ii}]}"
          z_item_num=$((z_item_num + 1))
          if test "${#z_item}" -lt "${z_p1}"; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} must be at least ${z_p1} chars, got '${z_item}' (${#z_item})"
            break
          fi
          if test "${#z_item}" -gt "${z_p2}"; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} must be no more than ${z_p2} chars, got '${z_item}' (${#z_item})"
            break
          fi
          if ! [[ "${z_item}" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} must match ^[a-z][a-z0-9-]*[a-z0-9]$, got '${z_item}'"
            break
          fi
        done
        ;;

      list_cidr)
        for z_ii in "${!z_items[@]}"; do
          z_item="${z_items[${z_ii}]}"
          z_item_num=$((z_item_num + 1))
          if ! [[ "${z_item}" =~ ${z_cidr_re} ]]; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} has invalid CIDR format (four octets of 0 to 255, no leading zero, prefix 0 to 32): '${z_item}'"
            break
          fi
        done
        ;;

      list_domain)
        for z_ii in "${!z_items[@]}"; do
          z_item="${z_items[${z_ii}]}"
          z_item_num=$((z_item_num + 1))
          if ! [[ "${z_item}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            z_verdict="${BUV_check_fail}${z_varname} item #${z_item_num} has invalid domain format: '${z_item}'"
            break
          fi
        done
        ;;

      *)
        z_verdict="${BUV_check_fail}unknown type: ${z_type}"
        ;;

    esac
  fi

  printf '%s' "${z_verdict}"
}

# buv_hallmark_format VALUE — validate hallmark string matches [cbg]YYMMDDHHMMSS-rYYMMDDHHMMSS
# Returns 0 on valid, dies on invalid. Pass empty string to skip (optional fields).
buv_hallmark_format() {
  zbuv_sentinel
  local z_val="${1:-}"
  test -n "${z_val}" || return 0
  [[ "${z_val}" =~ ^[cbg][0-9]{12}-r[0-9]{12}$ ]] \
    || buc_die_now "Invalid hallmark format: '${z_val}' (expected [cbg]YYMMDDHHMMSS-rYYMMDDHHMMSS)"
}

# buv_scope_sentinel SCOPE PREFIX — die if any PREFIX_ vars exist that are not enrolled in SCOPE,
# or if any stands exported that is no hand-off (the exported-name rule)
# Usage: buv_scope_sentinel RBRN RBRN_
buv_scope_sentinel() {
  zbuv_sentinel

  local z_scope="${1:-}"
  local z_prefix="${2:-}"
  test -n "${z_scope}"  || buc_die_now "buv_scope_sentinel: scope required"
  test -n "${z_prefix}" || buc_die_now "buv_scope_sentinel: prefix required"

  # Build lookup string from enrolled varnames for this scope
  local z_known=" "
  local z_i
  for z_i in "${!z_buv_scope_roll[@]}"; do
    test "${z_buv_scope_roll[${z_i}]}" = "${z_scope}" || continue
    z_known="${z_known}${z_buv_varname_roll[${z_i}]} "
  done

  # Scan environment for unexpected vars with this prefix
  # compgen answers 1 where no variable wears the prefix, which leaves the
  # listing empty and nothing to scan; any other status is a failure. This runs
  # at regime validation, ahead of any temp directory, so the listing is held in
  # memory: variable names carry no whitespace, so one line split by read holds
  # them all.
  local z_listing=""
  local z_listing_status=0
  z_listing=$(compgen -v "${z_prefix}") || z_listing_status=$?
  test "${z_listing_status}" -le 1 || buc_die_now "buv_scope_sentinel: could not list the ${z_prefix} variables"
  local -r z_newline=$'\n'
  local -r z_line="${z_listing//"${z_newline}"/ }"
  local z_names=()
  read -r -a z_names <<< "${z_line}" || buc_die_now "buv_scope_sentinel: could not split the ${z_prefix} listing"
  local z_unexpected=()
  local z_n
  for z_n in "${!z_names[@]}"; do
    case "${z_known}" in
      *" ${z_names[${z_n}]} "*) : ;;
      *) z_unexpected+=("${z_names[${z_n}]}") ;;
    esac
  done

  if test "${#z_unexpected[@]}" -gt 0; then
    buc_reject "${BUBG_ENROLL_DENTIL}" "Unexpected ${z_prefix}* variables not enrolled in ${z_scope}: ${z_unexpected[*]}"
  fi

  # The second rule: a name of this scope standing exported is refused save the
  # hand-offs every level declares. The door is named where this process runs
  # under one, its dispatch file having been read before any kindle.
  zbuv_exported_rule "${z_prefix}" "${BURD_TARGET:+${BURD_TARGET}, at }the ${z_scope} ${BUBG_BUKRO_KINDLE_PROSOPON}" ""
}

# buv_export_sentinel DOOR [ADMITTED] — the exported-name rule at a process's entry
# Applies the scope sentinel's second rule over every family the kit speaks
# across an exec. A launcher's entry, each workbench's head and buc_execute call
# it; ADMITTED is the hand-offs that level declares beside those every level
# declares, space-separated, a word ending in an underscore admitting its family.
buv_export_sentinel() {
  buc_doc_brief "Refuse a name of the kit standing exported that this level declares no hand-off for"
  buc_doc_param "door" "The ${BUBG_TABTARGET_BASE} basename the refusal names"
  buc_doc_oparm "admitted" "The hand-offs this level declares beside every level's, space-separated"
  buc_doc_shown || return 0

  zbuv_sentinel

  local -r z_door="${1:-}"
  local -r z_admitted="${2:-}"
  test -n "${z_door}" || buc_die_now "buv_export_sentinel: door required"

  local z_family=""
  for z_family in BURC_ BURS_ BURD_ BURE_ BURV_ BURX_ BUZ_ BUC_; do
    zbuv_exported_rule "${z_family}" "${z_door}" "${z_admitted}"
  done
}

# zbuv_exported_rule PREFIX WHERE ADMITTED — reject the first name wearing PREFIX
# that stands exported in this process and is no hand-off
# The listing is compgen -e: a name that arrived exported keeps its listing after
# a sourced file reassigns it, so the rule reads the inheritance, never the file.
# Every level admits the environment regime, the pointer and the kit directory;
# ADMITTED names what a level declares beside them, a word ending in an
# underscore admitting its family.
zbuv_exported_rule() {
  zbuv_sentinel

  local -r z_prefix="${1:-}"
  local -r z_where="${2:-}"
  local -r z_admitted="${3:-}"
  test -n "${z_prefix}" || buc_die_now "zbuv_exported_rule: prefix required"

  local z_listing=""
  local z_listing_status=0
  z_listing=$(compgen -e "${z_prefix}") || z_listing_status=$?
  test "${z_listing_status}" -le 1 || buc_die_now "zbuv_exported_rule: could not list the exported ${z_prefix} variables"
  local -r z_newline=$'\n'
  local -r z_line="${z_listing//"${z_newline}"/ }"
  local z_names=()
  read -r -a z_names <<< "${z_line}" || buc_die_now "zbuv_exported_rule: could not split the exported ${z_prefix} listing"
  test "${#z_names[@]}" -gt 0 || return 0

  local z_words=()
  read -r -a z_words <<< "${z_admitted}" || buc_die_now "zbuv_exported_rule: could not split the admitted hand-offs"

  local z_n=""
  local z_w=""
  local z_handed=""
  for z_n in "${!z_names[@]}"; do
    z_handed=""
    case "${z_names[${z_n}]}" in
      BURE_*|BURD_BURD_FILE|BURD_BUK_DIR) z_handed=1 ;;
    esac
    if test -z "${z_handed}" && test "${#z_words[@]}" -gt 0; then
      for z_w in "${!z_words[@]}"; do
        case "${z_words[${z_w}]}" in
          *_) case "${z_names[${z_n}]}" in "${z_words[${z_w}]}"*) z_handed=1 ;; esac ;;
          *)  test "${z_names[${z_n}]}" != "${z_words[${z_w}]}" || z_handed=1 ;;
        esac
      done
    fi
    test -z "${z_handed}" || continue
    buc_reject "${BUBG_ENROLL_DENTIL}" "${z_names[${z_n}]} arrives exported at ${z_where}, and no value of the kit crosses an exec by inheritance save a hand-off its level declares (the exported-name rule)"
  done
}

# buv_vet SCOPE — iterate all enrolled vars in scope; reject on first failure
# A failed value check is the buv enrollment-validation gate firing — it
# rejects with BUBG_ENROLL_DENTIL so negative tests can assert WHICH layer
# refused (the band expansion is unguarded on purpose: a vet failure without
# the bubc tinder dies loud, never soft).
buv_vet() {
  zbuv_sentinel

  local z_scope="${1:-}"
  test -n "${z_scope}" || buc_die_now "buv_vet: scope required"

  local z_i
  local z_err
  for z_i in "${!z_buv_scope_roll[@]}"; do
    test "${z_buv_scope_roll[${z_i}]}" = "${z_scope}" || continue
    z_err=$(zbuv_check_capture "${z_i}") || buc_die_now "buv_vet: could not check ${z_buv_varname_roll[${z_i}]}"
    test -z "${z_err}" || test "${z_err}" = "${BUV_check_gated}" || buc_reject "${BUBG_ENROLL_DENTIL}" "${z_buv_varname_roll[${z_i}]}: ${z_err#"${BUV_check_fail}"}"
  done

  for z_i in "${!z_buv_koine_scope_roll[@]}"; do
    test "${z_buv_koine_scope_roll[${z_i}]}" = "${z_scope}" || continue
    zbuv_koine_vet "${z_scope}" "${z_buv_koine_carrier_roll[${z_i}]}"
  done
}

# zbuv_koine_vet SCOPE CARRIER — refuse a koine carrier any line of which carries a ${ reference
# The carrier's text is read because bash expanded every reference when it
# sourced the carrier, so no sourced value still shows one. The read takes no
# value from the text: it names the field before a line's first '=' and nothing
# more, and a blank line or a comment line is no value to either reader.
zbuv_koine_vet() {
  zbuv_sentinel

  local -r z_scope="${1:-}"
  local -r z_carrier="${2:-}"
  test -n "${z_scope}"   || buc_die_now "zbuv_koine_vet: scope required"
  test -f "${z_carrier}" || buc_die_now "zbuv_koine_vet: carrier not found: ${z_carrier}"

  local z_lines=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_lines+=("${z_line}")
  done < "${z_carrier}" || buc_die_now "zbuv_koine_vet: could not read ${z_carrier}"

  local z_fields=()
  local z_bare=""
  local z_n=""
  for z_n in "${!z_lines[@]}"; do
    z_bare="${z_lines[${z_n}]#"${z_lines[${z_n}]%%[![:space:]]*}"}"
    case "${z_bare}" in
      ''|'#'*) continue ;;
      *'${'*)  z_fields+=("${z_bare%%=*}") ;;
    esac
  done

  if test "${#z_fields[@]}" -gt 0; then
    buc_reject "${BUBG_ENROLL_DENTIL}" "Regime ${z_scope} is handed to docker compose and carries a \${ reference in: ${z_fields[*]}"
  fi
}

# buv_lock SCOPE — make all enrolled variables in scope readonly
# Call after enforce succeeds. Prevents downstream mutation of validated config.
buv_lock() {
  zbuv_sentinel

  local -r z_scope="${1:-}"
  test -n "${z_scope}" || buc_die_now "buv_lock: scope required"

  local z_i
  for z_i in "${!z_buv_scope_roll[@]}"; do
    test "${z_buv_scope_roll[${z_i}]}" = "${z_scope}" || continue
    readonly "${z_buv_varname_roll[${z_i}]}"
  done
}

buv_export_and_lock() {
  zbuv_sentinel

  local -r z_scope="${1:-}"
  test -n "${z_scope}" || buc_die_now "buv_export_and_lock: scope required"

  local z_i
  for z_i in "${!z_buv_scope_roll[@]}"; do
    test "${z_buv_scope_roll[${z_i}]}" = "${z_scope}" || continue
    export "${z_buv_varname_roll[${z_i}]}"
    readonly "${z_buv_varname_roll[${z_i}]}"
  done
}

# buv_report SCOPE "Label" — rich per-variable display; returns non-zero if any failed
buv_report() {
  zbuv_sentinel

  local z_scope="${1:-}"
  local z_label="${2:-}"
  test -n "${z_scope}" || buc_die_now "buv_report: scope required"
  test -n "${z_label}" || buc_die_now "buv_report: label required"

  local z_any_failed=0
  local -r z_name_lead="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"

  buc_step "${z_label}"

  local z_i
  for z_i in "${!z_buv_scope_roll[@]}"; do
    test "${z_buv_scope_roll[${z_i}]}" = "${z_scope}" || continue

    local z_varname="${z_buv_varname_roll[${z_i}]}"
    local z_type="${z_buv_type_roll[${z_i}]}"
    local z_desc="${z_buv_desc_roll[${z_i}]}"
    [[ "${z_varname}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] \
      || buc_die_now "buv_report: invalid variable name: '${z_varname}'"
    local z_val="${!z_varname:-}"
    local z_err

    # Secret redaction — replace display value before PASS/FAIL output
    local z_display_val="${z_val}"
    if test "${z_type}" = "secret" && test -n "${z_val}"; then
      z_display_val="(redacted — ${#z_val} chars)"
    fi

    z_err=$(zbuv_check_capture "${z_i}") || buc_die_now "Could not check ${z_varname}"
    if test -z "${z_err}"; then
      zbuv_req_status "${z_i}"
      if test "${z_buv_req_status}" = "opt" && test -z "${z_val}"; then
        buc_step "  VACANT  ${z_varname} [${z_type}] (${z_desc})"
      else
        buc_step "  PASS  ${z_varname}=${z_display_val} [${z_type}]"
      fi
    elif test "${z_err}" = "${BUV_check_gated}"; then
      buc_step "  SKIP  ${z_varname} (gated)"
    else
      buc_step "  FAIL  ${z_varname}=${z_display_val} [${z_type}]: ${z_err#"${BUV_check_fail}"}"
      z_any_failed=1
    fi
  done

  return "${z_any_failed}"
}

# zbuv_req_status INDEX — derive req/opt/cond from enrollment data
# Sets z_buv_req_status.
zbuv_req_status() {
  zbuv_sentinel
  local -r z_idx="${1:-}"
  case "${z_idx}" in ''|*[!0123456789]*) buc_die_now "zbuv_req_status: index must be digits, got '${z_idx}'" ;; esac
  local -r z_gate_var="${z_buv_gate_var_roll[10#${z_idx}]}"
  local -r z_p1="${z_buv_p1_roll[10#${z_idx}]}"

  if test -n "${z_gate_var}"; then
    z_buv_req_status="cond"
  elif test "${z_p1}" = "0"; then
    z_buv_req_status="opt"
  else
    z_buv_req_status="req"
  fi
}

# buv_render SCOPE "Label" [FILE_PATH] — render all enrolled vars via bupr_ presentation
# Walks enrollment rolls grouped by group, applying group-level gates.
# Optional FILE_PATH displays a gray "File: <path>" line under the title; empty/omitted skips it.
# Requires bupr (PresentationRegime) to be kindled.
buv_render() {
  zbuv_sentinel
  zbupr_sentinel
  # buym's sentinel kindles it lazily, and the BUYC_* reads below expand before
  # any callee's guard can run, so the kindle is forced here.  Where it stands
  # no longer decides the color verdict: buym's configurators re-resolve the
  # palette, so a later buym_unconditional reaches it whenever it is called.
  zbuym_sentinel

  local z_scope="${1:-}"
  local z_label="${2:-}"
  local z_file_path="${3:-}"
  test -n "${z_scope}" || buc_die_now "buv_render: scope required"
  test -n "${z_label}" || buc_die_now "buv_render: label required"

  local z_current_group=""
  local z_i
  local z_group=""
  local z_varname=""
  local z_type=""
  local z_desc=""
  local z_grp_gate_var=""
  local z_grp_gate_val=""
  local z_s=""

  echo "" || buc_die_now
  buym_format_yawp "${BUYC_BRIGHT_WHITE}" "${z_label}"; local -r z_title_line="${z_buym_format}"
  echo "${z_title_line}" || buc_die_now
  if test -n "${z_file_path}"; then
    buym_format_yawp "${BUYC_GRAY}" "File: ${z_file_path}"; local -r z_file_line="${z_buym_format}"
    echo "  ${z_file_line}" || buc_die_now
  fi
  echo "" || buc_die_now

  for z_i in "${!z_buv_scope_roll[@]}"; do
    test "${z_buv_scope_roll[${z_i}]}" = "${z_scope}" || continue

    z_group="${z_buv_group_roll[${z_i}]}"
    z_varname="${z_buv_varname_roll[${z_i}]}"
    z_type="${z_buv_type_roll[${z_i}]}"
    z_desc="${z_buv_desc_roll[${z_i}]}"

    # Group transition — close previous, open new
    if test "${z_group}" != "${z_current_group}"; then
      if test -n "${z_current_group}"; then
        bupr_section_end
      fi
      z_current_group="${z_group}"

      # The group's gate, looked up in the group registry (empty if ungated)
      z_grp_gate_var=""
      z_grp_gate_val=""
      for z_s in "${!z_buv_grp_scope_roll[@]}"; do
        test "${z_buv_grp_scope_roll[${z_s}]}" = "${z_scope}" || continue
        test "${z_buv_grp_title_roll[${z_s}]}" = "${z_group}" || continue
        z_grp_gate_var="${z_buv_grp_gate_var_roll[${z_s}]}"
        z_grp_gate_val="${z_buv_grp_gate_val_roll[${z_s}]}"
        break
      done
      if test -n "${z_grp_gate_var}"; then
        bupr_section_begin "${z_group}" "${z_grp_gate_var}" "${z_grp_gate_val}"
      else
        bupr_section_begin "${z_group}"
      fi
    fi

    zbuv_req_status "${z_i}"
    bupr_section_item "${z_varname}" "${z_type}" "${z_buv_req_status}" "${z_desc}"
  done

  # Close final group
  if test -n "${z_current_group}"; then
    bupr_section_end
  fi
}

# eof

