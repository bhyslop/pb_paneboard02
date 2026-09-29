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

# Multiple inclusion guard
test -z "${ZBUC_SOURCED:-}" || return 0
ZBUC_SOURCED=1

# Color is no longer buc's own concern.  Every display path renders through
# the buym core (buym_format_yawp over the kindle-time BUYC_* palette), which
# owns the single terminal-capability decision and honors NO_COLOR/TERM=dumb.
# Semantic ambients flow in by BUYC_* name (resolved after kindle); colored
# prefixes ride buym's WARN/FAIL span markers.

# Global context variable for info and error messages
z_buc_context=""

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
  local z_d="${1:-1}"
  case "${z_d}" in ''|*[!0-9]*) z_d=1 ;; esac
  local z_label="${2:-}"
  local z_file="${BASH_SOURCE[z_d]##*/}"
  local z_line="${BASH_LINENO[z_d-1]}"
  z_buc_tag="${z_label}${z_file}:${z_line}: "
}

zbuc_tag_args() {
  local z_d="${1:-1}"
  shift
  local z_label="${1:-}"
  shift
  zbuc_make_tag "${z_d}" "${z_label}"
  local z_arg
  for z_arg in "$@"; do
    buym_strip_yawp "${z_arg}"
    printf '%s\n' "${z_buym_format}"
  done | zbuc_log "${z_buc_tag}" " ---- "
}

######################################################################
# Public logging wrappers

buc_log_args() { zbuc_tag_args 3 "buc_log_args " "$@"; }
buc_log_pipe() { zbuc_make_tag 3 "buc_log_pipe "; zbuc_log "${z_buc_tag}" " ---- "; }

buc_step()     { zbuc_tag_args 3 "buc_step     " "$@"; zbuc_print 0 BUYC_BRIGHT_WHITE "$*"; }
buc_code()     { zbuc_tag_args 3 "buc_code     " "$@"; zbuc_print 0 BUYC_CYAN         "$*"; }
buc_info()     { zbuc_tag_args 3 "buc_info     " "$@"; zbuc_print 0 ""                "$@"; }
buc_debug()    { zbuc_tag_args 3 "buc_debug    " "$@"; zbuc_print 2 ""                "$@"; }
buc_trace()    { zbuc_tag_args 3 "buc_trace    " "$@"; zbuc_print 3 ""                "$@"; }
buc_warn() {
  zbuc_tag_args 3 "buc_warn     " "$@"
  buym_warn_yawp "WARNING:"; local z_pfx="${z_buym_yelp}"
  zbuc_print 0 "" "${z_pfx} $*"
}
buc_success() {
  zbuc_tag_args 3 "buc_success  " "$@"
  zbuc_tint BUYC_GREEN "$*"
  printf '%s\n' "${z_buym_format}" >&2 || buc_die_now
}
# Band membrane: $? captured before any command so a `cmd || buc_die_now` chain
# whose cmd exited with a precision-band code (bubc band tinder) re-exits
# that code instead of laundering it to 1. Everything else — including a
# cold caller before bubc is sourced — stays exit 1, "imprecise death".
buc_die_now() {
  local z_status=$?
  zbuc_tag_args 3 "buc_die_now      " "ERROR: [${z_buc_context:-}] $*"
  buym_fail_yawp "ERROR:"; local z_pfx="${z_buym_yelp}"
  zbuc_print -1 "" "${z_pfx} [${z_buc_context:-}] $*"
  if test -n "${BUBC_band_base:-}"                                \
     && test "${z_status}" -ge "${BUBC_band_base}"                \
     && test "${z_status}" -lt "$((BUBC_band_base + BUBC_band_width))"; then
    exit "${z_status}"
  fi
  exit 1
}

# Deliberate rejection origin. Exits with an in-band code from the bubc band
# tinder block so a negative test can assert WHICH gate fired; buc_die_now
# wrappers upstream propagate the code unchanged through the band membrane.
# An out-of-band argument is a programming error and dies imprecisely.
buc_reject() {
  local z_code="${1:-}"
  shift || true
  test -n "${BUBC_band_base:-}" || buc_die_now "buc_reject: band tinder not sourced (bubc_constants.sh)"
  test -n "${z_code}"           || buc_die_now "buc_reject: band code required"
  test "${z_code}" -ge "${BUBC_band_base}" 2>/dev/null || buc_die_now "buc_reject: code '${z_code}' below band"
  test "${z_code}" -lt "$((BUBC_band_base + BUBC_band_width))" || buc_die_now "buc_reject: code '${z_code}' above band"
  zbuc_tag_args 3 "buc_reject   " "ERROR: [${z_buc_context:-}] $*"
  buym_fail_yawp "ERROR:"; local z_pfx="${z_buym_yelp}"
  zbuc_print -1 "" "${z_pfx} [${z_buc_context:-}] $*"
  exit "${z_code}"
}

# Display unprefixed cyan text for typeable guidance (commands, config values).
# Sigil-less by design — routes color through the core but skips the context tag.
buc_bare() {
  zbuc_tag_args 3 "buc_bare     " "$@"
  zbuc_tint BUYC_CYAN "$*"
  printf '%s\n' "${z_buym_format}" >&2
}

# Display tabtarget hint: resolves colophon to tabtarget filename
# Args: colophon [extra_args...]
buc_tabtarget() {
  local z_colophon="$1"
  shift
  local z_extra="${*:+ $*}"
  buym_tt_path "${z_colophon}"
  test -n "${z_buym_tt_path}" || buc_die_now "buc_tabtarget: no tabtarget found for colophon '${z_colophon}'"
  buc_bare "        ${z_buym_tt_path}${z_extra}"
}

buc_context() {
  z_buc_context="$1"
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
    zbuc_tint BUYC_MAGENTA "${1}"
    echo "  ${z_buym_format}:  ${z_env_var_info}"
    return 0
  fi

  # In execute mode, validate variable is set
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
  echo
  zbuc_tint BUYC_BRIGHT_WHITE "${z_buc_context}"
  echo "  ${z_buym_format}"
  echo "    brief: $1"
}

buc_doc_lines() {
  set -e
  zbuc_doc_mode_predicate || return 0
  echo "           $1"
}

buc_doc_param() {
  set -e
  z_buc_usage_string="${z_buc_usage_string} <<$1>>"
  zbuc_doc_mode_predicate || return 0
  echo "    required: $1 - $2"
}

buc_doc_oparm() {
  set -e
  z_buc_usage_string="${z_buc_usage_string} [<<$1>>]"
  zbuc_doc_mode_predicate || return 0
  echo "    optional: $1 - $2"
}

zbuc_usage() {
  zbuc_tint BUYC_CYAN "${z_buc_usage_string}"
  printf '    usage: %s\n' "${z_buym_format}"
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
  local z_usage; z_usage=$(zbuc_usage)
  buym_fail_yawp "ERROR:"; local z_pfx="${z_buym_yelp}"
  zbuc_tint "" "${z_pfx} ${z_usage}"
  printf '%s\n' "${z_buym_format}"
  exit 1
}

# Tint <text> through the buym core with the ambient named by <BUYC_name>
# (empty name => default/no ambient).  Sentinel-guarded and name-indirect so
# every BUYC_* dereference happens after kindle — a cold caller (doc-mode,
# pre-kindle buc_die_now) is set -u safe.  Resolved string lands in z_buym_format.
zbuc_tint() {
  zbuym_sentinel
  local z_name="${1:-}"
  local z_ambient=""
  test -z "${z_name}" || z_ambient="${!z_name}"
  buym_format_yawp "${z_ambient}" "${2:-}"
}

# Multi-line print function with verbosity control.
# Usage: zbuc_print <min_verbosity> <BUYC_ambient_name> [message...]
# Sends output to stderr to avoid interfering with stdout returns.  Each
# message renders through the shared buym resolver (via zbuc_tint), so inline
# yawp spans resolve, the named ambient and gray operation sigil are
# terminal-aware, and a cold display does not trip set -u.
zbuc_print() {
  local z_min_verbosity="$1"
  local z_ambient_name="$2"
  shift 2

  # Always print if z_min_verbosity is -1, otherwise check BURE_VERBOSE
  if test "${z_min_verbosity}" -eq -1 || test "${BURE_VERBOSE:-0}" -ge "${z_min_verbosity}"; then
    zbuym_sentinel
    while test $# -gt 0; do
      zbuc_tint "${z_ambient_name}" "$1"
      if test -n "${z_buc_context}"; then
        printf '%s%s%s %s\n' "${BUYC_GRAY}" "${z_buc_context}" "${BUYC_RESET}" "${z_buym_format}" >&2
      else
        printf '%s\n' "${z_buym_format}" >&2
      fi
      shift
    done
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
  local z_prefix="$1"
  local -r z_rest_prefix="$2"
  local -r z_outfile="${BURD_TRANSCRIPT:-}"
  local z_line=""

  while IFS= read -r z_line; do
    test -z "${z_outfile}" || printf '%s%s\n' "${z_prefix}" "${z_line}" >> "${z_outfile}"
    z_prefix="${z_rest_prefix}"
  done
}


# Die if condition is true (non-zero)
# Usage: buc_die_if <condition> <message1> [<message2> ...]
buc_die_if() {
  local z_condition="$1"
  shift

  test "${z_condition}" -ne 0 || return 0

  set -e
  local z_context="${z_buc_context:-}"
  buym_fail_yawp "ERROR:"; local z_pfx="${z_buym_yelp}"
  zbuc_print -1 "" "${z_pfx} [${z_context}] $1"
  shift
  zbuc_print -1 "" "$@"
  exit 1
}

# Die unless condition is true (zero)
# Usage: buc_die_unless <condition> <message1> [<message2> ...]
buc_die_unless() {
  local z_condition="$1"
  shift

  test "${z_condition}" -eq 0 || return 0

  set -e
  local z_context="${z_buc_context:-}"
  buym_fail_yawp "ERROR:"; local z_pfx="${z_buym_yelp}"
  zbuc_print -1 "" "${z_pfx} [${z_context}] $1"
  shift
  zbuc_print -1 "" "$@"
  exit 1
}

zbuc_show_help() {
  local z_prefix="$1"
  local z_title="$2"
  local z_env_func="$3"

  echo "${z_title}"
  echo

  if test -n "${z_env_func}"; then
    echo "Environment Variables:"
    "${z_env_func}"
    echo
  fi

  echo "Commands:"

  local z_decl z_flag z_cmd
  while read -r z_decl z_flag z_cmd; do
    [[ "${z_cmd}" =~ ^${z_prefix}[a-z][a-z0-9_]*$ ]] || continue
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

  test -z "${BURE_COUNTDOWN:-}" || buc_die_now "BURE_COUNTDOWN must be 'skip' or unset, got '${BURE_COUNTDOWN}'"

  buc_step "Countdown: ${z_seconds}s to cancel (Ctrl-C)"
  sleep 1
  zbuc_tint BUYC_BRIGHT_YELLOW "${z_prompt}"
  printf '%s ' "${z_buym_format}" >/dev/tty
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

  test -z "${BURE_CONFIRM:-}" || buc_die_now "BURE_CONFIRM must be 'skip' or unset, got '${BURE_CONFIRM}'"

  sleep 1
  zbuc_tint BUYC_BRIGHT_YELLOW "${z_prompt}"
  printf '%s\n' "${z_buym_format}" >&2
  # Newline-terminated by necessity: the non-interactive dispatch relay forwards
  # this stream a whole line at a time, so a partial line never reaches the
  # terminal — the operator would face a blocked read with no visible prompt.
  # The answer is typed on the line beneath. Do not rejoin prompt and answer.
  printf 'Type %s to confirm:\n' "${z_required_value}" >&2
  local z_input
  read -r z_input </dev/tty
  test "${z_input}" = "${z_required_value}" || buc_die_now "Confirmation failed — expected '${z_required_value}', got '${z_input}'"
}

buc_execute() {
  set -e
  local z_prefix="$1"
  local z_title="$2"
  local z_env_func="$3"
  local z_command="${4:-}"
  shift 3; test -z "${z_command}" || shift

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
  if test -n "${z_command}" && [[ "${z_command}" =~ ^${z_prefix}[a-z][a-z0-9_]*$ ]]; then
    buc_context "${z_command}"
    test -z "${z_env_func}" || "${z_env_func}" "${z_command}"
    declare -F "${z_command}" >/dev/null || buc_die_now "Function not found: ${z_command}"
    "${z_command}" "$@"
  else
    test -z "${z_command}" || buc_warn "Unknown command: ${z_command}"
    buc_set_doc_mode
    zbuc_show_help "${z_prefix}" "${z_title}" "${z_env_func}"
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
  local -r z_path="${1:?buc_native_path_capture: path required}"

  if test "${BURD_OSTYPE:-}" != "cygwin"; then
    printf '%s\n' "${z_path}"
    return 0
  fi

  case "${z_path}" in
    /cygdrive/?/*)
      local -r z_drive_rest="${z_path#/cygdrive/}"
      local -r z_drive="${z_drive_rest%%/*}"
      local -r z_drive_tail="${z_drive_rest#"${z_drive}/"}"
      printf '%s\n' "${z_drive}:/${z_drive_tail}"
      ;;
    /*)
      return 1
      ;;
    *)
      printf '%s\n' "${z_path}"
      ;;
  esac
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
  local -r z_text="${1:?buc_clipboard_copy_predicate: text required}"

  z_buc_clipboard_tool=""

  if test -n "${SSH_CONNECTION:-}"; then
    buc_log_args "Clipboard copy declined: SSH_CONNECTION stands, so the execution host is not the station and no clipboard reachable here is the operator's"
    return 1
  fi

  local z_copied=0
  if command -v pbcopy >/dev/null 2>&1; then
    z_buc_clipboard_tool="pbcopy"
    if printf '%s' "${z_text}" | pbcopy 2>/dev/null; then z_copied=1; fi
  elif command -v clip.exe >/dev/null 2>&1; then
    z_buc_clipboard_tool="clip.exe"
    if printf '%s' "${z_text}" | clip.exe 2>/dev/null; then z_copied=1; fi
  elif command -v wl-copy >/dev/null 2>&1; then
    z_buc_clipboard_tool="wl-copy"
    if printf '%s' "${z_text}" | wl-copy 2>/dev/null; then z_copied=1; fi
  elif command -v xclip >/dev/null 2>&1; then
    z_buc_clipboard_tool="xclip"
    if printf '%s' "${z_text}" | xclip -selection clipboard 2>/dev/null; then z_copied=1; fi
  fi

  test "${z_copied}" = "1"
}

# eof
