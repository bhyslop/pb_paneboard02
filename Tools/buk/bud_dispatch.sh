#!/bin/bash
#
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
# Bash Utility Regime Dispatch - Direct bash dispatch
#
# NOTE: This is bootstrap infrastructure, not a full module.
# No kindle/sentinel pattern - this runs before other modules are loaded.
# A dispatcher is external code by convention, and this file has no
# ZBUD_SOURCED guard, no kindle, and no buc_* to call: it is executed,
# not sourced, and it hand-rolls zbud_die/zbud_show because buc_command.sh
# is not loaded yet. Declaring a two-segment sentinel here would register
# the file as a module body to any structural reader.

set -euo pipefail
shopt -s extglob

# The surface forms of the governed words this dispatch speaks, so the lines
# below expand a constant instead of spelling the word. The sourced file is
# generated, declares readonly constants and calls nothing, and carries its own
# inclusion guard - so it is safe here, where buc_command.sh is not yet loaded,
# and a sibling sourcing the same file costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh"

BURE_VERBOSE=${BURE_VERBOSE:-0}

BURD_REGIME_FILE=${BURD_REGIME_FILE:-"__MISSING_BURD_REGIME_FILE__"}

# Utility function for verbose output
zbud_show() { test "$BURE_VERBOSE" != "1" || echo "BURDSHOW: $*"; }

# Enable trace mode if verbose level is 2
if test "${BURE_VERBOSE}" = "2"; then
  set -x
fi

zbud_die() { echo "FATAL: $*" >&2; exit 1; }

# String validator with optional length constraints
zbud_check_string() {
  local -r z_context="${1}"
  local -r z_varname="${2}"
  local z_val="${!z_varname:-}"
  local -r z_min="${3}"
  local -r z_max="${4}"

  test "${z_min}" != "0" -o -n "${z_val}" || return 0
  test -n "${z_val}" || zbud_die "[${z_context}] ${z_varname} must not be empty"

  if test -n "${z_max}"; then
    test ${#z_val} -ge "${z_min}" || zbud_die "[${z_context}] ${z_varname} must be at least ${z_min} chars, got '${z_val}' (${#z_val})"
    test ${#z_val} -le "${z_max}" || zbud_die "[${z_context}] ${z_varname} must be no more than ${z_max} chars, got '${z_val}' (${#z_val})"
  fi
}

# Source configuration and setup environment
zbud_setup() {
  zbud_show "Starting BDU setup"

  # Three log modes, and this flag stands beside neither other one. No-log
  # composes no names for a coordinator to write to, and interactive names the
  # uncurated tee this mode removes; either pair states two answers to one
  # question.
  if test -n "${BURD_AMANUENSIS:-}"; then
    test -z "${BURD_NO_LOG:-}"      || zbud_die "BURD_AMANUENSIS and BURD_NO_LOG are exclusive: no-log composes no log names to hand over"
    test -z "${BURD_INTERACTIVE:-}" || zbud_die "BURD_AMANUENSIS and BURD_INTERACTIVE are exclusive: the uncurated tee is what this mode removes"
  fi

  source            "${BURD_REGIME_FILE}"

  # Apply BURV (Bash Utility Regime Verification) overrides if set
  BURC_OUTPUT_ROOT_DIR="${BURV_OUTPUT_ROOT_DIR:-${BURC_OUTPUT_ROOT_DIR}}"
  BURC_TEMP_ROOT_DIR="${BURV_TEMP_ROOT_DIR:-${BURC_TEMP_ROOT_DIR}}"
  BURC_LOOSEBOX_ROOT_DIR="${BURV_LOOSEBOX_ROOT_DIR:-${BURC_LOOSEBOX_ROOT_DIR}}"

  zbud_check_string "${BURD_REGIME_FILE}" BURC_STATION_FILE        1 256
  zbud_check_string "${BURD_REGIME_FILE}" BURC_LOG_LAST            1 256
  zbud_check_string "${BURD_REGIME_FILE}" BURC_LOG_EXT             1 32
  zbud_check_string "${BURD_REGIME_FILE}" BURC_TABTARGET_DIR       1 256
  zbud_check_string "${BURD_REGIME_FILE}" BURC_TABTARGET_DELIMITER 1 8
  zbud_check_string "${BURD_REGIME_FILE}" BURC_TEMP_ROOT_DIR       1 256
  zbud_check_string "${BURD_REGIME_FILE}" BURC_OUTPUT_ROOT_DIR     1 256
  zbud_check_string "${BURD_REGIME_FILE}" BURC_LOOSEBOX_ROOT_DIR   1 256
  zbud_check_string "${BURD_REGIME_FILE}" BURC_TOOLS_DIR           1 256

  # Dispatch-provided directory variables (survive exec boundary for CLIs)
  BURD_TOOLS_DIR="${BURC_TOOLS_DIR}"
  BURD_BUK_DIR="${BURC_TOOLS_DIR}/buk"
  BURD_TABTARGET_DIR="${BURC_TABTARGET_DIR}"

  # The coordinator runs as its own process, so a station value reaches a kit's
  # CLI only by riding a BURD_ variable across that boundary. Declared here and
  # left empty for the no-log path below, which sources no station file at all.
  BURD_TACKROOM=""

  export BURD_TOOLS_DIR BURD_BUK_DIR BURD_TABTARGET_DIR BURD_TACKROOM

  # Source station file (skip for no-log handbook tabtargets)
  if test -z "${BURD_NO_LOG:-}"; then
    zbud_show "Sourcing station file: ${BURC_STATION_FILE}"
    source                           "${BURC_STATION_FILE}"

    # Apply BURV (Bash Utility Regime Verification) overrides if set
    BURS_LOG_DIR="${BURV_LOG_DIR:-${BURS_LOG_DIR}}"
    BURD_TACKROOM="${BURV_TACKROOM:-${BURS_TACKROOM:-}}"

    # Absolutize a relative tackroom against the repo root, the same idiom the
    # temp directory takes below: z-launcher normalizes cwd to the repo root, so
    # a station value may be written relative exactly as the log directory is.
    case "${BURD_TACKROOM}" in
      ""|/*) ;;
      *)     BURD_TACKROOM="${PWD}/${BURD_TACKROOM}" ;;
    esac

    # Validate station variables
    zbud_check_string "${BURC_STATION_FILE}" BURS_LOG_DIR 1 256
  fi

  mkdir -p "${BURC_TEMP_ROOT_DIR}" || zbud_die "Failed to create temp root: ${BURC_TEMP_ROOT_DIR}"
  local -r z_date_file="${BURC_TEMP_ROOT_DIR}/bud_bootstrap_date.txt"
  date +'%Y%m%d-%H%M%S %s' > "${z_date_file}" || zbud_die "Failed to get datetime"
  local z_datetime
  z_datetime=$(<"${z_date_file}")
  test -n "${z_datetime}" || zbud_die "Empty datetime from ${z_date_file}"
  BURD_NOW_STAMP="${z_datetime% *}-$$-$((RANDOM % 1000))"
  BURD_NOW_EPOCH="${z_datetime#* }"
  zbud_show "Generated timestamp: ${BURD_NOW_STAMP} epoch: ${BURD_NOW_EPOCH}"

  BURD_TEMP_DIR="${BURC_TEMP_ROOT_DIR}/temp-${BURD_NOW_STAMP}"
  case "${BURD_TEMP_DIR}" in
    /*) ;;
    *)  BURD_TEMP_DIR="${PWD}/${BURD_TEMP_DIR}" ;;
  esac
  mkdir -p                           "${BURD_TEMP_DIR}" || zbud_die "Failed to create temp directory: ${BURD_TEMP_DIR}"

  # SETTLED THROUGH THE FILESYSTEM, not merely prefixed. A relative root may
  # spell a parent segment (a station's own regime can state "../temp-buk",
  # a directory beside the checkout rather than beneath it); the working
  # directory prefix above leaves that segment standing literally, and a
  # consumer that compares this announced path against a canonical answer —
  # cargo's, or a nested shell's own re-derived cwd — never matches it.
  # `cd -P` resolves both the parent segment and any symlink on the way;
  # bash builtins only.
  BURD_TEMP_DIR="$(cd -P "${BURD_TEMP_DIR}" && pwd -P)" || zbud_die "Failed to settle temp directory: ${BURD_TEMP_DIR}"
  zbud_show "Generated temporary dir: ${BURD_TEMP_DIR}"

  # Setup transcript file path
  BURD_TRANSCRIPT="${BURD_TEMP_DIR}/transcript.txt"

  # The checkout's own loosebox, where its derived and rebuildable build
  # products stand. IT IS KEYED ON THE CHECKOUT'S DIRNAME AND THAT IS THE WHOLE
  # OF WHAT MAKES IT SAFE TO SHARE A ROOT: on a plain station the root sits
  # beside the checkouts and several of them reach it, so a key that were
  # anything less than the directory each stands in would hand one checkout's
  # products to another. z-launcher normalizes cwd to the repo root, so PWD's
  # own basename IS that dirname.
  #
  # THE KEY IS THE SAME UNDER A STILE, where the harness composes the root
  # beneath a scratch container the billet's dirname already keys. The dirname
  # then appears twice on the path — once as the container's key, once here.
  # That is the ruling and not a defect to repair: this composition holds one
  # rule for both seats, and a composition that dropped the key where it looked
  # redundant would be a second rule to keep in step.
  BURD_LOOSEBOX_DIR="${BURC_LOOSEBOX_ROOT_DIR}/${PWD##*/}"
  case "${BURD_LOOSEBOX_DIR}" in
    /*) ;;
    *)  BURD_LOOSEBOX_DIR="${PWD}/${BURD_LOOSEBOX_DIR}" ;;
  esac
  mkdir -p                           "${BURD_LOOSEBOX_DIR}" || zbud_die "Failed to create ${BUBG_LOOSEBOX_ROOT_DIR_BASE}: ${BURD_LOOSEBOX_DIR}"

  # SETTLED for the same reason the temp directory is settled above: a
  # relative loosebox root may spell a parent segment too.
  BURD_LOOSEBOX_DIR="$(cd -P "${BURD_LOOSEBOX_DIR}" && pwd -P)" || zbud_die "Failed to settle ${BUBG_LOOSEBOX_ROOT_DIR_BASE}: ${BURD_LOOSEBOX_DIR}"
  zbud_show "The ${BUBG_LOOSEBOX_ROOT_DIR_BASE} is ready: ${BURD_LOOSEBOX_DIR}"

  # Setup output directories under the output root (both fixed locations).
  #   current/  = this dispatch's outputs (fresh each run).
  #   previous/ = the prior dispatch's current/, promoted here at dispatch
  #               start. Promotion is EXIT-STATUS-INDEPENDENT — it runs before
  #               this dispatch does any work, so the prior run's outputs are
  #               forwarded regardless of how it exited (fail-after-forward
  #               still passes the baton). The current/+previous/ pair is the
  #               depth-1 cross-tabtarget chain; no deeper history is kept.
  BURD_OUTPUT_DIR="${BURC_OUTPUT_ROOT_DIR}/current"
  BURD_PREVIOUS_DIR="${BURC_OUTPUT_ROOT_DIR}/previous"
  case "${BURD_OUTPUT_DIR}" in
    /*) ;;
    *)  BURD_OUTPUT_DIR="${PWD}/${BURD_OUTPUT_DIR}" ;;
  esac
  case "${BURD_PREVIOUS_DIR}" in
    /*) ;;
    *)  BURD_PREVIOUS_DIR="${PWD}/${BURD_PREVIOUS_DIR}" ;;
  esac

  # Promote prior current/ -> previous/, then create a fresh empty current/.
  # current/ and previous/ are siblings under one root, so mv is always an
  # atomic same-filesystem rename — never a byte copy. It relocates the prior
  # outputs (replacing the old unconditional rm of current/) rather than
  # destroying them. First drop the generation older than one, then promote.
  if test -d "${BURD_PREVIOUS_DIR}"; then
    zbud_show "Dropping stale previous directory: ${BURD_PREVIOUS_DIR}"
    rm -rf "${BURD_PREVIOUS_DIR}" || zbud_die "Failed to remove previous directory: ${BURD_PREVIOUS_DIR}"
  fi
  if test -d "${BURD_OUTPUT_DIR}"; then
    zbud_show "Promoting prior output to previous: ${BURD_OUTPUT_DIR} -> ${BURD_PREVIOUS_DIR}"
    mv "${BURD_OUTPUT_DIR}" "${BURD_PREVIOUS_DIR}" || zbud_die "Failed to promote output directory to previous: ${BURD_OUTPUT_DIR}"
  fi
  mkdir -p "${BURD_OUTPUT_DIR}" || zbud_die "Failed to create output directory: ${BURD_OUTPUT_DIR}"

  # SETTLED for the same reason the temp directory is settled above. The
  # previous directory is not itself settled by a cd — it need not exist yet
  # on a first-ever dispatch — but is instead rederived as the settled
  # output directory's own sibling, which carries no parent segment either.
  BURD_OUTPUT_DIR="$(cd -P "${BURD_OUTPUT_DIR}" && pwd -P)" || zbud_die "Failed to settle output directory: ${BURD_OUTPUT_DIR}"
  BURD_PREVIOUS_DIR="${BURD_OUTPUT_DIR%/*}/previous"

  zbud_show "Output directory ready: ${BURD_OUTPUT_DIR} (previous: ${BURD_PREVIOUS_DIR})"

  # Get Git context
  local -r z_git_context_file="${BURD_TEMP_DIR}/bud_git_context.txt"
  local -r z_git_context_stderr="${BURD_TEMP_DIR}/bud_git_context_stderr.txt"
  if git describe --always --dirty --tags --long > "${z_git_context_file}" 2>"${z_git_context_stderr}"; then
    BURD_GIT_CONTEXT=$(<"${z_git_context_file}")
  else
    BURD_GIT_CONTEXT="git-unavailable"
  fi
  zbud_show "Git context: ${BURD_GIT_CONTEXT}"

  # Platform fact for native binaries (e.g. theurge) that cannot inherit bash's
  # own $OSTYPE across the process boundary — synthesized live each dispatch and
  # delivered through the exported BURD_ channel. The native bash path is derived
  # inside theurge via cygpath, keeping cygpath out of kit bash.
  BURD_OSTYPE="${OSTYPE}"
  zbud_show "Platform: ${BURD_OSTYPE}"

  # Export for child processes
  export BURD_TEMP_DIR
  export BURD_LOOSEBOX_DIR
  export BURD_OUTPUT_DIR
  export BURD_PREVIOUS_DIR
  export BURD_NOW_STAMP
  export BURD_NOW_EPOCH
  export BURD_TRANSCRIPT
  export BURD_GIT_CONTEXT
  export BURD_OSTYPE

  return 0
}

# Process command-line arguments
zbud_process_args() {
  local -r z_target="${1}"
  shift

  zbud_show "Processing target: ${z_target}"

  # Extract tokens from tabtarget
  local -a z_tokens
  IFS="${BURC_TABTARGET_DELIMITER}" read -ra z_tokens <<< "${z_target}"
  zbud_show "Split tokens: ${z_tokens[*]}"

  # Store primary command token (legacy, equivalent to BURD_TOKEN_1)
  BURD_COMMAND="${z_tokens[0]}"

  # Explode tokens into numbered variables for workbench access
  # Pattern matches MBC_TTPARAM__FIRST through MBC_TTPARAM__FIFTH
  BURD_TOKEN_1="${z_tokens[0]:-}"
  BURD_TOKEN_2="${z_tokens[1]:-}"
  BURD_TOKEN_3="${z_tokens[2]:-}"
  BURD_TOKEN_4="${z_tokens[3]:-}"
  BURD_TOKEN_5="${z_tokens[4]:-}"

  export BURD_TOKEN_1 BURD_TOKEN_2 BURD_TOKEN_3 BURD_TOKEN_4 BURD_TOKEN_5

  # Create tag for log files
  local -r z_tag="${z_tokens[0]}-${z_tokens[2]:-unknown}"

  # Setup log paths and files (skip entirely for no-log tabtargets)
  if test -z "${BURD_NO_LOG:-}"; then
    BURD_LOG_LAST="${BURS_LOG_DIR}/${BURC_LOG_LAST}.${BURC_LOG_EXT}"
    BURD_LOG_SAME="${BURS_LOG_DIR}/same-${z_tag}.${BURC_LOG_EXT}"
    BURD_LOG_HIST="${BURS_LOG_DIR}/hist-${z_tag}-${BURD_NOW_STAMP}.${BURC_LOG_EXT}"
    mkdir -p "${BURS_LOG_DIR}"
    if test -n "${BURD_AMANUENSIS:-}"; then
      # The names are the dispatch's and the writing is the coordinator's, so
      # the three cross the exec boundary here and nowhere else. No file is
      # created: an absent member after this dispatch says the coordinator
      # wrote none, where an empty file this dispatch had touched would lie.
      export BURD_LOG_LAST BURD_LOG_SAME BURD_LOG_HIST
    else
      : > "${BURD_LOG_LAST}"
      : > "${BURD_LOG_SAME}"
      : > "${BURD_LOG_HIST}"
    fi
  fi

  # Store target and extra arguments
  BURD_TARGET="${z_target}"
  BURD_CLI_ARGS=("$@")

  # Export command context for workbench access
  export BURD_COMMAND
  export BURD_TARGET
  export BURD_CLI_ARGS

  return 0
}

# Function to curate logs for the 'same' log file (normalized output)
zbud_curate_same() {
  # Convert to unix line endings, strip colors, normalize temp dir, remove VOLATILE lines
  local z_line
  while IFS= read -r z_line || test -n "${z_line}"; do
    test -n "${z_line}" || continue
    z_line="${z_line//$'\x1b'\[*([0-9;])[a-zA-Z]/}"
    z_line="${z_line//$'\x1b'\([A-Z]/}"
    z_line="${z_line//${BURD_TEMP_DIR}/BURD_EPHEMERAL_DIR}"
    case "${z_line}" in
      *VOLATILE*) continue ;;
    esac
    local -a z_frames
    IFS=$'\r' read -ra z_frames <<< "${z_line}"
    local z_frame
    if test "${#z_frames[@]}" -gt 0; then
      for z_frame in "${z_frames[@]}"; do
        printf '%s\n' "${z_frame}"
      done
    else
      printf '\n'
    fi
  done
}

# Function to curate the historical log file (with timestamps). Reads the
# coordinator's raw stream on stdin; the caller opens fd 3 onto BURD_LOG_HIST,
# so each line's stamped form is appended there directly while the line itself
# passes through untouched on stdout — the one filter does both jobs the fifo
# pair used to split across two processes.
zbud_curate_hist() {
  # The trailing `|| test -n` guard matches zbud_curate_same's: a coordinator
  # whose final line carries no newline still gets stamped. Under the retired
  # per-line plumbing the dispatch's own read loop dropped that line before
  # either curate function saw it, so all three logs lost it alike; a stream
  # fed by tee delivers it, and without this guard hist alone would drop what
  # the same and last logs now keep.
  #
  # The stamp itself is taken by printf where bash can convert one (4.2+), and
  # by a forked date where it cannot. That fork is the single largest cost left
  # in the curation of a chatty door, and the floor this kit builds to is bash
  # 3.2, so both arms have to stand; the version verdict is reached once, ahead
  # of the loop, and the two arms emit the same bytes.
  #
  # `IFS=` matches zbud_curate_same's read for a reason this log carries alone.
  # Under the default IFS a read strips the leading and trailing whitespace off
  # every line it takes, so a stamped line's content began at its first
  # non-blank byte — and a table carved out of this log then differed, byte for
  # byte, from the same table carved out of a capture that kept its indentation.
  # Sessions compare saved tables across two positions of the record, and this
  # log is the only re-read channel a tabtarget leaves them, so the timestamp
  # prefix stands and the bytes after it are the coordinator's own.
  local z_stamp_is_builtin=0
  if test "${BASH_VERSINFO[0]}" -gt 4 || { test "${BASH_VERSINFO[0]}" -eq 4 && test "${BASH_VERSINFO[1]}" -ge 2; }; then
    z_stamp_is_builtin=1
  fi

  local z_line
  while IFS= read -r z_line || test -n "${z_line}"; do
    if test "${z_stamp_is_builtin}" -eq 1; then
      printf "[%(%Y-%m-%d %H:%M:%S)T] %s\n" -1 "${z_line}" >&3
    else
      printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "${z_line}" >&3
    fi
    printf '%s\n' "${z_line}"
  done
}

# Generate and log checksum for a file
zbud_generate_checksum() {
  local -r z_file="${1}"
  local -r z_output_file="${2}"

  local z_checksum
  z_checksum=$(openssl dgst -sha256 -r "${z_file}" 2>/dev/null) || z_checksum="checksum-unavailable"
  read -r z_checksum _ <<< "${z_checksum}"

  echo "Same log checksum: ${z_checksum}" >> "${z_output_file}"
  return 0
}

# Resolve color policy once at dispatch time and export the verdict as
# BURD_COLOR (0/1) — a dispatch-computed value, never an operator-set BURE_
# input (BUr_q2m). BURE_COLOR stays readable here as the optional operator
# override it always was, but dispatch never writes it: a verdict left under
# the BURE_ prefix crosses a spawn boundary as if it were operator ambient
# (BURE_ passes by design), so the child reads a stale pin as an explicit
# override and never re-derives its own.
zbud_resolve_color() {
  if test -n "${NO_COLOR:-}"; then
    export BURD_COLOR=0
    return 0
  fi
  case "${BURE_COLOR:-auto}" in
    0|1)
      export BURD_COLOR="${BURE_COLOR}"
      ;;
    auto|*)
      if test -t 1 && test "${TERM:-}" != "dumb"; then
          export BURD_COLOR=1
      else
          export BURD_COLOR=0
      fi
      ;;
  esac
}

# Write a fixed-width timestamp (YYYYMMDD-HHMMSS.NNNNNNNNN) to the file at $1.
# Sub-second precision is not load-bearing — the nanosecond field is always
# zero — but the fixed width is preserved for stable downstream BURX parsing.
zbud_nanosecond_timestamp() {
  local -r z_output_file="${1}"
  date +'%Y%m%d-%H%M%S.000000000' > "${z_output_file}" || zbud_die "date failed"
}

zbud_write_burx_initial() {
  local -r z_ts_file="${BURD_TEMP_DIR}/zbud_began_at.txt"
  zbud_nanosecond_timestamp "${z_ts_file}"
  local -r z_began_at=$(<"${z_ts_file}")
  test -n "${z_began_at}" || zbud_die "Empty began_at timestamp"

  local -r z_label="${BURE_LABEL:-}"
  local -r z_content="BURX_PID=$$
BURX_BEGAN_AT=${z_began_at}
BURX_TABTARGET=${BURD_TARGET}
BURX_TEMP_DIR=${BURD_TEMP_DIR}
BURX_TRANSCRIPT=${BURD_TRANSCRIPT}
BURX_LOG_HIST=${BURD_LOG_HIST:-}
BURX_LABEL=${z_label}"
  buf_write_fact_single "${BUF_burx_env}" "${z_content}"
}

zbud_write_burx_completion() {
  local -r z_exit_status="${1}"
  local -r z_ts_file="${BURD_TEMP_DIR}/zbud_ended_at.txt"
  zbud_nanosecond_timestamp "${z_ts_file}"
  local -r z_ended_at=$(<"${z_ts_file}")
  test -n "${z_ended_at}" || zbud_die "Empty ended_at timestamp"

  printf 'BURX_EXIT_STATUS=%s\nBURX_ENDED_AT=%s\n' "${z_exit_status}" "${z_ended_at}" >> "${BURD_OUTPUT_DIR}/${BUF_burx_env}"
  printf 'BURX_EXIT_STATUS=%s\nBURX_ENDED_AT=%s\n' "${z_exit_status}" "${z_ended_at}" >> "${BURD_TEMP_DIR}/${BUF_burx_env}"
}

zbud_main() {
  zbud_show "Starting BDU dispatch"

  # Decide color policy before stdout is piped
  zbud_resolve_color

  # Setup environment
  zbud_setup || { echo "ERROR: Environment setup failed" >&2; exit 1; }
  zbud_show "Environment setup complete"

  # Source fact-file module for BURX writes
  source "${BURC_TOOLS_DIR}/buk/buf_fact.sh"

  # Process arguments
  zbud_process_args "$@" || { echo "ERROR: Argument processing failed" >&2; exit 1; }
  zbud_show "Arguments processed"

  # Write initial BURX exchange state
  zbud_write_burx_initial

  # Detect unexpected BURD_ variables
  local -r z_known="BURD_CONFIG_DIR BURD_MOORINGS_DIR BURD_REGIME_FILE BURD_NO_LOG BURD_INTERACTIVE BURD_AMANUENSIS BURD_OUTRIDER BURD_COORDINATOR_SCRIPT BURD_LAUNCHER BURD_STATION_FILE BURD_TERM_COLS BURD_NOW_STAMP BURD_NOW_EPOCH BURD_TEMP_DIR BURD_LOOSEBOX_DIR BURD_OUTPUT_DIR BURD_PREVIOUS_DIR BURD_TRANSCRIPT BURD_GIT_CONTEXT BURD_LOG_LAST BURD_LOG_SAME BURD_LOG_HIST BURD_COMMAND BURD_TARGET BURD_CLI_ARGS BURD_TOKEN_1 BURD_TOKEN_2 BURD_TOKEN_3 BURD_TOKEN_4 BURD_TOKEN_5 BURD_TOOLS_DIR BURD_BUK_DIR BURD_TABTARGET_DIR BURD_TACKROOM BURD_OSTYPE BURD_COLOR"
  z_bud_unexpected=()
  local z_var
  for z_var in $(compgen -v BURD_); do
    case " ${z_known} " in
      *" ${z_var} "*) : ;;
      *) z_bud_unexpected+=("${z_var}") ;;
    esac
  done

  # Die on unexpected variables
  if test ${#z_bud_unexpected[@]} -gt 0; then
    zbud_die "Unexpected BURD_ variables: ${z_bud_unexpected[*]}"
  fi

  # Build complete invocation array (always has ≥2 elements, so always safe under set -u)
  local -r z_coordinator_cmd="${BURD_COORDINATOR_SCRIPT}"
  local -a z_invocation=("${z_coordinator_cmd}" "${BURD_COMMAND}")
  if test ${#BURD_CLI_ARGS[@]} -gt 0; then
    z_invocation+=("${BURD_CLI_ARGS[@]}")
  fi
  zbud_show "Coordinator command: ${z_invocation[*]}"

  # Log command to all log files (or suppress all output if BURD_NO_LOG)
  if test -z "${BURD_NO_LOG:-}"; then
    if test -n "${BURD_AMANUENSIS:-}"; then
      # The invocation and git-context lines belong to whoever writes the
      # record, and under this mode that is the coordinator (BUr_fbc). The
      # dispatch announces the paths it composed and writes nothing into them.
      echo "log files:   ${BURD_LOG_LAST} ${BURD_LOG_SAME} ${BURD_LOG_HIST}"
    elif test -n "${BURD_INTERACTIVE:-}"; then
      echo "log (interactive): ${BURD_LOG_HIST}"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_HIST}"
      echo "Git context: ${BURD_GIT_CONTEXT}"  >> "${BURD_LOG_HIST}"
    else
      echo "log files:   ${BURD_LOG_LAST} ${BURD_LOG_SAME} ${BURD_LOG_HIST}"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_LAST}"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_SAME}"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_HIST}"
      echo "Git context: ${BURD_GIT_CONTEXT}"  >> "${BURD_LOG_HIST}"
    fi
    echo "transcript:  ${BURD_TRANSCRIPT}"
    echo "output dir:  ${BURD_OUTPUT_DIR}"
    echo "${BUBG_LOOSEBOX_ROOT_DIR_BASE}:    ${BURD_LOOSEBOX_DIR}"
  fi

  zbud_show "Executing coordinator"

  # Execute coordinator with logging
  set +e
  z_bud_status_file="${BURD_TEMP_DIR}/status-$$"
  if test -n "${BURD_AMANUENSIS:-}" || test -n "${BURD_NO_LOG:-}"; then
    # The two modes in which this dispatch tees nothing, for opposite reasons:
    # no-log because there is no record, amanuensis because the record is the
    # coordinator's to write. Both leave the child's streams untouched, so the
    # arm is one. It stands first because the interactive test below no longer
    # has to exclude no-log by hand.
    {
      "${z_invocation[@]}"
      echo $? > "${z_bud_status_file}"
      zbud_show "Coordinator status: $(cat "${z_bud_status_file}")"
    }
  elif test -n "${BURD_INTERACTIVE:-}"; then
    # Interactive mode with logging: uncurated tee to historical log, preserves line buffering
    "${z_invocation[@]}" 2>&1 | tee -a "${BURD_LOG_HIST}"
    z_bud_exit_status=${PIPESTATUS[0]}
    echo "${z_bud_exit_status}" > "${z_bud_status_file}"
    zbud_show "Coordinator status (interactive): ${z_bud_exit_status}"
  else
    # Non-interactive with logging. tee replicates the raw stream to the last
    # log and to a private per-invocation capture under BURD_TEMP_DIR, then
    # hands the remainder to the one long-lived hist filter — it stamps each
    # line onto fd 3 (opened here onto BURD_LOG_HIST) and passes the line
    # through untouched on its own stdout, so the terminal stays live on the
    # fd it always has. Both filters keep the "pay for a chatty door's output
    # once" shape the fifo pair had; only the plumbing between them changes.
    # The same log is derived from the private capture once the pipeline
    # returns — sequentially, nothing to wait on — and never from the shared
    # last log, which every tabtarget writing into BURS_LOG_DIR shares.
    local -r z_raw_capture="${BURD_TEMP_DIR}/raw-capture-$$"

    {
      "${z_invocation[@]}" 2>&1
      echo $? > "${z_bud_status_file}"
      zbud_show "Coordinator status: $(cat "${z_bud_status_file}")"
    } | tee -a "${BURD_LOG_LAST}" "${z_raw_capture}" | zbud_curate_hist 3>>"${BURD_LOG_HIST}"

    zbud_curate_same < "${z_raw_capture}" >> "${BURD_LOG_SAME}"
    rm -f "${z_raw_capture}"
  fi

  z_bud_exit_status=$(<"${z_bud_status_file}")
  rm                     "${z_bud_status_file}"

  # Write BURX completion state
  zbud_write_burx_completion "${z_bud_exit_status}"

  set -e

  # Generate checksum for the log files (only when this dispatch wrote them).
  # Under the amanuensis mode the digest is the coordinator's, taken after the
  # last byte of the same log is written, because only the writer knows when
  # that is (BUr_yht).
  if test -z "${BURD_NO_LOG:-}" && test -z "${BURD_AMANUENSIS:-}"; then
    zbud_generate_checksum "${BURD_LOG_SAME}" "${BURD_LOG_HIST}"
    zbud_show "Checksum generated"
  fi

  zbud_show "BDU completed with status: ${z_bud_exit_status}"

  exit "${z_bud_exit_status}"
}

# Direct execution only — sourcing (e.g. a test harness calling
# zbud_resolve_color in isolation) defines the functions without re-running
# a whole dispatch.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  zbud_main "$@"
fi

# eof
