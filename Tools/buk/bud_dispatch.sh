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
# Bash Dispatch Utility - Direct bash dispatch

set -euo pipefail

BUD_VERBOSE=${BUD_VERBOSE:-0}

BUD_REGIME_FILE=${BUD_REGIME_FILE:-"__MISSING_REGIME_FILE__"}

# Utility function for verbose output
zbud_show() { test "$BUD_VERBOSE" != "1" || echo "BDUSHOW: $*"; }

# Enable trace mode if verbose level is 2
if [[ "$BUD_VERBOSE" == "2" ]]; then
  set -x
fi

zbud_die() { echo "FATAL: $*" >&2; exit 1; }

# String validator with optional length constraints
zbud_check_string() {
  local context=$1
  local varname=$2
  eval "local val=\${$varname:-}" || zbud_die "Variable '$varname' is not defined in '$context'"
  local min=$3
  local max=$4

  test "$min" = "0" -a -z "$val" && return 0
  test -n "$val" || zbud_die "[$context] $varname must not be empty"

  if [ -n "$max" ]; then
    test ${#val} -ge $min || zbud_die "[$context] $varname must be at least $min chars, got '${val}' (${#val})"
    test ${#val} -le $max || zbud_die "[$context] $varname must be no more than $max chars, got '${val}' (${#val})"
  fi
}

# Source configuration and setup environment
zbud_setup() {
  zbud_show "Starting BDU setup"

  source            "${BUD_REGIME_FILE}"
  zbud_check_string "${BUD_REGIME_FILE}" BURC_STATION_FILE        1 256
  zbud_check_string "${BUD_REGIME_FILE}" BURC_LOG_LAST            1 256
  zbud_check_string "${BUD_REGIME_FILE}" BURC_LOG_EXT             1 32
  zbud_check_string "${BUD_REGIME_FILE}" BURC_TABTARGET_DIR       1 256
  zbud_check_string "${BUD_REGIME_FILE}" BURC_TABTARGET_DELIMITER 1 8
  zbud_check_string "${BUD_REGIME_FILE}" BURC_TEMP_ROOT_DIR       1 256
  zbud_check_string "${BUD_REGIME_FILE}" BURC_OUTPUT_ROOT_DIR     1 256
  zbud_check_string "${BUD_REGIME_FILE}" BURC_TOOLS_DIR           1 256

  # Source station file
  zbud_show "Sourcing station file: ${BURC_STATION_FILE}"
  source                           "${BURC_STATION_FILE}"

  # Validate station variables
  zbud_check_string "${BURC_STATION_FILE}" BURS_LOG_DIR 1 256

  BUD_NOW_STAMP=$(date +'%Y%m%d-%H%M%S')-$$-$((RANDOM % 1000))
  zbud_show "Generated timestamp: ${BUD_NOW_STAMP}"

  BUD_TEMP_DIR="${BURC_TEMP_ROOT_DIR}/temp-${BUD_NOW_STAMP}"
  mkdir -p                           "${BUD_TEMP_DIR}"
  zbud_show "Generated temporary dir: ${BUD_TEMP_DIR}"

  # Validate temporary directory
  if [[ ! -d "${BUD_TEMP_DIR}" ]]; then
    echo "ERROR: Failed to create temporary directory: ${BUD_TEMP_DIR}" >&2
    return 1
  fi

  if [[ -n "$(find "${BUD_TEMP_DIR}" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "ERROR: Temporary directory is not empty: ${BUD_TEMP_DIR}" >&2
    return 1
  fi

  # Setup transcript file path
  BUD_TRANSCRIPT="${BUD_TEMP_DIR}/transcript.txt"

  # Setup output directory (fixed location, cleared on each run)
  BUD_OUTPUT_DIR="${BURC_OUTPUT_ROOT_DIR}/current"

  # Clear if exists, then create fresh
  if [[ -d "$BUD_OUTPUT_DIR" ]]; then
    zbud_show "Clearing existing output directory: $BUD_OUTPUT_DIR"
    rm -rf "$BUD_OUTPUT_DIR"
  fi
  mkdir -p "$BUD_OUTPUT_DIR"

  # Validate output directory
  if [[ ! -d "$BUD_OUTPUT_DIR" ]]; then
    echo "ERROR: Failed to create output directory: $BUD_OUTPUT_DIR" >&2
    return 1
  fi

  if [[ -n "$(find "$BUD_OUTPUT_DIR" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "ERROR: Output directory is not empty: $BUD_OUTPUT_DIR" >&2
    return 1
  fi

  zbud_show "Output directory ready: $BUD_OUTPUT_DIR"

  # Get Git context
  BUD_GIT_CONTEXT=$(git describe --always --dirty --tags --long 2>/dev/null || echo "git-unavailable")
  zbud_show "Git context: $BUD_GIT_CONTEXT"

  # Export for child processes
  export BUD_TEMP_DIR
  export BUD_OUTPUT_DIR
  export BUD_NOW_STAMP
  export BUD_TRANSCRIPT
  export BUD_GIT_CONTEXT

  return 0
}

# Process command-line arguments
zbud_process_args() {
  local target=$1
  shift

  zbud_show "Processing target: $target"

  # Extract tokens from tabtarget
  IFS="${BURC_TABTARGET_DELIMITER}" read -ra tokens <<< "$target"
  zbud_show "Split tokens: ${tokens[*]}"

  # Store primary command token (legacy, equivalent to BUD_TOKEN_1)
  BUD_COMMAND="${tokens[0]}"

  # Explode tokens into numbered variables for workbench access
  # Pattern matches MBC_TTPARAM__FIRST through MBC_TTPARAM__FIFTH
  BUD_TOKEN_1="${tokens[0]:-}"
  BUD_TOKEN_2="${tokens[1]:-}"
  BUD_TOKEN_3="${tokens[2]:-}"
  BUD_TOKEN_4="${tokens[3]:-}"
  BUD_TOKEN_5="${tokens[4]:-}"

  export BUD_TOKEN_1 BUD_TOKEN_2 BUD_TOKEN_3 BUD_TOKEN_4 BUD_TOKEN_5

  # Create tag for log files
  local tag="${tokens[0]}-${tokens[2]:-unknown}"

  # Setup log paths
  BUD_LOG_LAST="${BURS_LOG_DIR}/${BURC_LOG_LAST}.${BURC_LOG_EXT}"
  BUD_LOG_SAME="${BURS_LOG_DIR}/same-${tag}.${BURC_LOG_EXT}"
  BUD_LOG_HIST="${BURS_LOG_DIR}/hist-${tag}-$BUD_NOW_STAMP.${BURC_LOG_EXT}"

  # Prepare/initialize log files unless logging disabled
  if [[ -z "${BUD_NO_LOG:-}" ]]; then
    # Prepare log directories
    mkdir -p "${BURS_LOG_DIR}"
    # Initialize log files
    > "$BUD_LOG_LAST"
    > "$BUD_LOG_SAME"
    > "$BUD_LOG_HIST"
  fi

  # Store target and extra arguments
  BUD_TARGET="$target"
  BUD_CLI_ARGS=("$@")

  # Export command context for workbench access
  export BUD_COMMAND
  export BUD_TARGET
  export BUD_CLI_ARGS

  return 0
}

# Function to curate logs for the 'same' log file (normalized output)
zbud_curate_same() {
  # Convert to unix line endings, strip colors, normalize temp dir, remove VOLATILE lines
  sed -e 's/\r/\n/g'                             \
      -e '/^$/d'                                 \
      -e 's/\x1b[\[][0-9;]*[a-zA-Z]//g'          \
      -e 's/\x1b[(][A-Z]//g'                     \
      -e "s|${BUD_TEMP_DIR}|BUD_EPHEMERAL_DIR|g" \
      -e '/VOLATILE/d'
}

# Function to curate logs for the historical log file (with timestamps)
zbud_curate_hist() {
  while read -r line; do
    printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$line"
  done
}

# Generate and log checksum for a file
zbud_generate_checksum() {
  local file=$1
  local output_file=$2

  # Try multiple checksum commands (platform-dependent)
  local checksum=$(sha256sum            "$file" 2>/dev/null ||
                   openssl dgst -sha256 "$file" 2>/dev/null ||
                   echo "checksum-unavailable")

  echo "Same log checksum: $checksum" >> "$output_file"
  return 0
}

# Resolve color policy once at dispatch time and export BUD_COLOR (0/1)
zbud_resolve_color() {
  if [ -n "${NO_COLOR:-}" ]; then
    export BUD_COLOR=0
    return 0
  fi
  case "${BUD_COLOR:-auto}" in
    0|1)
      export BUD_COLOR
      ;;
    auto|*)
      if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -gt 0 ]; then
          export BUD_COLOR=1
      else
          export BUD_COLOR=0
      fi
      ;;
  esac
}

zbud_main() {
  zbud_show "Starting BDU dispatch"

  # Decide color policy before stdout is piped
  zbud_resolve_color

  # Setup environment
  zbud_setup || (echo "ERROR: Environment setup failed" >&2 && exit 1)
  zbud_show "Environment setup complete"

  # Process arguments
  zbud_process_args "$@" || (echo "ERROR: Argument processing failed" >&2 && exit 1)
  zbud_show "Arguments processed"

  # Build complete invocation array (always has ≥2 elements, so always safe under set -u)
  local coordinator_cmd="${BUD_COORDINATOR_SCRIPT}"
  local -a zbud_invocation=("$coordinator_cmd" "$BUD_COMMAND")
  if [[ ${#BUD_CLI_ARGS[@]} -gt 0 ]]; then
    zbud_invocation+=("${BUD_CLI_ARGS[@]}")
  fi
  zbud_show "Coordinator command: ${zbud_invocation[*]}"

  # Log command to all log files (or disable)
  if [[ -n "${BUD_NO_LOG:-}" ]]; then
    echo "logs:        disabled"
  elif [[ -n "${BUD_INTERACTIVE:-}" ]]; then
    echo "log (interactive): $BUD_LOG_HIST"
    echo "command: ${zbud_invocation[*]}" >> "$BUD_LOG_HIST"
    echo "Git context: $BUD_GIT_CONTEXT"  >> "$BUD_LOG_HIST"
  else
    echo "log files:   $BUD_LOG_LAST $BUD_LOG_SAME $BUD_LOG_HIST"
    echo "command: ${zbud_invocation[*]}" >> "$BUD_LOG_LAST"
    echo "command: ${zbud_invocation[*]}" >> "$BUD_LOG_SAME"
    echo "command: ${zbud_invocation[*]}" >> "$BUD_LOG_HIST"
    echo "Git context: $BUD_GIT_CONTEXT"  >> "$BUD_LOG_HIST"
  fi
  echo "transcript:  ${BUD_TRANSCRIPT}"
  echo "output dir:  ${BUD_OUTPUT_DIR}"

  zbud_show "Executing coordinator"

  # Execute coordinator with logging
  set +e
  zBUD_STATUS_FILE="${BUD_TEMP_DIR}/status-$$"
  if [[ -n "${BUD_INTERACTIVE:-}" ]]; then
    # Interactive mode: uncurated logging to historical log, preserves line buffering
    "${zbud_invocation[@]}" 2>&1 | tee -a "$BUD_LOG_HIST"
    zBUD_EXIT_STATUS=${PIPESTATUS[0]}
    echo $zBUD_EXIT_STATUS > "${zBUD_STATUS_FILE}"
    zbud_show "Coordinator status (interactive): $zBUD_EXIT_STATUS"
  elif [[ -n "${BUD_NO_LOG:-}" ]]; then
    {
      "${zbud_invocation[@]}"
      echo $? > "${zBUD_STATUS_FILE}"
      zbud_show "Coordinator status: $(cat ${zBUD_STATUS_FILE})"
    }
  else
    {
      "${zbud_invocation[@]}"
      echo $? > "${zBUD_STATUS_FILE}"
      zbud_show "Coordinator status: $(cat ${zBUD_STATUS_FILE})"
    } | while IFS= read -r line; do
        printf '%s\n' "$line" >> "$BUD_LOG_LAST"
        printf '%s\n' "$line" | zbud_curate_same >> "$BUD_LOG_SAME"
        printf '%s\n' "$line" | zbud_curate_hist >> "$BUD_LOG_HIST"
        printf '%s\n' "$line"  # to stdout
      done
  fi

  zBUD_EXIT_STATUS=$(cat "${zBUD_STATUS_FILE}")
  rm                     "${zBUD_STATUS_FILE}"
  set -e

  # Generate checksum for the log files (only when enabled)
  if [[ -z "${BUD_NO_LOG:-}" ]]; then
    zbud_generate_checksum "$BUD_LOG_SAME" "$BUD_LOG_HIST"
    zbud_show "Checksum generated"
  fi

  zbud_show "BDU completed with status: $zBUD_EXIT_STATUS"

  exit "$zBUD_EXIT_STATUS"
}

zbud_main "$@"

# eof

