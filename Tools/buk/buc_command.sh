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
# Bash Console Utility Library

set -euo pipefail

# Multiple inclusion guard — dies through printf and exit, since buc_die_now
# is defined below it in this very file
test -z "${ZBUC_SOURCED:-}" || { printf '%s\n' "Module buc multiply sourced - check sourcing hierarchy" >&2 || exit 1; exit 1; }
ZBUC_SOURCED=1

# The band's range the membrane below reads, from the substrate's generated
# constants, sourced here so the membrane holds in every process that loads
# this module. The sourced file carries its own inclusion guard, so a sibling
# sourcing it costs nothing; buc_die_now is not yet defined, so a failed
# source dies through printf and exit like the guard above.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" \
  || { printf '%s\n' "Failed to source bubg_breviary.sh" >&2 || exit 1; exit 1; }

# Color is no longer buc's own concern.  Every display path renders through
# the buym core (buym_format_yawp over the kindle-time BUYC_* palette), which
# owns the single terminal-capability decision and honors NO_COLOR/TERM=dumb.
# Semantic ambients flow in by BUYC_* name (resolved after kindle); colored
# prefixes ride buym's WARN/FAIL span markers.

# Global context variable for info and error messages
z_buc_context=""

# The tint function's slot: the rendered text zbuc_tint_yawp leaves for its
# caller. The command module has no kindle, so it is initialized here.
z_buc_tint=""

# Help mode flag
z_buc_doc_mode=false


######################################################################
# Internal logging helpers

# Usage: zbuc_make_tag <depth> "<label>"
#   Computes z_buc_tag for the given stack depth/label (no I/O).
# Usage: zbuc_tag_args <depth> "<label>" [arg...]
#   Computes z_buc_tag and logs args directly to the transcript.
#
# Bash stack quirk:
#   BASH_SOURCE[i] / FUNCNAME[i] index the current frame,
#   but BASH_LINENO[i] reports the line where FUNCNAME[i+1] was called.
#   For depth=N callers:
#       file = BASH_SOURCE[N]
#       line = BASH_LINENO[N-1]
# Usage: zbuc_make_tag <depth> "<label>"
#   Computes z_buc_tag for the given stack depth/label (no I/O).
#   Note: With depth=0 or too-deep stacks, file/line may be empty (by design).
zbuc_make_tag() {
  local -r z_d="${1:-1}"
  case "${z_d}" in ''|*[!0123456789]*) buc_die_now "zbuc_make_tag: depth must be digits, got '${z_d}'" ;; esac
  local z_label="${2:-}"
  local z_file="${BASH_SOURCE[10#${z_d}]##*/}"
  local z_line="${BASH_LINENO[10#${z_d}-1]}"
  z_buc_tag="${z_label}${z_file}:${z_line}: "
}

zbuc_tag_args() {
  local z_d="${1:-1}"
  test "$#" -eq 0 || shift
  local z_label="${1:-}"
  test "$#" -eq 0 || shift
  zbuc_make_tag "${z_d}" "${z_label}"
  local z_arg
  for z_arg in "$@"; do
    zbuc_tag_line "${z_arg}"
  done | zbuc_log "${z_buc_tag}" " ---- "
}

# One argument of zbuc_tag_args, stripped of its yelp spans and printed.
# Usage: zbuc_tag_line <arg>
zbuc_tag_line() {
  buym_strip_yawp "${1:-}"; local -r z_stripped="${z_buym_format}"
  printf '%s\n' "${z_stripped}" || exit 1
}

######################################################################
# Public logging wrappers

buc_log_args() { zbuc_tag_args 3 "buc_log_args " "$@"; }
buc_log_pipe() { zbuc_make_tag 3 "buc_log_pipe "; zbuc_log "${z_buc_tag}" " ---- "; }

buc_step()     { zbuc_tag_args 3 "buc_step     " "$@"; zbuc_print 0 "${BUYC_BRIGHT_WHITE:-}" "$*"; }
buc_code()     { zbuc_tag_args 3 "buc_code     " "$@"; zbuc_print 0 "${BUYC_CYAN:-}"         "$*"; }
buc_info()     { zbuc_tag_args 3 "buc_info     " "$@"; zbuc_print 0 ""                "$@"; }
buc_debug()    { zbuc_tag_args 3 "buc_debug    " "$@"; zbuc_print 2 ""                "$@"; }
buc_trace()    { zbuc_tag_args 3 "buc_trace    " "$@"; zbuc_print 3 ""                "$@"; }
buc_warn() {
  zbuc_tag_args 3 "buc_warn     " "$@"
  buym_warn_yawp "WARNING:"; local -r z_pfx="${z_buym_yelp}"
  zbuc_print 0 "" "${z_pfx} $*"
}
buc_success() {
  zbuc_tag_args 3 "buc_success  " "$@"
  zbuc_tint_yawp "${BUYC_GREEN:-}" "$*"; local -r z_tinted="${z_buc_tint}"
  printf '%s\n' "${z_tinted}" >&2 || buc_die_now
}
# Band membrane: $? captured before any command so a `cmd || buc_die_now` chain
# whose cmd exited with a precision-band code (the band's range in the
# generated constants sourced above) re-exits that code instead of laundering
# it to 1. Everything else stays exit 1, "imprecise death".
buc_die_now() {
  local z_status=$?
  if test -z "${ZBUYM_SOURCED:-}"; then
    # Ahead of the yelp module, which every display path renders through: the
    # dispatch kindle at this file's foot runs before its sourcer loads it.
    printf 'ERROR: [%s] %s\n' "${z_buc_context:-}" "$*" >&2 || exit 1
  else
    zbuc_tag_args 3 "buc_die_now      " "ERROR: [${z_buc_context:-}] $*"
    buym_fail_yawp "ERROR:"; local -r z_pfx="${z_buym_yelp}"
    zbuc_print -1 "" "${z_pfx} [${z_buc_context:-}] $*"
  fi
  if test "${z_status}" -ge "${BUBG_BAND_FRIEZE_BASE}" \
     && test "${z_status}" -lt "$((BUBG_BAND_FRIEZE_BASE + BUBG_BAND_FRIEZE_WIDTH))"; then
    exit "${z_status}"
  fi
  exit 1
}

# Deliberate rejection origin. Exits with an in-band code, a gate's generated
# constant, so a negative test can assert WHICH gate fired; buc_die_now wrappers
# upstream propagate the code unchanged through the band membrane.
# An out-of-band argument is a programming error and dies imprecisely.
buc_reject() {
  local z_code="${1:-}"
  test "$#" -eq 0 || shift
  test -n "${z_code}"           || buc_die_now "buc_reject: band code required"
  case "${z_code}" in *[!0123456789]*) buc_die_now "buc_reject: code '${z_code}' is not a number" ;; esac
  test "${z_code}" -ge "${BUBG_BAND_FRIEZE_BASE}" || buc_die_now "buc_reject: code '${z_code}' below band"
  test "${z_code}" -lt "$((BUBG_BAND_FRIEZE_BASE + BUBG_BAND_FRIEZE_WIDTH))" || buc_die_now "buc_reject: code '${z_code}' above band"
  if test -z "${ZBUYM_SOURCED:-}"; then
    # Ahead of the yelp module, as buc_die_now above: a refusal at the
    # dispatch kindle at this file's foot.
    printf 'ERROR: [%s] %s\n' "${z_buc_context:-}" "$*" >&2 || buc_die_now
  else
    zbuc_tag_args 3 "buc_reject   " "ERROR: [${z_buc_context:-}] $*"
    buym_fail_yawp "ERROR:"; local -r z_pfx="${z_buym_yelp}"
    zbuc_print -1 "" "${z_pfx} [${z_buc_context:-}] $*"
  fi
  exit "${z_code}"
}

# Display unprefixed cyan text for typeable guidance (commands, config values).
# Sigil-less by design — routes color through the core but skips the context tag.
buc_bare() {
  zbuc_tag_args 3 "buc_bare     " "$@"
  zbuc_tint_yawp "${BUYC_CYAN:-}" "$*"; local -r z_tinted="${z_buc_tint}"
  printf '%s\n' "${z_tinted}" >&2 || buc_die_now
}

# Display tabtarget hint: resolves colophon to tabtarget filename
# Args: colophon [extra_args...]
buc_tabtarget() {
  local z_colophon="${1}"
  test "$#" -eq 0 || shift
  local z_extra="${*:+ $*}"
  buym_tt_path "${z_colophon}"
  test -n "${z_buym_tt_path}" || buc_die_now "buc_tabtarget: no tabtarget found for colophon '${z_colophon}'"
  buc_bare "        ${z_buym_tt_path}${z_extra}"
}

buc_context() {
  z_buc_context="${1}"
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
  test "${z_buc_doc_mode}" = "true"
}

buc_doc_env_row() {
  set -e

  local z_env_var_name="${1}"
  local z_env_var_info="${2}"

  # Trim trailing spaces from variable name
  z_env_var_name="${z_env_var_name%% *}"

  # In doc mode, show documentation only (no validation — env vars may not be set)
  if zbuc_doc_mode_predicate; then
    zbuc_tint_yawp "${BUYC_MAGENTA:-}" "${1}"; local -r z_tinted="${z_buc_tint}"
    echo "  ${z_tinted}:  ${z_env_var_info}" || buc_die_now
    return 0
  fi

  # In execute mode, validate variable is set
  local -r z_name_lead="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
  [[ "${z_env_var_name}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] \
    || buc_die_now "buc_doc_env_row: invalid variable name: '${z_env_var_name}'"
  # Non-fatal by grant: repo owner determines warning safe here
  test -n "${!z_env_var_name:-}" || buc_warn "${z_env_var_name} is not set"
}

# Idiomatic last step of environment documentation in furnish.
# In doc mode, signals furnish to return early (sourcing/kindle not needed for help).
# Usage:
#    buc_doc_env_done || return 0
buc_doc_env_done() {
  zbuc_doc_mode_predicate || return 0
  return 1
}

z_buc_usage_string="UNFILLED"

buc_doc_brief() {
  set -e
  z_buc_usage_string="${z_buc_context}"
  zbuc_doc_mode_predicate || return 0
  echo || buc_die_now
  zbuc_tint_yawp "${BUYC_BRIGHT_WHITE:-}" "${z_buc_context}"; local -r z_tinted="${z_buc_tint}"
  echo "  ${z_tinted}" || buc_die_now
  echo "    brief: ${1}" || buc_die_now
}

buc_doc_lines() {
  set -e
  zbuc_doc_mode_predicate || return 0
  echo "           ${1}" || buc_die_now
}

buc_doc_param() {
  set -e
  z_buc_usage_string="${z_buc_usage_string} <<${1}>>"
  zbuc_doc_mode_predicate || return 0
  echo "    required: ${1} - ${2}" || buc_die_now
}

buc_doc_oparm() {
  set -e
  z_buc_usage_string="${z_buc_usage_string} [<<${1}>>]"
  zbuc_doc_mode_predicate || return 0
  echo "    optional: ${1} - ${2}" || buc_die_now
}

zbuc_usage() {
  zbuc_tint_yawp "${BUYC_CYAN:-}" "${z_buc_usage_string}"; local -r z_tinted="${z_buc_tint}"
  printf '    usage: %s\n' "${z_tinted}" || buc_die_now
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
  z_buc_doc_mode=true
}

buc_usage_die() {
  set -e
  # The line zbuc_usage prints, composed here rather than captured from it.
  zbuc_tint_yawp "${BUYC_CYAN:-}" "${z_buc_usage_string}"; local -r z_cyan="${z_buc_tint}"
  local -r z_usage="    usage: ${z_cyan}"
  buym_fail_yawp "ERROR:"; local -r z_pfx="${z_buym_yelp}"
  zbuc_tint_yawp "" "${z_pfx} ${z_usage}"; local -r z_line="${z_buc_tint}"
  printf '%s\n' "${z_line}" || exit 1
  exit 1
}

# Tint <text> through the buym core with the ambient the caller hands by value
# (empty => default/no ambient).  Sentinel-guarded; a caller spells a palette
# constant as "${BUYC_name:-}", so a cold caller (doc-mode, pre-kindle
# buc_die_now) is set -u safe.  Resolved string lands in z_buc_tint.
# zbuc_tint_yawp <ambient> <text> — the tinted text
# → local -r z_tinted="${z_buc_tint}"
zbuc_tint_yawp() {
  zbuym_sentinel
  local -r z_ambient="${1:-}"
  buym_format_yawp "${z_ambient}" "${2:-}"; local -r z_formatted="${z_buym_format}"
  z_buc_tint="${z_formatted}"
}

# Multi-line print function with verbosity control.
# Usage: zbuc_print <min_verbosity> <ambient> [message...]
# Sends output to stderr to avoid interfering with stdout returns.  Each
# message renders through the shared buym resolver (via zbuc_tint_yawp), so inline
# yawp spans resolve, the named ambient and gray operation sigil are
# terminal-aware, and a cold display does not trip set -u.
zbuc_print() {
  local z_min_verbosity="${1}"
  local -r z_ambient="${2}"
  test "$#" -lt 2 || shift 2

  # Always print if z_min_verbosity is -1, otherwise check BURE_VERBOSE
  if test "${z_min_verbosity}" -eq -1 || test "${BURE_VERBOSE:-0}" -ge "${z_min_verbosity}"; then
    zbuym_sentinel
    while test $# -gt 0; do
      zbuc_print_line "${z_ambient}" "${1}"
      test "$#" -eq 0 || shift
    done
  fi
}

# One message of zbuc_print: tinted by the named ambient and printed, behind the
# context sigil when one is set.
# Usage: zbuc_print_line <ambient> <message>
zbuc_print_line() {
  zbuc_tint_yawp "${1:-}" "${2:-}"; local -r z_tinted="${z_buc_tint}"
  if test -n "${z_buc_context}"; then
    printf '%s%s%s %s\n' "${BUYC_GRAY}" "${z_buc_context}" "${BUYC_RESET}" "${z_tinted}" >&2 || exit 1
  else
    printf '%s\n' "${z_tinted}" >&2 || exit 1
  fi
}

# Core logging implementation - always reads from stdin
#
# The drain is UNCONDITIONAL, and BURD_TRANSCRIPT decides only whether each
# line is written. Returning early on an unset transcript would close the read
# end of the pipe zbuc_tag_args builds, and the writer loop feeding it takes
# SIGPIPE the moment it loses that race — under `set -o pipefail` the writer's
# 141 becomes the pipeline's status, and `set -e` then exits the shell inside
# buc_die_now BEFORE zbuc_print can reach stderr. The diagnostic is annihilated
# and the caller dies mute. Read to EOF first; decide what to write second.
zbuc_log() {
  local z_prefix="${1}"
  local -r z_rest_prefix="${2}"
  local -r z_outfile="${BURD_TRANSCRIPT:-}"
  local z_line=""

  while IFS= read -r z_line || test -n "${z_line}"; do
    test -z "${z_outfile}" || printf '%s%s\n' "${z_prefix}" "${z_line}" >> "${z_outfile}"
    z_prefix="${z_rest_prefix}"
  done
}


# Die if condition is true (non-zero)
# Usage: buc_die_if <condition> <message1> [<message2> ...]
buc_die_if() {
  local z_condition="${1}"
  test "$#" -eq 0 || shift

  test "${z_condition}" -ne 0 || return 0

  set -e
  local z_context="${z_buc_context:-}"
  buym_fail_yawp "ERROR:"; local -r z_pfx="${z_buym_yelp}"
  zbuc_print -1 "" "${z_pfx} [${z_context}] ${1}"
  test "$#" -eq 0 || shift
  zbuc_print -1 "" "$@"
  exit 1
}

# Die unless condition is true (zero)
# Usage: buc_die_unless <condition> <message1> [<message2> ...]
buc_die_unless() {
  local z_condition="${1}"
  test "$#" -eq 0 || shift

  test "${z_condition}" -eq 0 || return 0

  set -e
  local z_context="${z_buc_context:-}"
  buym_fail_yawp "ERROR:"; local -r z_pfx="${z_buym_yelp}"
  zbuc_print -1 "" "${z_pfx} [${z_context}] ${1}"
  test "$#" -eq 0 || shift
  zbuc_print -1 "" "$@"
  exit 1
}

zbuc_show_help() {
  local z_prefix="${1}"
  local z_title="${2}"
  local z_env_func="${3}"

  echo "${z_title}" || buc_die_now
  echo || buc_die_now

  if test -n "${z_env_func}"; then
    echo "Environment Variables:" || buc_die_now
    # A call through a variable: the name arrives at run time, so the call takes a form the
    # unguarded-command reading admits (VOr_jqp). A known name is called by name.
    declare -F "${z_env_func}" >/dev/null || buc_die_now "Function not found: ${z_env_func}"
    "${z_env_func}"
    echo || buc_die_now
  fi

  echo "Commands:" || buc_die_now

  # declare -F prints one "declare -f <name>" line per function. Function
  # names carry no whitespace, so the listing flattened to one line and split
  # by read holds every name among its words, and the match keeps the names
  # under the prefix alone.
  local z_listing=""
  z_listing=$(declare -F) || buc_die_now "Failed to list the defined functions"
  local -r z_newline=$'\n'
  local -r z_listing_line="${z_listing//"${z_newline}"/ }"
  local z_words=()
  read -r -a z_words <<< "${z_listing_line}" || buc_die_now "Failed to split the function listing"
  local z_i
  for z_i in "${!z_words[@]}"; do
    [[ "${z_words[${z_i}]}" =~ ^${z_prefix}[a-z][a-z0-9_]*$ ]] || continue
    [[ "${z_words[${z_i}]}" != *_predicate && "${z_words[${z_i}]}" != *_capture && "${z_words[${z_i}]}" != *_recite ]] || continue
    buc_context "${z_words[${z_i}]}"
    # A call through a variable: the name arrives at run time, so the call takes a form the
    # unguarded-command reading admits (VOr_jqp). A known name is called by name.
    # Another call to a dispatched command function takes a suffix; in doc mode every prologue
    # returns at buc_doc_shown, so it never fires.
    "${z_words[${z_i}]}" || buc_die_now "Documentation failed: ${z_words[${z_i}]}"
  done
}

buc_countdown() {
  local z_seconds="${1}"
  local z_prompt="${2}"

  if test "${BURE_COUNTDOWN:-}" = "skip"; then
    buc_step "Countdown: ${z_seconds}s (skipped — BURE_COUNTDOWN=skip)"
    return 0
  fi

  test -z "${BURE_COUNTDOWN:-}" || buc_die_now "BURE_COUNTDOWN must be 'skip' or unset, got '${BURE_COUNTDOWN}'"
  case "${z_seconds}" in ''|*[!0123456789]*) buc_die_now "buc_countdown: seconds must be digits, got '${z_seconds}'" ;; esac

  buc_step "Countdown: ${z_seconds}s to cancel (Ctrl-C)"
  sleep 1 || buc_die_now "sleep failed"
  zbuc_tint_yawp "${BUYC_BRIGHT_YELLOW:-}" "${z_prompt}"; local -r z_tinted="${z_buc_tint}"
  printf '%s ' "${z_tinted}" >/dev/tty || buc_die_now
  local z_i
  for (( z_i=10#${z_seconds}; z_i>=1; z_i-- )); do
    printf '%d... ' "${z_i}" >/dev/tty || buc_die_now
    sleep 1 || buc_die_now "sleep failed"
  done
  printf '\n' >/dev/tty || buc_die_now
}

buc_require() {
  local z_prompt="${1}"
  local z_required_value="${2}"

  if test "${BURE_CONFIRM:-}" = "skip"; then
    buc_step "Confirm: (skipped — BURE_CONFIRM=skip)"
    return 0
  fi

  test -z "${BURE_CONFIRM:-}" || buc_die_now "BURE_CONFIRM must be 'skip' or unset, got '${BURE_CONFIRM}'"

  sleep 1 || buc_die_now "sleep failed"
  zbuc_tint_yawp "${BUYC_BRIGHT_YELLOW:-}" "${z_prompt}"; local -r z_tinted="${z_buc_tint}"
  printf '%s\n' "${z_tinted}" >&2 || buc_die_now
  # Newline-terminated by necessity: the non-interactive dispatch relay forwards
  # this stream a whole line at a time, so a partial line never reaches the
  # terminal — the operator would face a blocked read with no visible prompt.
  # The answer is typed on the line beneath. Do not rejoin prompt and answer.
  printf 'Type %s to confirm:\n' "${z_required_value}" >&2 || buc_die_now
  local z_input
  read -r z_input </dev/tty || buc_die_now "Failed to read input"
  test "${z_input}" = "${z_required_value}" || buc_die_now "Confirmation failed — expected '${z_required_value}', got '${z_input}'"
}

buc_execute() {
  set -e
  local z_prefix="${1}"
  local z_title="${2}"
  local z_env_func="${3}"
  local z_command="${4:-}"
  test "$#" -lt 3 || shift 3
  test -z "${z_command}" || shift

  # THE CLI'S ENTRY, where a dispatch's pointer reached it: a name of the kit
  # standing exported is refused save the hand-offs this level declares, the
  # zipper's folio among them. The folio is then withdrawn from the export, so
  # the command still reads it here and nothing this CLI runs inherits it.
  test -z "${BURD_BURD_FILE:-}" || buv_export_sentinel "${BURD_TARGET}" "BUZ_FOLIO"
  test -z "${BUZ_FOLIO+x}" || export -n BUZ_FOLIO

  # Enable bash trace to stderr if BURE_VERBOSE is 3 or higher and bash >= 4.1
  if test "${BURE_VERBOSE:-0}" -ge 3; then
    if test "${BASH_VERSINFO[0]}" -gt 4 || { test "${BASH_VERSINFO[0]}" -eq 4 && test "${BASH_VERSINFO[1]}" -ge 1; }; then
      export PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
      export BASH_XTRACEFD=2
      set -x
    fi
  fi

  # Validate prefix pattern, furnish deps, then dispatch command
  if test -n "${z_command}" && [[ "${z_command}" =~ ^${z_prefix}[a-z][a-z0-9_]*$ ]]; then
    buc_context "${z_command}"
    test -z "${z_env_func}" || "${z_env_func}" "${z_command}"
    # A call through a variable: the name arrives at run time, so the call takes a form the
    # unguarded-command reading admits (VOr_jqp). A known name is called by name.
    declare -F "${z_command}" >/dev/null || buc_die_now "Function not found: ${z_command}"
    "${z_command}" "$@"
  else
    # Non-fatal by grant: repo owner determines warning safe here
    test -z "${z_command}" || buc_warn "Unknown command: ${z_command}"
    buc_set_doc_mode
    zbuc_show_help "${z_prefix}" "${z_title}" "${z_env_func}"
    echo || buc_die_now
    exit 1
  fi
}

# --- Hyperlink helper, rendered through the yelp module's one decision ---
# OSC-8 where the palette renders one; the URL beside the text where it does
# not.  Disable with: export BURE_HYPERLINKS=0
zbuc_hyperlink() {
  local z_text="${1:-}"
  local z_url="${2:-}"

  zbuym_sentinel
  buym_href_yawp "${z_url}" "${z_text}"; local -r z_href="${z_buym_yelp}"
  buym_format_yawp "" "${z_href}"; local -r z_rendered="${z_buym_format}"
  printf '%s' "${z_rendered}" || buc_die_now
}

# buc_link "Prefix text" "Link text" "URL"  (prints to stderr like other user-visible messages)
buc_link() {
  local z_prefix="${1:-}"
  local z_text="${2:-}"
  local z_url="${3:-}"

  zbuc_tag_args 3 "buc_link    " "${z_prefix} ${z_text} -> ${z_url}"

  # Always show at verbosity >= 0 (same visibility as buc_step)
  if test "${BURE_VERBOSE:-0}" -ge 0; then
    # Print prefix text if provided
    if test -n "${z_prefix}"; then
      printf '%s ' "${z_prefix}" >&2 || buc_die_now
    fi

    # Print formatted hyperlink
    zbuc_hyperlink "${z_text}" "${z_url}" >&2
    echo >&2 || buc_die_now
  fi
}

# --- Native path translation (Cygwin -> Windows-native) ---
#
# Normalize a path argument for a Windows-native tool (docker, cargo, ...)
# invoked from Cygwin bash. A Windows-native binary reads a Cygwin /cygdrive/X/...
# path as a literal Windows path and reports "does not exist"; hand it the
# drive-letter form (X:/... — forward slashes, which Windows accepts). Pure
# /cygdrive parameter expansion, no cygpath subshell, mirroring RBTDRX's Rust
# fast path. Gated on BURD_OSTYPE (the dispatch-synthesized platform fact): off
# Cygwin every path is emitted unchanged. A relative or already-native path
# passes through; a bare-absolute POSIX path (leading / but not /cygdrive) is an
# unsurveyed shape and returns 1 so the caller dies. Reads only its argument and
# BURD_OSTYPE — no kindle state — so it stays unit-testable in isolation.
#
# This is the single home for the transform: it folds the formerly-duplicated
# per-module copies (zrbfc/zrbndb/zrbob_native_path_capture) into one (heat ₣BV).
# Retire when the Windows-native tools build/run as true Cygwin binaries.
buc_native_path_capture() {
  local -r z_path="${1:-}"
  test -n "${z_path}" || return 1

  local z_native="${z_path}"
  if test "${BURD_OSTYPE:-}" = "cygwin"; then
    case "${z_path}" in
      /cygdrive/?/*)
        local -r z_drive_rest="${z_path#/cygdrive/}"
        local -r z_drive="${z_drive_rest%%/*}"
        local -r z_drive_tail="${z_drive_rest#"${z_drive}/"}"
        z_native="${z_drive}:/${z_drive_tail}"
        ;;
      /*)
        return 1
        ;;
    esac
  fi

  printf '%s\n' "${z_native}"
}

# --- Executable location (read from PATH itself) ---
#
# Answer the absolute path of the first executable file of the given name on
# PATH, or return 1 where none stands. A builtin may not stand at the head of a
# substitution, so a caller cannot take `command -v` or `type -P` in the one
# form, and bash 3.2 has no BASH_CMDS to read a lookup's answer from; this walk
# is the one capture that replaces them. It reads PATH rather than the hash
# table, so a hashed path never answers, and it answers only a regular file
# that is executable: a directory of that name, or a file that is not
# executable, is passed over where a lookup would answer it. An entry that does
# not open with `/` is passed over too, the empty entry among them, so the
# answer is absolute whatever directory the caller stands in. A name carrying
# a `/` is no PATH search and is refused. Reads its argument and PATH alone —
# no kindle state — so it stays unit-testable in isolation.
buc_executable_path_capture() {
  local -r z_name="${1:-}"
  test -n "${z_name}" || return 1
  case "${z_name}" in */*) return 1 ;; esac

  local z_dirs=()
  IFS=: read -r -a z_dirs <<< "${PATH}" || return 1
  test "${#z_dirs[@]}" -gt 0 || return 1

  local z_found=""
  local z_dir=""
  for z_dir in "${z_dirs[@]}"; do
    case "${z_dir}" in /*) ;; *) continue ;; esac
    test -f "${z_dir}/${z_name}" || continue
    test -x "${z_dir}/${z_name}" || continue
    z_found="${z_dir}/${z_name}"
    break
  done
  test -n "${z_found}" || return 1

  printf '%s\n' "${z_found}"
}

# --- Clipboard copy (platform-normalized) ---
#
# Copy the argument text to the system clipboard via the first present
# platform tool: pbcopy (macOS), clip.exe (Windows — reachable from WSL and
# Cygwin), wl-copy (Wayland), xclip (X11). Existence-probing is the platform
# discrimination — no OSTYPE sniffing;
# the tools are optional probe-and-skip dependencies each consuming project
# inventories itself. Predicate contract:
# exit 0 only when a tool was found AND the copy succeeded; exit 1 otherwise.
# Sets z_buc_clipboard_tool to the probed tool name (empty when none present)
# so the caller can log the outcome. Emits nothing on either stream and never
# dies — the caller owns any user-visible announcement, and a copy is always
# a convenience, never load-bearing. Reads its argument and one environment
# variable — no kindle state — so it stays unit-testable in isolation.
#
# A CLIPBOARD IS A STATION RESOURCE AND NEVER A HOST ONE. It belongs where the
# human sits, and a tool can only ever write the clipboard of the host it runs
# on — so the predicate's true contract is that the execution host IS the
# station, and SSH_CONNECTION is the exact cheap signature of that identity
# failing. The guard declines before probing anything, because over ssh a tool
# that is present answers for the wrong machine: clip.exe under an sshd session
# exits 0 onto a window station no desktop can paste from, which is a false
# verdict rather than a failed copy, and the caller's announcement inherits it.
# The cause is named on the log channel alone — the streams stay the caller's,
# as the paragraph above requires.
#
# DELIVERING the convenience remotely is out of scope by decision rather than by
# omission. OSC 52 is the only channel reaching the station's clipboard through
# ssh, riding the terminal stream rather than the host, but it is
# fire-and-forget with terminal-dependent support — so an announcement over it
# would be unverifiable, which is this same dishonesty rebuilt one layer up.
buc_clipboard_copy_predicate() {
  local -r z_text="${1:-}"
  test -n "${z_text}" || return 1

  z_buc_clipboard_tool=""

  if test -n "${SSH_CONNECTION:-}"; then
    buc_log_args "Clipboard copy declined: SSH_CONNECTION stands, so the execution host is not the station and no clipboard reachable here is the operator's"
    return 1
  fi

  # A failed copy's cause is kept for forensics, never written to either stream.
  local -r z_stderr_file="${BURD_TEMP_DIR}/buc_clipboard_stderr.txt"
  local z_copied=0
  if command -v pbcopy >/dev/null; then
    z_buc_clipboard_tool="pbcopy"
    if printf '%s' "${z_text}" | pbcopy 2>"${z_stderr_file}"; then z_copied=1; fi
  elif command -v clip.exe >/dev/null; then
    z_buc_clipboard_tool="clip.exe"
    if printf '%s' "${z_text}" | clip.exe 2>"${z_stderr_file}"; then z_copied=1; fi
  elif command -v wl-copy >/dev/null; then
    z_buc_clipboard_tool="wl-copy"
    if printf '%s' "${z_text}" | wl-copy 2>"${z_stderr_file}"; then z_copied=1; fi
  elif command -v xclip >/dev/null; then
    z_buc_clipboard_tool="xclip"
    if printf '%s' "${z_text}" | xclip -selection clipboard 2>"${z_stderr_file}"; then z_copied=1; fi
  fi

  test "${z_copied}" = "1"
}

######################################################################
# The dispatch this process runs under
#
# A dispatch writes its regime once to its dispatch file and hands every
# coordinator below it the pointer BURD_BURD_FILE and the kit directory
# BURD_BUK_DIR. This module, which every workbench and CLI sources first, reads
# the file the pointer names and then the config regime from the file that one
# names, and kindles both, so a CLI whose furnish sources nothing holds the two
# regimes kindled. The modules that kindle them are sourced here, and nowhere
# else in the process.
#
# A process the pointer does not reach kindles nothing here: a launcher, which
# withdraws an inherited pointer before it sources this module and composes its
# own run's; and a harness sourcing the module for its functions alone. A
# pointer naming no readable file is a broken launch contract, and dies
# imprecisely naming the pointer.
if test -n "${BURD_BURD_FILE:-}"; then
  test -f "${BURD_BURD_FILE}" || buc_die_now "BURD_BURD_FILE names no dispatch file: ${BURD_BURD_FILE}"
  test -r "${BURD_BURD_FILE}" || buc_die_now "BURD_BURD_FILE names an unreadable dispatch file: ${BURD_BURD_FILE}"
  source "${BURD_BURD_FILE}" \
    || buc_die_now "Failed to source the dispatch file BURD_BURD_FILE names: ${BURD_BURD_FILE}"
  test -n "${BURD_REGIME_FILE:-}" \
    || buc_die_now "The dispatch file names no config regime: ${BURD_BURD_FILE}"
  source "${BURD_REGIME_FILE}" \
    || buc_die_now "Failed to source the config regime the dispatch file names: ${BURD_REGIME_FILE}"

  source "${BASH_SOURCE[0]%/*}/bubc_constants.sh" || buc_die_now "Failed to source bubc_constants.sh"
  source "${BASH_SOURCE[0]%/*}/buv_validation.sh" || buc_die_now "Failed to source buv_validation.sh"
  source "${BASH_SOURCE[0]%/*}/burd_regime.sh"    || buc_die_now "Failed to source burd_regime.sh"
  source "${BASH_SOURCE[0]%/*}/burc_regime.sh"    || buc_die_now "Failed to source burc_regime.sh"

  zbuv_kindle
  zburd_kindle
  zburc_kindle
fi

# eof
