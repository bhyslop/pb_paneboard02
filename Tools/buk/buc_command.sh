#!/bin/bash
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
# Bash Console Utility Library

set -euo pipefail

# Multiple inclusion guard
test -z "${ZBUC_INCLUDED:-}" || return 0
ZBUC_INCLUDED=1

# Color tinder constants (pure ANSI-C quoted literals — no computation, no $())
BUC_black=$'\033[1;30m'
BUC_red=$'\033[1;31m'
BUC_green=$'\033[1;32m'
BUC_yellow=$'\033[1;33m'
BUC_blue=$'\033[1;34m'
BUC_magenta=$'\033[1;35m'
BUC_cyan=$'\033[1;36m'
BUC_white=$'\033[1;37m'
BUC_gray=$'\033[90m'
BUC_reset=$'\033[0m'

# Global context variable for info and error messages
ZBUC_CONTEXT=""

# Help mode flag
ZBUC_DOC_MODE=false


######################################################################
# Internal logging helpers

# Usage: zbuc_make_tag <depth> "<label>"
#   Computes ZBUC_TAG for the given stack depth/label (no I/O).
# Usage: zbuc_tag_args <depth> "<label>" [arg...]
#   Computes ZBUC_TAG and logs args directly to the transcript.
#
# Bash stack quirk:
#   BASH_SOURCE[i] / FUNCNAME[i] index the current frame,
#   but BASH_LINENO[i] reports the line where FUNCNAME[i+1] was called.
#   For depth=N callers:
#       file = BASH_SOURCE[N]
#       line = BASH_LINENO[N-1]
# Usage: zbuc_make_tag <depth> "<label>"
#   Computes ZBUC_TAG for the given stack depth/label (no I/O).
#   Note: With depth=0 or too-deep stacks, file/line may be empty (by design).
zbuc_make_tag() {
  local z_d="${1:-1}"
  case "${z_d}" in ''|*[!0-9]*) z_d=1 ;; esac
  local z_label="${2:-}"
  local z_file="${BASH_SOURCE[z_d]##*/}"
  local z_line="${BASH_LINENO[z_d-1]}"
  ZBUC_TAG="${z_label}${z_file}:${z_line}: "
}

zbuc_tag_args() {
  local z_d="${1:-1}"
  shift
  local z_label="${1:-}"
  shift
  zbuc_make_tag "${z_d}" "${z_label}"
  printf '%s\n' "$@" | zbuc_log "${ZBUC_TAG}" " ---- "
}

######################################################################
# Public logging wrappers

buc_log_args() { zbuc_tag_args 3 "buc_log_args " "$@"; }
buc_log_pipe() { zbuc_make_tag 3 "buc_log_pipe "; zbuc_log "${ZBUC_TAG}" " ---- "; }

buc_step()     { zbuc_tag_args 3 "buc_step     " "$@"; zbuc_print 0 "${BUC_white}$*${BUC_reset}"; }
buc_code()     { zbuc_tag_args 3 "buc_code     " "$@"; zbuc_print 0 "${BUC_cyan}$*${BUC_reset}"; }
buc_info()     { zbuc_tag_args 3 "buc_info     " "$@"; zbuc_print 0 "$@"; }
buc_debug()    { zbuc_tag_args 3 "buc_debug    " "$@"; zbuc_print 2 "$@"; }
buc_trace()    { zbuc_tag_args 3 "buc_trace    " "$@"; zbuc_print 3 "$@"; }
buc_warn()     { zbuc_tag_args 3 "buc_warn     " "$@"; zbuc_print 0 "${BUC_yellow}WARNING:${BUC_reset} $*"; }
buc_success()  { zbuc_tag_args 3 "buc_success  " "$@"; printf '%b\n' "${BUC_green}$*${BUC_reset}" >&2 || buc_die; }
buc_die() {
  zbuc_tag_args                3 "buc_die      " "ERROR: [${ZBUC_CONTEXT:-}] $*"
  zbuc_print -1          "${BUC_red}ERROR:${BUC_reset} [${ZBUC_CONTEXT:-}] $*"
  exit 1
}

# Display unprefixed cyan text for typeable guidance (commands, config values)
buc_bare() { zbuc_tag_args 3 "buc_bare     " "$@"; printf '%b\n' "${BUC_cyan}$*${BUC_reset}" >&2; }

# Display tabtarget hint: resolves colophon to tabtarget filename
# Args: colophon [extra_args...]
buc_tabtarget() {
  local z_colophon="$1"
  shift
  local z_extra="${*:+ $*}"
  local z_matches=("${BURD_TABTARGET_DIR}"/${z_colophon}.*)
  test -e "${z_matches[0]}" || buc_die "buc_tabtarget: no tabtarget found for colophon '${z_colophon}'"
  buc_bare "        ${z_matches[0]}${z_extra}"
}

buc_context() {
  ZBUC_CONTEXT="$1"
}

# Enable trace to stderr safely if supported
zbuc_enable_trace() {
  # Only supported in Bash >= 4.1
  if test "${BASH_VERSINFO[0]}" -gt 4 || { test "${BASH_VERSINFO[0]}" -eq 4 && test "${BASH_VERSINFO[1]}" -ge 1; }; then
    export BASH_XTRACEFD=2
  fi
  set -x
}

# Disable trace
zbuc_disable_trace() {
  set +x
}

zbuc_doc_mode_predicate() {
  test "${ZBUC_DOC_MODE}" = "true"
}

buc_doc_env() {
  set -e

  local env_var_name="${1}"
  local env_var_info="${2}"

  # Trim trailing spaces from variable name
  env_var_name="${env_var_name%% *}"

  # In doc mode, show documentation only (no validation — env vars may not be set)
  if zbuc_doc_mode_predicate; then
    echo "  ${BUC_magenta}${1}${BUC_reset}:  ${env_var_info}"
    return 0
  fi

  # In execute mode, validate variable is set
  test -n "${!env_var_name:-}" || buc_warn "${env_var_name} is not set"
}

# Idiomatic last step of environment documentation in furnish.
# In doc mode, signals furnish to return early (sourcing/kindle not needed for help).
# Usage:
#    buc_doc_env_done || return 0
buc_doc_env_done() {
  zbuc_doc_mode_predicate || return 0
  return 1
}

ZBUC_USAGE_STRING="UNFILLED"

buc_doc_brief() {
  set -e
  ZBUC_USAGE_STRING="${ZBUC_CONTEXT}"
  zbuc_doc_mode_predicate || return 0
  echo
  echo "  ${BUC_white}${ZBUC_CONTEXT}${BUC_reset}"
  echo "    brief: $1"
}

buc_doc_lines() {
  set -e
  zbuc_doc_mode_predicate || return 0
  echo "           $1"
}

buc_doc_param() {
  set -e
  ZBUC_USAGE_STRING="${ZBUC_USAGE_STRING} <<$1>>"
  zbuc_doc_mode_predicate || return 0
  echo "    required: $1 - $2"
}

buc_doc_oparm() {
  set -e
  ZBUC_USAGE_STRING="${ZBUC_USAGE_STRING} [<<$1>>]"
  zbuc_doc_mode_predicate || return 0
  echo "    optional: $1 - $2"
}

zbuc_usage() {
  printf '%b\n' "    usage: ${BUC_cyan}${ZBUC_USAGE_STRING}${BUC_reset}"
}

# Idiomatic last step of documentation in the bash api.
# Usage:
#    buc_doc_shown || return 0
buc_doc_shown() {
  zbuc_doc_mode_predicate || return 0
  zbuc_usage
  return 1
}

buc_set_doc_mode() {
  ZBUC_DOC_MODE=true
}

buc_usage_die() {
  set -e
  local context="${ZBUC_CONTEXT:-}"
  local usage=$(zbuc_usage)
  printf '%b\n' "${BUC_red}ERROR:${BUC_reset} ${usage}"
  exit 1
}

# Multi-line print function with verbosity control
# Sends output to stderr to avoid interfering with stdout returns
zbuc_print() {
  local min_verbosity="$1"
  shift

  # Always print if min_verbosity is -1, otherwise check BURE_VERBOSE
  if test "${min_verbosity}" -eq -1 || test "${BURE_VERBOSE:-0}" -ge "${min_verbosity}"; then
    while test $# -gt 0; do
      if test -n "${ZBUC_CONTEXT}"; then
        printf '%b%s%b %s\n' "${BUC_gray}" "${ZBUC_CONTEXT}" "${BUC_reset}" "$1" >&2
      else
        echo "$1" >&2
      fi
      shift
    done
  fi
}

# Core logging implementation - always reads from stdin
zbuc_log() {
  test -n "${BURD_TRANSCRIPT:-}" || return 0

  local z_prefix="$1"
  local z_rest_prefix="$2"
  local z_outfile="${BURD_TRANSCRIPT}"

  while IFS= read -r z_line; do
    printf '%s%s\n' "${z_prefix}" "${z_line}" >> "${z_outfile}"
    z_prefix="${z_rest_prefix}"
  done
}


# Die if condition is true (non-zero)
# Usage: buc_die_if <condition> <message1> [<message2> ...]
buc_die_if() {
  local condition="$1"
  shift

  test "${condition}" -ne 0 || return 0

  set -e
  local context="${ZBUC_CONTEXT:-}"
  zbuc_print -1 "${BUC_red}ERROR:${BUC_reset} [$context] $1"
  shift
  zbuc_print -1 "$@"
  exit 1
}

# Die unless condition is true (zero)
# Usage: buc_die_unless <condition> <message1> [<message2> ...]
buc_die_unless() {
  local condition="$1"
  shift

  test "${condition}" -eq 0 || return 0

  set -e
  local context="${ZBUC_CONTEXT:-}"
  zbuc_print -1 "${BUC_red}ERROR:${BUC_reset} [$context] $1"
  shift
  zbuc_print -1 "$@"
  exit 1
}

zbuc_show_help() {
  local prefix="$1"
  local title="$2"
  local env_func="$3"

  echo "$title"
  echo

  if test -n "${env_func}"; then
    echo "Environment Variables:"
    "$env_func"
    echo
  fi

  echo "Commands:"

  local z_decl z_flag z_cmd
  while read -r z_decl z_flag z_cmd; do
    [[ "${z_cmd}" =~ ^${prefix}[a-z][a-z0-9_]*$ ]] || continue
    buc_context "${z_cmd}"
    "${z_cmd}"
  done < <(declare -F)
}

buc_countdown() {
  local z_seconds="$1"
  local z_prompt="$2"

  if test "${BURE_COUNTDOWN:-}" = "skip"; then
    buc_step "Countdown: ${z_seconds}s (skipped — BURE_COUNTDOWN=skip)"
    return 0
  fi

  test -z "${BURE_COUNTDOWN:-}" || buc_die "BURE_COUNTDOWN must be 'skip' or unset, got '${BURE_COUNTDOWN}'"

  buc_step "Countdown: ${z_seconds}s to cancel (Ctrl-C)"
  sleep 1
  printf '%b ' "${BUC_yellow}${z_prompt}${BUC_reset}" >/dev/tty
  local z_i
  for (( z_i=z_seconds; z_i>=1; z_i-- )); do
    printf '%d... ' "$z_i" >/dev/tty
    sleep 1
  done
  printf '\n' >/dev/tty
}

buc_require() {
  local z_prompt="$1"
  local z_required_value="$2"

  if test "${BURE_CONFIRM:-}" = "skip"; then
    buc_step "Confirm: (skipped — BURE_CONFIRM=skip)"
    return 0
  fi

  test -z "${BURE_CONFIRM:-}" || buc_die "BURE_CONFIRM must be 'skip' or unset, got '${BURE_CONFIRM}'"

  sleep 1
  printf '%b\n' "${BUC_yellow}${z_prompt}${BUC_reset}" >&2
  printf 'Type %s to confirm: ' "${z_required_value}" >&2
  local z_input
  read -r z_input </dev/tty
  test "${z_input}" = "${z_required_value}" || buc_die "Confirmation failed — expected '${z_required_value}', got '${z_input}'"
}

buc_execute() {
  set -e
  local prefix="$1"
  local title="$2"
  local env_func="$3"
  local command="${4:-}"
  shift 3; test -z "${command}" || shift

  export BUC_VERBOSE="${BUC_VERBOSE:-0}"

  # Enable bash trace to stderr if BUC_VERBOSE is 3 or higher and bash >= 4.1
  if test "${BUC_VERBOSE}" -ge 3; then
    if test "${BASH_VERSINFO[0]}" -gt 4 || { test "${BASH_VERSINFO[0]}" -eq 4 && test "${BASH_VERSINFO[1]}" -ge 1; }; then
      export PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
      export BASH_XTRACEFD=2
      set -x
    fi
  fi

  # Validate prefix pattern, furnish deps, then dispatch command
  if test -n "${command}" && [[ "${command}" =~ ^${prefix}[a-z][a-z0-9_]*$ ]]; then
    buc_context "${command}"
    test -z "${env_func}" || "${env_func}" "${command}"
    declare -F "${command}" >/dev/null || buc_die "Function not found: ${command}"
    "${command}" "$@"
  else
    test -z "${command}" || buc_warn "Unknown command: ${command}"
    buc_set_doc_mode
    zbuc_show_help "${prefix}" "${title}" "${env_func}"
    echo
    exit 1
  fi
}

# --- Hyperlink helpers (OSC-8), falls back to plain text when disabled ---
# Disable with: export BURD_NO_HYPERLINKS=1
zbuc_hyperlink() {
  local z_text="${1:-}"
  local z_url="${2:-}"

  # ANSI codes for blue underlined text
  local z_blue_underline=$'\033[34m\033[4m'
  local z_reset=$'\033[0m'

  if test -n "${BURD_NO_HYPERLINKS:-}"; then
    # Fallback: blue underlined text with URL in angle brackets
    printf '%s%s%s <%s>' "${z_blue_underline}" "${z_text}" "${z_reset}" "${z_url}"
    return 0
  fi

  # OSC-8 with blue underline formatting
  printf '%s\033]8;;%s\033\\%s\033]8;;\033\\%s' \
    "${z_blue_underline}" "${z_url}" "${z_text}" "${z_reset}"
}

# buc_link "Prefix text" "Link text" "URL"  (prints to stderr like other user-visible messages)
buc_link() {
  local z_prefix="${1:-}"
  local z_text="${2:-}"
  local z_url="${3:-}"

  zbuc_tag_args 3 "buc_link    " "${z_prefix} ${z_text} -> ${z_url}"

  # Always show at verbosity >= 0 (same visibility as buc_step)
  if test "${BUC_VERBOSE:-0}" -ge 0; then
    # Print prefix text if provided
    test -n "${z_prefix}" && printf '%s ' "${z_prefix}" >&2

    # Print formatted hyperlink
    zbuc_hyperlink "${z_text}" "${z_url}" >&2
    echo >&2
  fi
}

# eof
