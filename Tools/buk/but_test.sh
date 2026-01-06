#!/bin/bash
#
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
# Bash Test Utility Library

# Multiple inclusion guard
test -z "${ZBUT_INCLUDED:-}" || return 0
ZBUT_INCLUDED=1

# Color codes
but_color() { test -n "$TERM" && test "$TERM" != "dumb" && printf '\033[%sm' "$1" || printf ''; }
ZBUT_WHITE=$(  but_color '1;37' )
ZBUT_RED=$(    but_color '1;31' )
ZBUT_GREEN=$(  but_color '1;32' )
ZBUT_RESET=$(  but_color '0'    )

# Generic renderer for aligned multi-line messages
# Usage: zbut_render_lines PREFIX [COLOR] [STACK_DEPTH] LINES...
zbut_render_lines() {
  local label="$1"; shift
  local color="$1"; shift

  local prefix="$label:"

  local visible_prefix="$prefix"
  test -z "$color" || prefix="${color}${prefix}${ZBUT_RESET}"
  local indent="$(printf '%*s' "$(echo -e "$visible_prefix" | sed 's/\x1b\[[0-9;]*m//g' | wc -c)" '')"

  local first=1
  for line in "$@"; do
    if test $first -eq 1; then
      echo "$prefix $line" >&2
      first=0
    else
      echo "$indent $line" >&2
    fi
  done
}

but_section() {
  test "${BUT_VERBOSE:-0}" -ge 1 || return 0
  zbut_render_lines "info " "${ZBUT_WHITE}" "$@"
}

but_info() {
  test "${BUT_VERBOSE:-0}" -ge 1 || return 0
  zbut_render_lines "info " "" "$@"
}

but_trace() {
  test "${BUT_VERBOSE:-0}" -ge 2 || return 0
  zbut_render_lines "trace" "" "$@"
}

but_fatal() {
  zbut_render_lines "ERROR" "${ZBUT_RED}" "$@"
  exit 1
}

but_fatal_on_error() {
  set -e
  local condition="$1"; shift
  test "${condition}" -eq 0 && return 0
  but_fatal "$@"
}

but_fatal_on_success() {
  set -e
  local condition="$1"; shift
  test "${condition}" -ne 0 && return 0
  but_fatal "$@"
}

# Safely invoke a command under 'set -e', capturing stdout, stderr, and exit status
# Globals set:
#   ZBUT_STDOUT  � command stdout
#   ZBUT_STDERR  � command stderr
#   ZBUT_STATUS  � command exit code
zbut_invoke() {
  but_trace "Invoking: $*"

  local tmp_stdout="$(mktemp)"
  local tmp_stderr="$(mktemp)"

  ZBUT_STATUS=$( (
      set +e
      "$@" >"${tmp_stdout}" 2>"${tmp_stderr}"
      printf '%s' "$?"
      exit 0
    ) || printf '__subshell_failed__' )

  if [[ "${ZBUT_STATUS}" == "__subshell_failed__" || -z "${ZBUT_STATUS}" ]]; then
    ZBUT_STATUS=127
    ZBUT_STDOUT=""
    ZBUT_STDERR="zbut_invoke: command caused shell to exit before status could be captured"
  else
    ZBUT_STDOUT=$(<"${tmp_stdout}")
    ZBUT_STDERR=$(<"${tmp_stderr}")
  fi

  rm -f "${tmp_stdout}" "${tmp_stderr}"
}

but_expect_ok_stdout() {
  set -e

  local expected="$1"; shift

  zbut_invoke "$@"

  but_fatal_on_error "${ZBUT_STATUS}" "Command failed with status ${ZBUT_STATUS}" \
                                      "Command: $*"                               \
                                      "STDERR: ${ZBUT_STDERR}"

  test "${ZBUT_STDOUT}" = "${expected}" || but_fatal "Output mismatch"            \
                                                     "Command: $*"                \
                                                     "Expected: '${expected}'"    \
                                                     "Got:      '${ZBUT_STDOUT}'"
}

but_expect_ok() {
  set -e

  zbut_invoke "$@"

  but_fatal_on_error "${ZBUT_STATUS}" "Command failed with status ${ZBUT_STATUS}" \
                                      "Command: $*"                               \
                                      "STDERR: ${ZBUT_STDERR}"
}

but_expect_fatal() {
  set -e

  zbut_invoke "$@"

  but_fatal_on_success "${ZBUT_STATUS}" "Expected failure but got success" \
                                        "Command: $*"                      \
                                        "STDOUT: ${ZBUT_STDOUT}"           \
                                        "STDERR: ${ZBUT_STDERR}"
}

# Run single test case in subshell
zbut_case() {
  set -e

  local case_name="$1"
  declare -F "${case_name}" >/dev/null || but_fatal "Test function not found: ${case_name}"

  but_section "START: ${case_name}"

  # Create per-test temp directory
  local case_temp_dir="${ZBUT_ROOT_TEMP_DIR}/${case_name}"
  mkdir -p "${case_temp_dir}" || but_fatal "Failed to create test temp dir: ${case_temp_dir}"

  local status
  (
    set -e
    export BUT_TEMP_DIR="${case_temp_dir}"
    "${case_name}"
  )

  status=$?
  but_trace "Ran: ${case_name} and got status:${status}"
  but_fatal_on_error "${status}" "Test failed: ${case_name}"

  but_trace "Finished: ${case_name} with status: ${status}"
  test "${BUT_VERBOSE:-0}" -le 0 || echo "${ZBUT_GREEN}PASSED:${ZBUT_RESET} ${case_name}" >&2
}

# Run all or specific tests
but_execute() {
  set -e

  # Validate temp directory parameter
  local root_temp_dir="$1"
  test -n "${root_temp_dir}"            || but_fatal "Usage: script.sh <root_temp_dir> [test_case]"
  test -d "${root_temp_dir}"            || but_fatal "Root temp dir does not exist: ${root_temp_dir}"
  test -w "${root_temp_dir}"            || but_fatal "Root temp dir is not writable: ${root_temp_dir}"
  test -z "$(ls -A "${root_temp_dir}")" || but_fatal "Root temp dir is not empty: ${root_temp_dir}"

  export ZBUT_ROOT_TEMP_DIR="${root_temp_dir}"
  export BUT_VERBOSE="${BUT_VERBOSE:-0}"

  # Enable bash trace to stderr if BUT_VERBOSE is 3 or higher and bash >= 4.1
  if [[ "${BUT_VERBOSE}" -ge 3 ]]; then
    if [[ "${BASH_VERSINFO[0]}" -gt 4 ]] || [[ "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -ge 1 ]]; then
      export PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
      export BASH_XTRACEFD=2
      set -x
    fi
  fi

  local prefix="$2"
  local the_case="$3"
  local count=0

  if [[ -n    "${the_case}" ]]; then
    echo      "${the_case}" | grep -q "^${prefix}" || \
         echo "${the_case} mismatch to '${prefix}' but trying..."
    zbut_case "${the_case}"
    count=1
  else
    local found=0
    for one_case in $(declare -F | grep "^declare -f ${prefix}" | cut -d' ' -f3); do
      found=1
      zbut_case "${one_case}"
      count=$((count + 1))
    done
    but_fatal_on_success "${found}" "No test functions found with prefix '${prefix}'"
  fi

  echo "${ZBUT_GREEN}All tests passed (${count} case$(test ${count} -eq 1 || echo 's'))${ZBUT_RESET}" >&2
}

# eof
