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

zbud_die() { echo "FATAL: $*" >&2 || exit 1; exit 1; }

# The surface forms of the governed words this dispatch speaks, so the lines
# below expand a constant instead of spelling the word. The sourced file is
# generated, declares readonly constants and calls nothing, and carries its own
# inclusion guard - so it is safe here, where buc_command.sh is not yet loaded,
# and a sibling sourcing the same file costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" \
  || zbud_die "Failed to source ${BASH_SOURCE[0]%/*}/bubg_breviary.sh"

# The configuration words this dispatch answers to, from the kit's constants,
# which declare readonly constants and call nothing.
source "${BASH_SOURCE[0]%/*}/bubc_constants.sh" \
  || zbud_die "Failed to source ${BASH_SOURCE[0]%/*}/bubc_constants.sh"

BURE_VERBOSE=${BURE_VERBOSE:-0}
case "${BURE_VERBOSE}" in
  0|1|2|3) ;;
  *) zbud_die "BURE_VERBOSE must be 0, 1, 2 or 3, got: ${BURE_VERBOSE}" ;;
esac

# The exchange file's lines as zbud_burx_append composes them, each set written
# whole once composed.
z_bud_burx_text=""

# The dispatch's own internals, which never enter the dispatch regime: the
# coordinator and the configuration's own-log word (zbud_main), the command
# token and the argument list (zbud_process_args).
z_bud_coordinator_script=""
z_bud_amanuensis=""
z_bud_command=""
z_bud_cli_args=()

# The verbose line rides stderr, so it never enters the coordinator's logs.
zbud_show() { test "${BURE_VERBOSE}" != "1" || echo "BURDSHOW: $*" >&2 || zbud_die "Failed to write a verbose line"; }

if test "${BURE_VERBOSE}" = "2"; then
  set -x
fi

# String validator with optional length constraints
zbud_check_string() {
  local -r z_context="${1}"
  local -r z_varname="${2}"
  local -r z_name_lead="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
  [[ "${z_varname}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] \
    || zbud_die "[${z_context}] invalid variable name: '${z_varname}'"
  local z_val="${!z_varname:-}"
  local -r z_min="${3}"
  local -r z_max="${4}"

  test "${z_min}" != "0" -o -n "${z_val}" || return 0
  test -n "${z_val}" || zbud_die "[${z_context}] ${z_varname} must not be empty"

  if test -n "${z_max}"; then
    test "${#z_val}" -ge "${z_min}" || zbud_die "[${z_context}] ${z_varname} must be at least ${z_min} chars, got '${z_val}' (${#z_val})"
    test "${#z_val}" -le "${z_max}" || zbud_die "[${z_context}] ${z_varname} must be no more than ${z_max} chars, got '${z_val}' (${#z_val})"
  fi
}

# Source configuration and setup environment
zbud_setup() {
  zbud_show "Starting BDU setup"

  # Three log modes, and the own-log word stands beside neither other one.
  # No-log composes no names for a coordinator to write to, and interactive
  # names the uncurated tee this mode removes; either pair states two answers
  # to one question. The launcher refuses the pair on the configuration line,
  # so this check stands behind it for a dispatch entered any other way.
  if test -n "${z_bud_amanuensis}"; then
    test -z "${BURD_NO_LOG}"      || zbud_die "buuc_ownlog and buuc_nolog are exclusive: buuc_nolog composes no member names to hand over"
    test -z "${BURD_INTERACTIVE}" || zbud_die "buuc_ownlog and buuc_interactive are exclusive: the uncurated tee is what this mode removes"
  fi

  # The config regime, read from its file. The launcher has kindled and
  # enforced it from the same file in its own process, and nothing exports it,
  # so this dispatch reads it again rather than inheriting it.
  test -n "${BURD_REGIME_FILE:-}" \
    || zbud_die "BURD_REGIME_FILE is not set - bul_launcher.sh names the config regime this dispatch sources"
  source            "${BURD_REGIME_FILE}" || zbud_die "Failed to source the regime file: ${BURD_REGIME_FILE}"

  # The station file, named by the config regime against the project root,
  # where the trampoline left this process standing.
  BURD_STATION_FILE="${PWD}/${BURC_STATION_FILE}"

  # BURV (Bash Utility Regime Verification) overrides, where set
  BURC_OUTPUT_ROOT_DIR="${BURV_OUTPUT_ROOT_DIR:-${BURC_OUTPUT_ROOT_DIR}}"
  BURC_TEMP_ROOT_DIR="${BURV_TEMP_ROOT_DIR:-${BURC_TEMP_ROOT_DIR}}"
  BURC_LOOSEBOX_ROOT_DIR="${BURV_LOOSEBOX_ROOT_DIR:-${BURC_LOOSEBOX_ROOT_DIR}}"

  # Dispatch-provided directory variables, written into the dispatch file. The
  # kit directory alone crosses the exec as well, beside the pointer, so a
  # child finds the kit's reader of that file.
  BURD_TOOLS_DIR="${BURC_TOOLS_DIR}"
  BURD_BUK_DIR="${BURC_TOOLS_DIR}/buk"
  BURD_TABTARGET_DIR="${BURC_TABTARGET_DIR}"

  # A station value reaches a kit's CLI through the dispatch file, under a
  # BURD_ name. Declared here and left empty for the no-log path below, which
  # sources no station file at all.
  BURD_TACKROOM=""

  # Source station file (skip for no-log handbook tabtargets)
  if test -z "${BURD_NO_LOG}"; then
    zbud_show "Sourcing station file: ${BURC_STATION_FILE}"
    source                           "${BURC_STATION_FILE}" || zbud_die "Failed to source the station file: ${BURC_STATION_FILE}"

    BURS_LOG_DIR="${BURV_LOG_DIR:-${BURS_LOG_DIR}}"

    # The tackroom is optional to the station regime, so an absent line reads
    # as the empty value a kit's own refusal then speaks to, never as an
    # unbound variable.
    BURD_TACKROOM="${BURV_TACKROOM:-${BURS_TACKROOM:-}}"

    # Absolutize a relative tackroom against the repo root, the same idiom the
    # temp directory takes below: z-launcher normalizes cwd to the repo root, so
    # a station value may be written relative exactly as the log directory is.
    case "${BURD_TACKROOM}" in
      ""|/*) ;;
      *)     BURD_TACKROOM="${PWD}/${BURD_TACKROOM}" ;;
    esac

    zbud_check_string "${BURC_STATION_FILE}" BURS_LOG_DIR 1 256
  fi

  mkdir -p "${BURC_TEMP_ROOT_DIR}" || zbud_die "Failed to create temp root: ${BURC_TEMP_ROOT_DIR}"
  local z_datetime
  z_datetime=$(date +'%Y%m%d-%H%M%S %s') || zbud_die "Failed to get datetime"
  test -n "${z_datetime}" || zbud_die "Empty datetime from date"
  BURD_NOW_STAMP="${z_datetime% *}-${$}-$((RANDOM % 1000))"
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
  # bash builtins only. The isolation subshell writes its answer to a file in
  # the directory it settles, read back in the one form.
  local -r z_settled_temp_file="${BURD_TEMP_DIR}/bud_settled_temp_dir.txt"
  (
    cd -P "${BURD_TEMP_DIR}" || zbud_die "Failed to enter temp directory: ${BURD_TEMP_DIR}"
    pwd -P                   || zbud_die "Failed to read the settled temp directory"
  ) > "${z_settled_temp_file}" || zbud_die "Failed to settle temp directory: ${BURD_TEMP_DIR}"
  BURD_TEMP_DIR=$(<"${z_settled_temp_file}") || zbud_die "Failed to read: ${z_settled_temp_file}"
  test -n "${BURD_TEMP_DIR}" || zbud_die "Empty settled path in ${z_settled_temp_file}"
  zbud_show "Generated temporary dir: ${BURD_TEMP_DIR}"

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
  #
  # THE FOLDED ROOT IS RECORDED BESIDE IT, made absolute against the project
  # root, so a door handing a child the root its own loosebox was keyed beneath
  # reads it here rather than climbing out of the directory composed below it.
  BURD_LOOSEBOX_ROOT_DIR="${BURC_LOOSEBOX_ROOT_DIR}"
  case "${BURD_LOOSEBOX_ROOT_DIR}" in
    /*) ;;
    *)  BURD_LOOSEBOX_ROOT_DIR="${PWD}/${BURD_LOOSEBOX_ROOT_DIR}" ;;
  esac
  BURD_LOOSEBOX_DIR="${BURC_LOOSEBOX_ROOT_DIR}/${PWD##*/}"
  case "${BURD_LOOSEBOX_DIR}" in
    /*) ;;
    *)  BURD_LOOSEBOX_DIR="${PWD}/${BURD_LOOSEBOX_DIR}" ;;
  esac
  mkdir -p                           "${BURD_LOOSEBOX_DIR}" || zbud_die "Failed to create ${BUBG_LOOSEBOX_BASE}: ${BURD_LOOSEBOX_DIR}"

  # SETTLED for the same reason the temp directory is settled above: a
  # relative loosebox root may spell a parent segment too.
  local -r z_settled_loosebox_file="${BURD_TEMP_DIR}/bud_settled_loosebox_dir.txt"
  (
    cd -P "${BURD_LOOSEBOX_DIR}" || zbud_die "Failed to enter ${BUBG_LOOSEBOX_BASE}: ${BURD_LOOSEBOX_DIR}"
    pwd -P                       || zbud_die "Failed to read the settled ${BUBG_LOOSEBOX_BASE}"
  ) > "${z_settled_loosebox_file}" || zbud_die "Failed to settle ${BUBG_LOOSEBOX_BASE}: ${BURD_LOOSEBOX_DIR}"
  BURD_LOOSEBOX_DIR=$(<"${z_settled_loosebox_file}") || zbud_die "Failed to read: ${z_settled_loosebox_file}"
  test -n "${BURD_LOOSEBOX_DIR}" || zbud_die "Empty settled path in ${z_settled_loosebox_file}"
  zbud_show "The ${BUBG_LOOSEBOX_BASE} is ready: ${BURD_LOOSEBOX_DIR}"

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
  # outputs rather than destroying them. First drop the generation older than
  # one, then promote.
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
  local -r z_settled_output_file="${BURD_TEMP_DIR}/bud_settled_output_dir.txt"
  (
    cd -P "${BURD_OUTPUT_DIR}" || zbud_die "Failed to enter output directory: ${BURD_OUTPUT_DIR}"
    pwd -P                     || zbud_die "Failed to read the settled output directory"
  ) > "${z_settled_output_file}" || zbud_die "Failed to settle output directory: ${BURD_OUTPUT_DIR}"
  BURD_OUTPUT_DIR=$(<"${z_settled_output_file}") || zbud_die "Failed to read: ${z_settled_output_file}"
  test -n "${BURD_OUTPUT_DIR}" || zbud_die "Empty settled path in ${z_settled_output_file}"
  BURD_PREVIOUS_DIR="${BURD_OUTPUT_DIR%/*}/previous"

  zbud_show "Output directory ready: ${BURD_OUTPUT_DIR} (previous: ${BURD_PREVIOUS_DIR})"

  local -r z_git_context_file="${BURD_TEMP_DIR}/bud_git_context.txt"
  local -r z_git_context_stderr="${BURD_TEMP_DIR}/bud_git_context_stderr.txt"
  if git describe --always --dirty --tags --long > "${z_git_context_file}" 2>"${z_git_context_stderr}"; then
    BURD_GIT_CONTEXT=$(<"${z_git_context_file}") || zbud_die "Failed to read: ${z_git_context_file}"
    test -n "${BURD_GIT_CONTEXT}" || zbud_die "Empty git context in ${z_git_context_file}"
  else
    BURD_GIT_CONTEXT="git-unavailable(see:${z_git_context_stderr})"
  fi
  zbud_show "Git context: ${BURD_GIT_CONTEXT}"

  # Platform fact for native binaries (e.g. theurge) that cannot inherit bash's
  # own $OSTYPE across the process boundary — synthesized live each dispatch and
  # delivered through the dispatch file. The native bash path is derived
  # inside theurge via cygpath, keeping cygpath out of kit bash.
  BURD_OSTYPE="${OSTYPE}"
  zbud_show "Platform: ${BURD_OSTYPE}"

  return 0
}

# Process command-line arguments
zbud_process_args() {
  local -r z_target="${1}"
  test "$#" -eq 0 || shift

  zbud_show "Processing target: ${z_target}"

  local -a z_tokens
  IFS="${BURC_TABTARGET_DELIMITER}" read -ra z_tokens <<< "${z_target}" || zbud_die "Failed to split the target: ${z_target}"
  zbud_show "Split tokens: ${z_tokens[*]}"

  # The command token the coordinator is handed is dispatch's own; the third
  # token is the zipper's imprint folio and crosses into the coordinator.
  z_bud_command="${z_tokens[0]}"
  BURD_TOKEN_3="${z_tokens[2]:-}"

  local -r z_tag="${z_tokens[0]}-${z_tokens[2]:-unknown}"

  # Setup log paths and files (skip entirely for no-log tabtargets)
  if test -z "${BURD_NO_LOG}"; then
    # The members are written absolute, against the repo root z-launcher left
    # this process standing in, as the tackroom is: a station names its log
    # directory relative, and the dispatch file records where the record
    # actually stands. The station value itself is left as it reads.
    local z_log_dir="${BURS_LOG_DIR}"
    case "${z_log_dir}" in
      /*) ;;
      *)  z_log_dir="${PWD}/${z_log_dir}" ;;
    esac
    BURD_LOG_LAST="${z_log_dir}/${BURC_LOG_LAST}.${BURC_LOG_EXT}"
    BURD_LOG_SAME="${z_log_dir}/same-${z_tag}.${BURC_LOG_EXT}"
    BURD_LOG_HIST="${z_log_dir}/hist-${z_tag}-${BURD_NOW_STAMP}.${BURC_LOG_EXT}"
    mkdir -p "${z_log_dir}" || zbud_die "Failed to create the ${BUBG_STATION_LOG_POSSESSIVE} directory: ${z_log_dir}"
    # Under the own-log mode the names are the dispatch's and the writing is the
    # coordinator's, so the three enter the dispatch file under this mode alone,
    # which is how the coordinator reads them, and no file is created: an absent
    # member after this dispatch says the coordinator wrote none, where an empty
    # file this dispatch had touched would lie.
    if test -z "${z_bud_amanuensis}"; then
      : > "${BURD_LOG_LAST}" || zbud_die "Failed to truncate: ${BURD_LOG_LAST}"
      : > "${BURD_LOG_SAME}" || zbud_die "Failed to truncate: ${BURD_LOG_SAME}"
      : > "${BURD_LOG_HIST}" || zbud_die "Failed to truncate: ${BURD_LOG_HIST}"
    fi
  fi

  BURD_TARGET="${z_target}"
  z_bud_cli_args=("$@")

  return 0
}

# Function to curate logs for the 'same' log file (normalized output)
zbud_curate_same() {
  # Convert to unix line endings, strip colors, normalize temp dir, remove VOLATILE lines
  local z_line
  while IFS= read -r z_line || test -n "${z_line}"; do
    test -n "${z_line}" || continue
    z_line="${z_line//$'\x1b'\[*([0123456789;])[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]/}"
    z_line="${z_line//$'\x1b'\([ABCDEFGHIJKLMNOPQRSTUVWXYZ]/}"
    z_line="${z_line//"${BURD_TEMP_DIR}"/BURD_EPHEMERAL_DIR}"
    case "${z_line}" in
      *VOLATILE*) continue ;;
    esac
    local -a z_frames
    IFS=$'\r' read -ra z_frames <<< "${z_line}" || zbud_die "Failed to read"
    local z_frame
    if test "${#z_frames[@]}" -gt 0; then
      for z_frame in "${z_frames[@]}"; do
        printf '%s\n' "${z_frame}" || zbud_die "Failed to write a curated line of the same member of the ${BUBG_STATION_LOG_BASE}"
      done
    else
      printf '\n' || zbud_die "Failed to write a curated line of the same member of the ${BUBG_STATION_LOG_BASE}"
    fi
  done
}

# Function to curate the historical log file (with timestamps). Reads the
# coordinator's raw stream on stdin; the caller opens fd 3 onto BURD_LOG_HIST,
# so each line's stamped form is appended there directly while the line itself
# passes through untouched on stdout — one filter does both jobs.
zbud_curate_hist() {
  # The trailing `|| test -n` guard matches zbud_curate_same's: a coordinator
  # whose final line carries no newline still gets stamped. A stream fed by tee
  # delivers that line, and without this guard hist alone would drop what the
  # same and last logs keep.
  #
  # The stamp itself is taken by a forked date on every line. That fork is the
  # single largest cost left in the curation of a chatty door, and the floor this
  # kit builds to is bash 3.2, whose printf converts no time, so no faster arm
  # stands beside it: the guide bars a bash-4 construct whatever version test
  # guards it.
  #
  # `IFS=` matches zbud_curate_same's read for a reason this log carries alone.
  # Under the default IFS a read strips the leading and trailing whitespace off
  # every line it takes, so a stamped line's content began at its first
  # non-blank byte — and a table carved out of this log then differed, byte for
  # byte, from the same table carved out of a capture that kept its indentation.
  # Sessions compare saved tables across two positions of the record, and this
  # log is the only re-read channel a tabtarget leaves them, so the timestamp
  # prefix stands and the bytes after it are the coordinator's own.
  # A date that fails stamps a marker rather than ending the relay: the lines
  # this filter carries are the record, and the stamp is only their prefix.
  local z_line
  local z_stamp=""
  local z_stamp_status=0
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_stamp_status=0
    z_stamp=$(date +"%Y-%m-%d %H:%M:%S") || z_stamp_status=$?
    test "${z_stamp_status}" -eq 0 || z_stamp="date-unavailable"
    printf "[%s] %s\n" "${z_stamp}" "${z_line}" >&3 || zbud_die "Failed to write a stamped line to the historical member of the ${BUBG_STATION_LOG_BASE}"
    printf '%s\n' "${z_line}" || zbud_die "Failed to pass a line through the hist filter"
  done
}

# Generate and log checksum for a file
zbud_generate_checksum() {
  local -r z_file="${1}"
  local -r z_output_file="${2}"

  local z_checksum=""
  local z_checksum_status=0
  local -r z_checksum_stderr="${BURD_TEMP_DIR}/bud_checksum_stderr.txt"
  z_checksum=$(openssl dgst -sha256 -r "${z_file}" 2>"${z_checksum_stderr}") || z_checksum_status=$?
  test "${z_checksum_status}" -eq 0 || z_checksum="checksum-unavailable(see:${z_checksum_stderr})"
  read -r z_checksum _ <<< "${z_checksum}" || zbud_die "Failed to read"

  echo "Same log checksum: ${z_checksum}" >> "${z_output_file}" || zbud_die "Failed to write"
  return 0
}

# Resolve color policy once at dispatch time and record the verdict as
# BURD_COLOR (0/1) in the dispatch file — a dispatch-computed value, never an
# operator-set BURE_ input (BUr_q2m). BURE_COLOR stays readable here as the
# optional operator override it always was, but dispatch never writes it: a
# verdict left under the BURE_ prefix crosses a spawn boundary as if it were
# operator ambient (BURE_ passes by design), so the child reads a stale pin as
# an explicit override and never re-derives its own.
zbud_resolve_color() {
  case "${BURE_COLOR:-auto}" in
    auto|0|1) ;;
    *) zbud_die "BURE_COLOR must be auto, 0 or 1, got: ${BURE_COLOR}" ;;
  esac
  if test -n "${NO_COLOR:-}"; then
    BURD_COLOR=0
    return 0
  fi
  case "${BURE_COLOR:-auto}" in
    0|1)
      BURD_COLOR="${BURE_COLOR}"
      ;;
    auto)
      if test -t 1 && test "${TERM:-}" != "dumb"; then
          BURD_COLOR=1
      else
          BURD_COLOR=0
      fi
      ;;
  esac
}

# Resolve the hyperlink switch once at dispatch time and record the verdict as
# BURD_HYPERLINKS (0/1) in the dispatch file — dispatch-computed like
# BURD_COLOR, never an operator input (BUr_q2m). BURE_HYPERLINKS is the
# operator's optional say and is never written; the yelp palette alone decides,
# from this verdict and the color mode, whether a link renders as an OSC 8
# escape.
zbud_resolve_hyperlinks() {
  case "${BURE_HYPERLINKS:-1}" in
    0|1) BURD_HYPERLINKS="${BURE_HYPERLINKS:-1}" ;;
    *) zbud_die "BURE_HYPERLINKS must be 0 or 1, got: ${BURE_HYPERLINKS}" ;;
  esac
}

# Read the terminal's width once at dispatch time, ahead of the pipe the
# coordinator's output takes. /dev/tty is probed in a subshell, since it may
# stand without opening (CI, a sandbox), its complaint kept in the temp dir;
# stty prints "rows cols", and a failed read keeps the default, its status read
# where the read is taken.
zbud_resolve_term_cols() {
  local -r z_tty_stderr="${BURD_TEMP_DIR}/bud_tty_probe_stderr.txt"
  BURD_TERM_COLS=80
  if (exec </dev/tty) 2>"${z_tty_stderr}"; then
    local z_tty_size=""
    local z_tty_status=0
    z_tty_size=$(stty size </dev/tty) || z_tty_status=$?
    test "${z_tty_status}" -ne 0 || BURD_TERM_COLS="${z_tty_size#* }"
    test -n "${BURD_TERM_COLS}" || BURD_TERM_COLS=80
  fi
}

# Write a fixed-width timestamp (YYYYMMDD-HHMMSS.NNNNNNNNN) to the file at $1.
# Sub-second precision is not load-bearing — the nanosecond field is always
# zero — but the fixed width is preserved for stable downstream BURX parsing.
zbud_nanosecond_timestamp() {
  local -r z_output_file="${1}"
  date +'%Y%m%d-%H%M%S.000000000' > "${z_output_file}" || zbud_die "date failed"
}

# Append one line to z_bud_burx_text, written as bash's sourcing reads it back:
# a bare token where the value is one, double quotes around one carrying
# anything else, and a refusal naming the field where it carries a character
# neither form holds. The one line writer of both files this dispatch composes,
# the dispatch file and the exchange file, each composed whole and written once.
zbud_burx_append() {
  local -r z_name="${1:-}"
  local -r z_value="${2:-}"
  local -r z_newline=$'\n'
  case "${z_value}" in
    *'"'*|*"'"*|*'\'*|*'$'*|*'`'*|*"${z_newline}"*)
      zbud_die "${z_name} carries a quote, a backslash, a dollar, a backtick or a newline, which no exchange line can carry: ${z_value}"
      ;;
  esac
  case "${z_value}" in
    *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./:,@%+=-]*)
      z_bud_burx_text="${z_bud_burx_text}${z_name}=\"${z_value}\"${z_newline}"
      ;;
    *)
      z_bud_burx_text="${z_bud_burx_text}${z_name}=${z_value}${z_newline}"
      ;;
  esac
}

zbud_write_burx_initial() {
  local -r z_ts_file="${BURD_TEMP_DIR}/zbud_began_at.txt"
  zbud_nanosecond_timestamp "${z_ts_file}"
  local z_began_at
  z_began_at=$(<"${z_ts_file}") || zbud_die "Failed to read: ${z_ts_file}"
  test -n "${z_began_at}" || zbud_die "Empty began_at timestamp"

  local -r z_newline=$'\n'
  z_bud_burx_text=""
  zbud_burx_append BURX_PID        "${$}"
  zbud_burx_append BURX_BEGAN_AT   "${z_began_at}"
  buf_write_fact_single "${BUF_burx_env}" "${z_bud_burx_text%"${z_newline}"}"
}

zbud_write_burx_completion() {
  local -r z_exit_status="${1}"
  local -r z_ts_file="${BURD_TEMP_DIR}/zbud_ended_at.txt"
  zbud_nanosecond_timestamp "${z_ts_file}"
  local z_ended_at
  z_ended_at=$(<"${z_ts_file}") || zbud_die "Failed to read: ${z_ts_file}"
  test -n "${z_ended_at}" || zbud_die "Empty ended_at timestamp"

  z_bud_burx_text=""
  zbud_burx_append BURX_EXIT_STATUS "${z_exit_status}"
  zbud_burx_append BURX_ENDED_AT    "${z_ended_at}"
  printf '%s' "${z_bud_burx_text}" >> "${BURD_OUTPUT_DIR}/${BUF_burx_env}" \
    || zbud_die "Failed to write the completion state: ${BURD_OUTPUT_DIR}/${BUF_burx_env}"
  printf '%s' "${z_bud_burx_text}" >> "${BURD_TEMP_DIR}/${BUF_burx_env}" \
    || zbud_die "Failed to write the completion state: ${BURD_TEMP_DIR}/${BUF_burx_env}"
}

zbud_main() {
  zbud_show "Starting BDU dispatch"

  # The launcher hands the coordinator, the tabtarget's configuration, the seat
  # and the moorings directory ahead of the tabtarget basename, by argument and
  # never by export. The configuration is the launcher stub's basename and its
  # buuc_ words, which the launcher has already checked; the own-log word is
  # this dispatch's to hold.
  test "$#" -ge 5 || zbud_die "The dispatch takes the coordinator, the configuration, the seat, the ${BUBG_MOORINGS_BASE} directory and the ${BUBG_TABTARGET_BASE}, in that order (bul_launcher.sh hands them)"
  z_bud_coordinator_script="${1:-}"
  local -r z_configuration="${2:-}"
  BURD_SEAT="${3:-}"
  BURD_CONFIG_DIR="${4:-}"
  test "$#" -lt 4 || shift 4
  case "${BURD_CONFIG_DIR}" in
    /*) ;;
    *)  zbud_die "The ${BUBG_MOORINGS_BASE} directory bul_launcher.sh hands must be absolute, got: '${BURD_CONFIG_DIR}'" ;;
  esac
  BURD_MOORINGS_DIR="${BURD_CONFIG_DIR##*/}"
  BURD_REGIME_FILE="${BURD_CONFIG_DIR}/burc.env"
  local z_words=()
  read -r -a z_words <<< "${z_configuration}" || zbud_die "Failed to split the configuration: ${z_configuration}"
  BURD_LAUNCHER="${z_words[0]:-}"
  BURD_NO_LOG=""
  BURD_INTERACTIVE=""
  local z_w=0
  for z_w in "${!z_words[@]}"; do
    test "${z_w}" -gt 0 || continue
    case "${z_words[${z_w}]}" in
      "${BUBC_word_nolog}")       BURD_NO_LOG=1 ;;
      "${BUBC_word_interactive}") BURD_INTERACTIVE=1 ;;
      "${BUBC_word_ownlog}")      z_bud_amanuensis=1 ;;
      *) zbud_die "Unknown configuration word '${z_words[${z_w}]}' in: ${z_configuration}" ;;
    esac
  done

  # Decide color policy before stdout is piped
  zbud_resolve_color
  zbud_resolve_hyperlinks

  zbud_setup
  zbud_show "Environment setup complete"

  # Read the terminal, still ahead of the pipe, into the temp dir setup made
  zbud_resolve_term_cols

  source "${BURC_TOOLS_DIR}/buk/buf_fact.sh" || zbud_die "Failed to source the fact module: ${BURC_TOOLS_DIR}/buk/buf_fact.sh"

  zbud_process_args "$@"
  zbud_show "Arguments processed"

  # THE DISPATCH FILE, written once into the temp dir and copied into the
  # output dir before the coordinator starts. It carries every BURD_ value this
  # process holds, the pointer naming it among them, and is the one channel a
  # process below reads them through. The log names are the exception: the
  # historical log enters the file wherever a log exists, the last and same logs
  # under the own-log mode alone, that pair standing being how a reader knows
  # the mode. A name inherited from a parent door that no enrollment holds is
  # written as it stands, and the coordinator's dispatch kindle refuses it.
  BURD_BURD_FILE="${BURD_TEMP_DIR}/${BUF_burd_env}"
  # The run's correlation label stands in the dispatch file on every run, empty
  # where none was handed, so a reader matching a run by it needs no presence
  # check; the exchange file carries the run's lifecycle alone.
  BURD_LABEL="${BURE_LABEL:-}"
  # compgen answers 1 where no variable wears the prefix, which leaves the
  # listing empty and nothing to write; any other status is a failure. Variable
  # names carry no whitespace, so one line split by read holds them all.
  local z_burd_listing=""
  local z_burd_listing_status=0
  z_burd_listing=$(compgen -v BURD_) || z_burd_listing_status=$?
  test "${z_burd_listing_status}" -le 1 || zbud_die "Failed to list the BURD_ variables"
  local -r z_newline=$'\n'
  local -r z_burd_line="${z_burd_listing//"${z_newline}"/ }"
  local z_burd_names=()
  read -r -a z_burd_names <<< "${z_burd_line}" || zbud_die "Failed to split the BURD_ listing"
  local -r z_name_lead="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
  local z_burd_name=""
  local z_i
  z_bud_burx_text=""
  for z_i in "${!z_burd_names[@]}"; do
    z_burd_name="${z_burd_names[${z_i}]}"
    [[ "${z_burd_name}" =~ ^[${z_name_lead}][${z_name_lead}0123456789]*$ ]] \
      || zbud_die "Invalid variable name in the BURD_ listing: '${z_burd_name}'"
    case "${z_burd_name}" in
      BURD_LOG_HIST)
        test -z "${BURD_NO_LOG}" || continue
        zbud_burx_append "${z_burd_name}" "${!z_burd_name}"
        continue
        ;;
      BURD_LOG_LAST|BURD_LOG_SAME)
        test -n "${z_bud_amanuensis}" || continue
        zbud_burx_append "${z_burd_name}" "${!z_burd_name}"
        continue
        ;;
    esac
    zbud_burx_append "${z_burd_name}" "${!z_burd_name}"
  done
  buf_write_fact_single "${BUF_burd_env}" "${z_bud_burx_text%"${z_newline}"}"

  # THE OVERRIDE FAMILY STOPS AT THIS DOOR. A harness composed it for this one
  # child, the launcher and this dispatch have folded it into the roots the file
  # records, and its export is withdrawn so no override travels below the door
  # it was composed for.
  local z_burv_listing=""
  local z_burv_listing_status=0
  z_burv_listing=$(compgen -e BURV_) || z_burv_listing_status=$?
  test "${z_burv_listing_status}" -le 1 || zbud_die "Failed to list the exported BURV_ variables"
  local -r z_burv_line="${z_burv_listing//"${z_newline}"/ }"
  local z_burv_names=()
  read -r -a z_burv_names <<< "${z_burv_line}" || zbud_die "Failed to split the exported BURV_ listing"
  if test "${#z_burv_names[@]}" -gt 0; then
    for z_i in "${!z_burv_names[@]}"; do
      export -n "${z_burv_names[${z_i}]}" || zbud_die "Failed to withdraw the export of ${z_burv_names[${z_i}]}"
    done
  fi

  # THE TWO HAND-OFFS, and the only names this dispatch exports: the pointer, so
  # the coordinator finds the file, and the kit directory, so it finds the kit's
  # reader of it.
  export BURD_BURD_FILE BURD_BUK_DIR

  zbud_write_burx_initial

  # Build complete invocation array (always has ≥2 elements, so always safe under set -u)
  local -a z_invocation=("${z_bud_coordinator_script}" "${z_bud_command}")
  if test "${#z_bud_cli_args[@]}" -gt 0; then
    z_invocation+=("${z_bud_cli_args[@]}")
  fi
  zbud_show "Coordinator command: ${z_invocation[*]}"

  # Log command to all log files (or suppress all output if BURD_NO_LOG)
  if test -z "${BURD_NO_LOG}"; then
    if test -n "${z_bud_amanuensis}"; then
      # The invocation and git-context lines belong to whoever writes the
      # record, and under this mode that is the coordinator (BUr_fbc). The
      # dispatch announces the paths it composed and writes nothing into them.
      echo "log files:   ${BURD_LOG_LAST} ${BURD_LOG_SAME} ${BURD_LOG_HIST}" || zbud_die "Failed to write"
    elif test -n "${BURD_INTERACTIVE}"; then
      echo "log (interactive): ${BURD_LOG_HIST}" || zbud_die "Failed to write"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_HIST}" || zbud_die "Failed to write"
      echo "Git context: ${BURD_GIT_CONTEXT}"  >> "${BURD_LOG_HIST}" || zbud_die "Failed to write"
    else
      echo "log files:   ${BURD_LOG_LAST} ${BURD_LOG_SAME} ${BURD_LOG_HIST}" || zbud_die "Failed to write"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_LAST}" || zbud_die "Failed to write"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_SAME}" || zbud_die "Failed to write"
      echo "command: ${z_invocation[*]}" >> "${BURD_LOG_HIST}" || zbud_die "Failed to write"
      echo "Git context: ${BURD_GIT_CONTEXT}"  >> "${BURD_LOG_HIST}" || zbud_die "Failed to write"
    fi
    echo "transcript:  ${BURD_TRANSCRIPT}" || zbud_die "Failed to write"
    echo "output dir:  ${BURD_OUTPUT_DIR}" || zbud_die "Failed to write"
    echo "${BUBG_LOOSEBOX_BASE}:    ${BURD_LOOSEBOX_DIR}" || zbud_die "Failed to write"
  fi

  zbud_show "Executing coordinator"

  # Execute coordinator with logging. The coordinator's status is captured where
  # it returns, and every relay pipeline's stage statuses on its own guard, so
  # errexit stays on throughout.
  z_bud_status_file="${BURD_TEMP_DIR}/status-${$}"
  # The coordinator's status is held as it returns and shown from the hold; the
  # status file carries it out of the group, which the logging arm pipes.
  local z_bud_coordinator_status=0
  # Every element status of a relay pipeline, read whole the moment it returns:
  # the coordinator's own status is relayed as the exit, and any filter's
  # failure dies naming the filter.
  local z_bud_relay_status=()
  z_bud_relay_status=(0 0 0)
  if test -n "${z_bud_amanuensis}" || test -n "${BURD_NO_LOG}"; then
    # The two modes in which this dispatch tees nothing, for opposite reasons:
    # no-log because there is no record, amanuensis because the record is the
    # coordinator's to write. Both leave the child's streams untouched, so the
    # arm is one. It stands first so the interactive test below need not
    # exclude no-log by hand.
    {
      "${z_invocation[@]}" || z_bud_coordinator_status=$?
      echo "${z_bud_coordinator_status}" > "${z_bud_status_file}" \
        || zbud_die "Failed to write the coordinator status: ${z_bud_status_file}"
      zbud_show "Coordinator status: ${z_bud_coordinator_status}"
    }
  elif test -n "${BURD_INTERACTIVE}"; then
    # Interactive mode with logging: uncurated tee to historical log, preserves line buffering
    {
      "${z_invocation[@]}" 2>&1 || z_bud_coordinator_status=$?
      echo "${z_bud_coordinator_status}" > "${z_bud_status_file}" \
        || zbud_die "Failed to write the coordinator status: ${z_bud_status_file}"
      zbud_show "Coordinator status (interactive): ${z_bud_coordinator_status}"
    } | tee -a "${BURD_LOG_HIST}" || z_bud_relay_status=("${PIPESTATUS[@]}")
    test "${z_bud_relay_status[1]}" -eq 0 \
      || zbud_die "The tee to the historical member failed with status ${z_bud_relay_status[1]}: ${BURD_LOG_HIST}"
    test "${z_bud_relay_status[0]}" -eq 0 \
      || zbud_die "The coordinator's group failed with status ${z_bud_relay_status[0]} recording its status: ${z_bud_status_file}"
  else
    # Non-interactive with logging. tee replicates the raw stream to the last
    # log and to a private per-invocation capture under BURD_TEMP_DIR, then
    # hands the remainder to the one long-lived hist filter — it stamps each
    # line onto fd 3 (opened here onto BURD_LOG_HIST) and passes the line
    # through untouched on its own stdout, so the terminal stays live on the
    # fd it always has. Each filter pays for a chatty door's output once.
    # The same log is derived from the private capture once the pipeline
    # returns — sequentially, nothing to wait on — and never from the shared
    # last log, which every tabtarget writing into BURS_LOG_DIR shares.
    local -r z_raw_capture="${BURD_TEMP_DIR}/raw-capture-${$}"

    {
      "${z_invocation[@]}" 2>&1 || z_bud_coordinator_status=$?
      echo "${z_bud_coordinator_status}" > "${z_bud_status_file}" \
        || zbud_die "Failed to write the coordinator status: ${z_bud_status_file}"
      zbud_show "Coordinator status: ${z_bud_coordinator_status}"
    } | tee -a "${BURD_LOG_LAST}" "${z_raw_capture}" | zbud_curate_hist 3>>"${BURD_LOG_HIST}" \
      || z_bud_relay_status=("${PIPESTATUS[@]}")
    # Judged downstream first: a stage that dies breaks the pipe of every stage
    # feeding it, so the furthest failure is the cause and the rest its echoes.
    test "${z_bud_relay_status[2]}" -eq 0 \
      || zbud_die "The hist filter failed with status ${z_bud_relay_status[2]}: ${BURD_LOG_HIST}"
    test "${z_bud_relay_status[1]}" -eq 0 \
      || zbud_die "The tee to the last member and the raw capture failed with status ${z_bud_relay_status[1]}: ${BURD_LOG_LAST} ${z_raw_capture}"
    test "${z_bud_relay_status[0]}" -eq 0 \
      || zbud_die "The coordinator's group failed with status ${z_bud_relay_status[0]} recording its status: ${z_bud_status_file}"

    zbud_curate_same < "${z_raw_capture}" >> "${BURD_LOG_SAME}" \
      || zbud_die "Failed to curate the same member from ${z_raw_capture}"
  fi

  z_bud_exit_status=$(<"${z_bud_status_file}") || zbud_die "Failed to read the coordinator status: ${z_bud_status_file}"
  test -n "${z_bud_exit_status}" || zbud_die "Empty coordinator status in ${z_bud_status_file}"

  zbud_write_burx_completion "${z_bud_exit_status}"

  # Generate checksum for the log files (only when this dispatch wrote them).
  # Under the amanuensis mode the digest is the coordinator's, taken after the
  # last byte of the same log is written, because only the writer knows when
  # that is (BUr_yht).
  if test -z "${BURD_NO_LOG}" && test -z "${z_bud_amanuensis}"; then
    zbud_generate_checksum "${BURD_LOG_SAME}" "${BURD_LOG_HIST}"
    zbud_show "Checksum generated"
  fi

  zbud_show "BDU completed with status: ${z_bud_exit_status}"

  exit "${z_bud_exit_status}"
}

# Direct execution only — sourcing (e.g. a test harness calling
# zbud_resolve_color in isolation) defines the functions without re-running
# a whole dispatch.
if test "${BASH_SOURCE[0]}" = "${0}"; then
  zbud_main "$@"
fi

# eof
