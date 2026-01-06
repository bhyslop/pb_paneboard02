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
# JJU Utility - Job Jockey studbook operations
#
# This file is sourced by jju_cli.sh. All functions use buc_doc_*
# for introspection and end with buc_die until implemented.

set -euo pipefail

# Multiple inclusion detection
test -z "${ZJJU_SOURCED:-}" || buc_die "Module jju multiply sourced"
ZJJU_SOURCED=1

######################################################################
# Boilerplate Functions

zjju_kindle() {
  test -z "${ZJJU_KINDLED:-}" || buc_die "Module jju already kindled"

  # Validate BUD environment
  buv_dir_exists "${BUD_TEMP_DIR}"
  test -n "${BUD_NOW_STAMP:-}" || buc_die "BUD_NOW_STAMP is unset"

  # Internal constants
  ZJJU_STUDBOOK_FILE=".claude/jjm/jjs_studbook.json"
  ZJJU_PADDOCK_DIR=".claude/jjm"
  ZJJU_TROPHY_DIR=".claude/jjm/retired"

  # URL-safe base64 character set (64 chars)
  # Position 0-25: A-Z, 26-51: a-z, 52-61: 0-9, 62: -, 63: _
  ZJJU_FAVOR_CHARSET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  ZJJU_FAVOR_CHARSET_LEN=64

  ZJJU_KINDLED=1
}

zjju_sentinel() {
  test "${ZJJU_KINDLED:-}" = "1" || buc_die "Module jju not kindled"
}

######################################################################
# Favor Encoding/Decoding
#
# Favor format: HHPPP (5 URL-safe base64 digits)
# - HH = heat (2 digits, 0-4095)
# - PPP = pace (3 digits, 0-262143, 000 = heat-only reference)
# Character set: A-Za-z0-9-_ (64 chars, URL-safe, defined in ZJJU_FAVOR_CHARSET)

# Internal: Get character at position in charset
# Output: single character to stdout
zjju_favor_char_at() {
  zjju_sentinel
  local z_pos="${1}"
  echo "${ZJJU_FAVOR_CHARSET:${z_pos}:1}"
}

# Internal: Get position of character in charset
# Output: position (0-63) or -1 if not found
zjju_favor_pos_of() {
  zjju_sentinel
  local z_char="${1}"
  local z_pos=0

  while test "${z_pos}" -lt "${ZJJU_FAVOR_CHARSET_LEN}"; do
    if test "${ZJJU_FAVOR_CHARSET:${z_pos}:1}" = "${z_char}"; then
      echo "${z_pos}"
      return 0
    fi
    z_pos=$((z_pos + 1))
  done

  echo "-1"
}

# Internal: Encode heat+pace into 5-digit Favor
# Args: heat (0-4095), pace (0-262143)
# Output: 5-char Favor string (e.g., "KbAAB")
zjju_favor_encode() {
  zjju_sentinel
  local z_heat="${1:-}"
  local z_pace="${2:-}"

  # Validate parameters
  test -n "${z_heat}" || buc_die "Parameter 'heat' is required"
  test -n "${z_pace}" || buc_die "Parameter 'pace' is required"

  # Validate numeric
  test "${z_heat}" -eq "${z_heat}" 2>/dev/null || buc_die "Heat must be numeric: ${z_heat}"
  test "${z_pace}" -eq "${z_pace}" 2>/dev/null || buc_die "Pace must be numeric: ${z_pace}"

  # Validate ranges
  test "${z_heat}" -ge 0 || buc_die "Heat must be >= 0: ${z_heat}"
  test "${z_heat}" -le 4095 || buc_die "Heat must be <= 4095: ${z_heat}"
  test "${z_pace}" -ge 0 || buc_die "Pace must be >= 0: ${z_pace}"
  test "${z_pace}" -le 262143 || buc_die "Pace must be <= 262143: ${z_pace}"

  # Encode heat (2 base64 digits)
  local z_heat_d1
  local z_heat_d2
  z_heat_d1=$((z_heat / 64))
  z_heat_d2=$((z_heat % 64))

  # Encode pace (3 base64 digits)
  local z_pace_d1
  local z_pace_d2
  local z_pace_d3
  z_pace_d1=$((z_pace / 4096))        # pace / (64*64)
  z_pace_d2=$(((z_pace / 64) % 64))
  z_pace_d3=$((z_pace % 64))

  # Convert positions to characters (inline string slice from constant)
  local z_c1="${ZJJU_FAVOR_CHARSET:${z_heat_d1}:1}"
  local z_c2="${ZJJU_FAVOR_CHARSET:${z_heat_d2}:1}"
  local z_c3="${ZJJU_FAVOR_CHARSET:${z_pace_d1}:1}"
  local z_c4="${ZJJU_FAVOR_CHARSET:${z_pace_d2}:1}"
  local z_c5="${ZJJU_FAVOR_CHARSET:${z_pace_d3}:1}"

  echo "${z_c1}${z_c2}${z_c3}${z_c4}${z_c5}"
}

# Internal: Decode Favor into heat and pace numbers
# Args: favor (5-char string)
# Output: tab-delimited "heat\tpace"
zjju_favor_decode() {
  zjju_sentinel
  local z_favor="${1:-}"

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Validate length
  test "${#z_favor}" -eq 5 || buc_die "Favor must be exactly 5 characters: ${z_favor}"

  # Extract characters
  local z_c1="${z_favor:0:1}"
  local z_c2="${z_favor:1:1}"
  local z_c3="${z_favor:2:1}"
  local z_c4="${z_favor:3:1}"
  local z_c5="${z_favor:4:1}"

  # Convert characters to positions (temp file + read pattern)
  local z_pos_file="${BUD_TEMP_DIR}/favor_decode_pos.txt"
  local z_p1
  local z_p2
  local z_p3
  local z_p4
  local z_p5

  zjju_favor_pos_of "${z_c1}" > "${z_pos_file}"
  read -r z_p1 < "${z_pos_file}"

  zjju_favor_pos_of "${z_c2}" > "${z_pos_file}"
  read -r z_p2 < "${z_pos_file}"

  zjju_favor_pos_of "${z_c3}" > "${z_pos_file}"
  read -r z_p3 < "${z_pos_file}"

  zjju_favor_pos_of "${z_c4}" > "${z_pos_file}"
  read -r z_p4 < "${z_pos_file}"

  zjju_favor_pos_of "${z_c5}" > "${z_pos_file}"
  read -r z_p5 < "${z_pos_file}"

  # Validate all characters were found
  test "${z_p1}" -ge 0 || buc_die "Invalid character in favor: ${z_c1}"
  test "${z_p2}" -ge 0 || buc_die "Invalid character in favor: ${z_c2}"
  test "${z_p3}" -ge 0 || buc_die "Invalid character in favor: ${z_c3}"
  test "${z_p4}" -ge 0 || buc_die "Invalid character in favor: ${z_c4}"
  test "${z_p5}" -ge 0 || buc_die "Invalid character in favor: ${z_c5}"

  # Decode heat (2 digits)
  local z_heat
  z_heat=$((z_p1 * 64 + z_p2))

  # Decode pace (3 digits)
  local z_pace
  z_pace=$((z_p3 * 4096 + z_p4 * 64 + z_p5))

  # Output tab-delimited
  echo "${z_heat}	${z_pace}"
}

# Internal: Normalize favor to full 6-character format (₣HHPPP)
# Args: favor (₣HH or ₣HHPPP)
# Output: 6-char favor string (₣HHPPP)
zjju_favor_normalize() {
  zjju_sentinel
  local z_favor="${1:-}"

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Validate first character is ₣
  local z_first="${z_favor:0:1}"
  test "${z_first}" = "₣" || buc_die "Favor must start with ₣: ${z_favor}"

  # Check length
  local z_len="${#z_favor}"

  if test "${z_len}" -eq 3; then
    # 3-char input (₣HH) → append AAA for heat-only reference
    echo "${z_favor}AAA"
  elif test "${z_len}" -eq 6; then
    # 6-char input (₣HHPPP) → pass through unchanged
    echo "${z_favor}"
  else
    buc_die "Favor must be 3 or 6 characters: ${z_favor}"
  fi
}

######################################################################
# Studbook File Operations
#
# Single gate for all studbook reads/writes. Validation enforced on write.

# Internal: Validate studbook JSON structure
# Args: json-string
# Returns: 0 if valid, 1 if invalid (with buc_die)
zjju_studbook_validate() {
  zjju_sentinel
  local z_json="${1:-}"
  local z_file="${BUD_TEMP_DIR}/studbook_validate.json"

  buc_trace "Validating studbook JSON"
  test -n "${z_json}" || buc_die "Studbook JSON is empty"

  buc_trace "Writing JSON to temp file: ${z_file}"
  printf '%s' "${z_json}" > "${z_file}"

  # Step 1: Valid JSON object
  jq -e 'type == "object"' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Not a valid JSON object"

  # Step 2: Required top-level fields
  jq -e 'has("heats") and has("next_heat_seed")' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Missing required fields (heats, next_heat_seed)"

  # Step 3: Top-level field types
  jq -e '(.heats | type) == "object" and (.next_heat_seed | type) == "string"' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Type mismatch in top-level fields"

  # Step 4: Heat keys format (₣XX)
  jq -e '.heats | to_entries | all(.key | test("^₣[A-Za-z0-9_-]{2}$"))' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Invalid heat key format (expected ₣XX)"

  # Step 5: Heat required fields
  jq -e '.heats | to_entries | all(.value | has("datestamp") and has("display") and has("silks") and has("status") and has("paces"))' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Heat missing required fields (datestamp, display, silks, status, paces)"

  # Step 6: Heat field formats
  jq -e '.heats | to_entries | all(.value | (.datestamp | test("^[0-9]{6}$")) and (.silks | test("^[a-z0-9-]+$")) and (.status | . == "current" or . == "retired"))' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Invalid heat field format (datestamp=YYMMDD, silks=kebab-case, status=current|retired)"

  # Step 7: Pace validation
  jq -e '.heats | to_entries | all(.value.paces | all(has("id") and has("display") and has("status") and (.id | test("^[0-9]{3}$")) and (.status | . == "current" or . == "pending" or . == "complete" or . == "abandoned" or . == "malformed")))' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Invalid pace (id=XXX, status=current|pending|complete|abandoned|malformed)"

  # Step 8: next_heat_seed format (XX)
  jq -e '.next_heat_seed | test("^[A-Za-z0-9_-]{2}$")' "${z_file}" >/dev/null 2>&1 \
    || buc_die "Invalid next_heat_seed format (expected 2 base64 chars)"

  buc_trace "Studbook validation passed"
}

# Internal: Read studbook from disk
# Output: JSON content to stdout
zjju_studbook_read() {
  zjju_sentinel

  test -f "${ZJJU_STUDBOOK_FILE}" || buc_die "Studbook not found: ${ZJJU_STUDBOOK_FILE}"

  cat "${ZJJU_STUDBOOK_FILE}"
}

# Internal: Write studbook to disk (validates first)
# Args: json-string
zjju_studbook_write() {
  zjju_sentinel
  local z_json="${1:-}"

  # Validate before writing
  zjju_studbook_validate "${z_json}"

  # Normalize and write
  jq --sort-keys --indent 2 '.' <<< "${z_json}" > "${ZJJU_STUDBOOK_FILE}"
}

######################################################################
# Studbook Operations

# Internal: Increment heat seed (2 base64 chars)
# Args: current seed (e.g., "AA")
# Output: next seed (e.g., "AB")
zjju_heat_seed_next() {
  zjju_sentinel
  local z_seed="${1:-}"

  test -n "${z_seed}" || buc_die "Seed is required"
  test "${#z_seed}" -eq 2 || buc_die "Seed must be 2 characters: ${z_seed}"

  local z_c1="${z_seed:0:1}"
  local z_c2="${z_seed:1:1}"

  # Convert characters to positions (temp file + read pattern)
  local z_pos_file="${BUD_TEMP_DIR}/seed_next_pos.txt"
  local z_p1
  local z_p2

  zjju_favor_pos_of "${z_c1}" > "${z_pos_file}"
  read -r z_p1 < "${z_pos_file}"

  zjju_favor_pos_of "${z_c2}" > "${z_pos_file}"
  read -r z_p2 < "${z_pos_file}"

  test "${z_p1}" -ge 0 || buc_die "Invalid character in seed: ${z_c1}"
  test "${z_p2}" -ge 0 || buc_die "Invalid character in seed: ${z_c2}"

  # Increment (base64 arithmetic)
  z_p2=$((z_p2 + 1))
  if test "${z_p2}" -ge "${ZJJU_FAVOR_CHARSET_LEN}"; then
    z_p2=0
    z_p1=$((z_p1 + 1))
    test "${z_p1}" -lt "${ZJJU_FAVOR_CHARSET_LEN}" || buc_die "Heat seed overflow (max 4096 heats)"
  fi

  # Convert positions to characters (inline string slice from constant)
  local z_nc1="${ZJJU_FAVOR_CHARSET:${z_p1}:1}"
  local z_nc2="${ZJJU_FAVOR_CHARSET:${z_p2}:1}"

  echo "${z_nc1}${z_nc2}"
}

jju_muster() {
  zjju_sentinel
  buc_doc_brief "List current heats with Favors and silks"
  buc_doc_shown || return 0

  buc_trace "Listing heats from studbook"

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_muster.json"
  zjju_studbook_read > "${z_temp}"

  # Check if there are any heats (BCG: temp file for jq output)
  local z_count_file="${BUD_TEMP_DIR}/muster_count.txt"
  jq -r '.heats | length' "${z_temp}" > "${z_count_file}"
  local z_heat_count
  read -r z_heat_count < "${z_count_file}"

  if test "${z_heat_count}" -eq 0; then
    echo "No heats in studbook"
    buc_trace "Muster found no heats, temp file: ${z_temp}"
    return 0
  fi

  # List heats with their details
  echo "Current heats:"
  echo ""

  jq -r '.heats | to_entries | .[] |
    "\(.key)\t\(.value.display)\t\(.value.silks)\t\(.value.paces | length)"' \
    "${z_temp}" | while IFS=$'\t' read -r z_favor z_display z_silks z_pace_count; do

    # Format output
    printf "%s  %s  [%s]  (%s paces)\n" \
      "${z_favor}" "${z_display}" "${z_silks}" "${z_pace_count}"
  done

  buc_trace "Muster complete, temp file: ${z_temp}"
}

jju_saddle() {
  zjju_sentinel
  local z_favor="${1:-}"

  buc_doc_brief "Mount heat, show paddock + paces + recent steeple"
  buc_doc_param "favor" "Heat Favor (₣HHAAA for heat-only)"
  buc_doc_shown || return 0

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Normalize favor to 6-char format (BCG: temp file for output)
  local z_norm_file="${BUD_TEMP_DIR}/saddle_norm.txt"
  zjju_favor_normalize "${z_favor}" > "${z_norm_file}"
  read -r z_favor < "${z_norm_file}"

  # Extract heat favor (₣HH) from normalized favor
  local z_favor_digits="${z_favor:1}"
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  buc_trace "Saddling heat ${z_heat_favor}"

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_saddle.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Extract heat metadata (BCG: temp file for each jq scalar)
  local z_scalar_file="${BUD_TEMP_DIR}/saddle_scalar.txt"

  local z_datestamp
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].datestamp' "${z_temp}" > "${z_scalar_file}"
  read -r z_datestamp < "${z_scalar_file}"

  local z_display
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].display' "${z_temp}" > "${z_scalar_file}"
  read -r z_display < "${z_scalar_file}"

  local z_silks
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].silks' "${z_temp}" > "${z_scalar_file}"
  read -r z_silks < "${z_scalar_file}"

  # Get heat seed (without ₣)
  local z_seed="${z_heat_favor:1}"

  # Read paddock file
  local z_paddock_file="${ZJJU_PADDOCK_DIR}/jjp_${z_seed}.md"
  test -f "${z_paddock_file}" || buc_die "Paddock file not found: ${z_paddock_file}"

  # Output heat header
  echo "# Heat: ${z_display}"
  echo ""
  echo "**Favor**: ${z_heat_favor}"
  echo "**Silks**: ${z_silks}"
  echo "**Started**: ${z_datestamp}"
  echo ""
  echo "---"
  echo ""

  # Output paddock content
  cat "${z_paddock_file}"
  echo ""
  echo "---"
  echo ""

  # Find current pace (first pending)
  local z_current_pace_file="${BUD_TEMP_DIR}/saddle_current_pace.json"
  jq -r --arg heat "${z_heat_favor}" \
    '.heats[$heat].paces | map(select(.status == "pending")) | first // null' \
    "${z_temp}" > "${z_current_pace_file}"

  # Check if there is a current pace (BCG: temp file for jq scalar)
  local z_has_current
  jq -r 'if . == null then "false" else "true" end' "${z_current_pace_file}" > "${z_scalar_file}"
  read -r z_has_current < "${z_scalar_file}"

  if test "${z_has_current}" = "true"; then
    echo "## Current Pace"
    echo ""
    local z_current_id
    jq -r '.id' "${z_current_pace_file}" > "${z_scalar_file}"
    read -r z_current_id < "${z_scalar_file}"

    local z_current_display
    jq -r '.display' "${z_current_pace_file}" > "${z_scalar_file}"
    read -r z_current_display < "${z_scalar_file}"

    echo "**${z_heat_favor}${z_current_id}**: ${z_current_display}"
    echo ""
    echo "---"
    echo ""

    # Output remaining paces (pending only, excluding current)
    echo "## Remaining Paces"
    echo ""

    local z_remaining_file="${BUD_TEMP_DIR}/saddle_remaining.json"
    jq -r --arg heat "${z_heat_favor}" --arg current_id "${z_current_id}" \
      '.heats[$heat].paces | map(select(.status == "pending" and .id != $current_id))' \
      "${z_temp}" > "${z_remaining_file}"

    local z_remaining_count
    jq -r 'length' "${z_remaining_file}" > "${z_scalar_file}"
    read -r z_remaining_count < "${z_scalar_file}"

    if test "${z_remaining_count}" -gt 0; then
      jq -r '.[] | "- \(.id): \(.display)"' "${z_remaining_file}"
      echo ""
    else
      echo "(No other pending paces)"
      echo ""
    fi

    echo "---"
    echo ""

    # Get recent steeplechase entries for current pace
    echo "## Recent Steeplechase"
    echo ""

    local z_pace_favor="${z_heat_favor}${z_current_id}"
    buc_trace "Querying steeplechase for current pace: ${z_pace_favor}"

    # Capture jju_rein output
    local z_rein_file="${BUD_TEMP_DIR}/saddle_rein.txt"
    jju_rein "${z_pace_favor}" > "${z_rein_file}" 2>&1 || true

    # Show the output
    cat "${z_rein_file}"

  else
    # No pending paces
    echo "## Status"
    echo ""
    echo "All paces complete. Heat ready to retire."
    echo ""
  fi

  buc_trace "Saddle complete for ${z_heat_favor}, temp files: ${z_temp}, ${z_current_pace_file}"
}

jju_nominate() {
  zjju_sentinel
  local z_display="${1:-}"
  local z_silks="${2:-}"

  buc_doc_brief "Create new heat with paddock stub"
  buc_doc_param "display" "Human-readable heat name"
  buc_doc_param "silks" "Kebab-case identifier"
  buc_doc_shown || return 0

  # Validate parameters
  test -n "${z_display}" || buc_die "Parameter 'display' is required"
  test -n "${z_silks}" || buc_die "Parameter 'silks' is required"

  # Validate silks format (kebab-case)
  echo "${z_silks}" | grep -Eq '^[a-z0-9-]+$' || buc_die "Silks must be kebab-case: ${z_silks}"

  buc_trace "Nominating new heat"

  # Read studbook to temp file (BCG: temp file instead of command substitution)
  local z_studbook_file="${BUD_TEMP_DIR}/nominate_studbook.json"
  zjju_studbook_read > "${z_studbook_file}"

  # Get next heat seed (BCG: temp file + read pattern)
  local z_scalar_file="${BUD_TEMP_DIR}/nominate_scalar.txt"
  local z_seed
  jq -r '.next_heat_seed' "${z_studbook_file}" > "${z_scalar_file}"
  read -r z_seed < "${z_scalar_file}"
  test -n "${z_seed}" || buc_die "Failed to read next_heat_seed from studbook"

  # Format datestamp (YYMMDD)
  local z_datestamp="${BUD_NOW_STAMP:0:6}"

  # Create heat entry with Favor prefix
  local z_heat_key="₣${z_seed}"

  # Build new studbook JSON with new heat
  local z_temp_heat="${BUD_TEMP_DIR}/nominate_add_heat.json"
  jq --arg key "${z_heat_key}" \
     --arg datestamp "${z_datestamp}" \
     --arg display "${z_display}" \
     --arg silks "${z_silks}" \
     '.heats[$key] = {
        "datestamp": $datestamp,
        "display": $display,
        "silks": $silks,
        "status": "current",
        "paces": []
      }' "${z_studbook_file}" > "${z_temp_heat}"

  # Increment next_heat_seed
  local z_next_seed_file="${BUD_TEMP_DIR}/nominate_next_seed.txt"
  zjju_heat_seed_next "${z_seed}" > "${z_next_seed_file}"
  local z_next_seed
  read -r z_next_seed < "${z_next_seed_file}"

  local z_temp_final="${BUD_TEMP_DIR}/nominate_final.json"
  jq --arg seed "${z_next_seed}" \
     '.next_heat_seed = $seed' "${z_temp_heat}" > "${z_temp_final}"

  # Read the final JSON (BCG: $(<file) on same line as declaration)
  local z_new_studbook=$(<"${z_temp_final}")
  test -n "${z_new_studbook}" || buc_die "Failed to read: ${z_temp_final}"

  # Write studbook (validates internally)
  zjju_studbook_write "${z_new_studbook}"

  # Create paddock file stub (BCG: echo sequences instead of heredoc)
  local z_paddock_file="${ZJJU_PADDOCK_DIR}/jjp_${z_seed}.md"
  {
    echo "# ${z_display}"
    echo ""
    echo "## Goal"
    echo ""
    echo "[Describe the goal of this heat]"
    echo ""
    echo "## Approach"
    echo ""
    echo "[Describe the approach]"
    echo ""
    echo "## Constraints"
    echo ""
    echo "[List any constraints or guidelines]"
  } > "${z_paddock_file}"

  buc_trace "Nominated heat ${z_heat_key}, temp files: ${z_temp_heat}, ${z_temp_final}"
  echo "Heat ${z_heat_key} nominated: ${z_display}"
  echo "Silks: ${z_silks}"
  echo "Paddock: ${z_paddock_file}"
}

jju_slate() {
  zjju_sentinel
  local z_favor="${1:-}"
  local z_display="${2:-}"

  buc_doc_brief "Add new pace to heat (append-only)"
  buc_doc_param "favor" "Heat Favor (₣HHAAA for heat-only)"
  buc_doc_param "display" "Human-readable pace name"
  buc_doc_shown || return 0

  # Validate parameters
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"
  test -n "${z_display}" || buc_die "Parameter 'display' is required"

  # Normalize favor to 6-char format (BCG: temp file for output)
  local z_norm_file="${BUD_TEMP_DIR}/slate_norm.txt"
  zjju_favor_normalize "${z_favor}" > "${z_norm_file}"
  read -r z_favor < "${z_norm_file}"

  # Extract heat favor (₣HH) from normalized favor
  local z_favor_digits="${z_favor:1}"
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  buc_trace "Slating new pace in ${z_heat_favor}"

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_slate.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Get pace count to determine next ID and status (BCG: temp file for jq output)
  local z_scalar_file="${BUD_TEMP_DIR}/slate_scalar.txt"
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].paces | length' "${z_temp}" > "${z_scalar_file}"
  local z_pace_count
  read -r z_pace_count < "${z_scalar_file}"

  # Calculate next pace ID
  local z_next_id
  if test "${z_pace_count}" -eq 0; then
    z_next_id="001"
  else
    # Get max ID and increment (BCG: temp file for jq output)
    jq -r --arg heat "${z_heat_favor}" \
      '.heats[$heat].paces | map(.id | tonumber) | max' "${z_temp}" > "${z_scalar_file}"
    local z_max_id
    read -r z_max_id < "${z_scalar_file}"
    local z_next_num=$((z_max_id + 1))

    # Format as 3-digit string
    if test "${z_next_num}" -lt 10; then
      z_next_id="00${z_next_num}"
    elif test "${z_next_num}" -lt 100; then
      z_next_id="0${z_next_num}"
    else
      z_next_id="${z_next_num}"
    fi
  fi

  # Determine status (current if first pace, pending otherwise)
  local z_status
  if test "${z_pace_count}" -eq 0; then
    z_status="current"
  else
    z_status="pending"
  fi

  # Add pace to heat
  local z_temp_final="${BUD_TEMP_DIR}/slate_final.json"
  jq --arg heat "${z_heat_favor}" \
     --arg id "${z_next_id}" \
     --arg display "${z_display}" \
     --arg status "${z_status}" \
     '.heats[$heat].paces += [{
        "id": $id,
        "display": $display,
        "status": $status
      }]' "${z_temp}" > "${z_temp_final}"

  # Read the new studbook (BCG: $(<file) on same line as declaration)
  local z_new_studbook=$(<"${z_temp_final}")
  test -n "${z_new_studbook}" || buc_die "Failed to read: ${z_temp_final}"

  # Write studbook (validates internally)
  zjju_studbook_write "${z_new_studbook}"

  buc_trace "Slated pace ${z_next_id}, temp files: ${z_temp}, ${z_temp_final}"
  echo "Pace ${z_heat_favor}${z_next_id} slated: ${z_display}"
}

jju_reslate() {
  zjju_sentinel
  local z_favor="${1:-}"
  local z_display="${2:-}"

  buc_doc_brief "Revise pace description"
  buc_doc_param "favor" "Pace Favor (₣HHPPP)"
  buc_doc_param "display" "New description"
  buc_doc_shown || return 0

  # Validate parameters
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"
  test -n "${z_display}" || buc_die "Parameter 'display' is required"

  buc_trace "Reslating pace ${z_favor}"

  # Parse favor (₣HHPPP format)
  test "${z_favor:0:1}" = "₣" || buc_die "Favor must start with ₣: ${z_favor}"
  test "${#z_favor}" -eq 6 || buc_die "Favor must be 6 characters (₣HHPPP): ${z_favor}"

  # Decode favor to get numeric heat and pace values
  local z_favor_digits="${z_favor:1}"  # Remove ₣ prefix
  local z_decode_file="${BUD_TEMP_DIR}/reslate_decode.txt"
  zjju_favor_decode "${z_favor_digits}" > "${z_decode_file}"

  local z_heat_num
  local z_pace_num
  IFS=$'\t' read -r z_heat_num z_pace_num < "${z_decode_file}"

  # Reconstruct heat favor (₣HH)
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  # Format pace ID as 3-digit string
  local z_pace_id
  if test "${z_pace_num}" -lt 10; then
    z_pace_id="00${z_pace_num}"
  elif test "${z_pace_num}" -lt 100; then
    z_pace_id="0${z_pace_num}"
  else
    z_pace_id="${z_pace_num}"
  fi

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_reslate.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Verify pace exists
  jq -e --arg heat "${z_heat_favor}" --arg id "${z_pace_id}" \
    '.heats[$heat].paces | any(.id == $id)' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Pace not found: ${z_favor}"

  # Update pace display
  local z_temp_final="${BUD_TEMP_DIR}/reslate_final.json"
  jq --arg heat "${z_heat_favor}" \
     --arg id "${z_pace_id}" \
     --arg display "${z_display}" \
     '.heats[$heat].paces |= map(
        if .id == $id then .display = $display else . end
      )' "${z_temp}" > "${z_temp_final}"

  # Read the new studbook (BCG: $(<file) on same line as declaration)
  local z_new_studbook=$(<"${z_temp_final}")
  test -n "${z_new_studbook}" || buc_die "Failed to read: ${z_temp_final}"

  # Write studbook (validates internally)
  zjju_studbook_write "${z_new_studbook}"

  buc_trace "Reslated pace ${z_favor}, temp files: ${z_temp}, ${z_temp_final}"
  echo "Pace ${z_favor} reslated: ${z_display}"
}

jju_rail() {
  zjju_sentinel
  local z_favor="${1:-}"
  local z_order="${2:-}"

  buc_doc_brief "Reorder paces in heat"
  buc_doc_param "favor" "Heat Favor (₣HHAAA for heat-only)"
  buc_doc_param "order" "Space-separated pace IDs in new order (e.g., '001 003 002')"
  buc_doc_shown || return 0

  # Validate parameters
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"
  test -n "${z_order}" || buc_die "Parameter 'order' is required"

  # Normalize favor to 6-char format (BCG: temp file for output)
  local z_norm_file="${BUD_TEMP_DIR}/rail_norm.txt"
  zjju_favor_normalize "${z_favor}" > "${z_norm_file}"
  read -r z_favor < "${z_norm_file}"

  # Extract heat favor (₣HH) from normalized favor
  local z_favor_digits="${z_favor:1}"
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_rail.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Get current pace count (BCG: temp file for jq output)
  local z_scalar_file="${BUD_TEMP_DIR}/rail_scalar.txt"
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].paces | length' "${z_temp}" > "${z_scalar_file}"
  local z_pace_count
  read -r z_pace_count < "${z_scalar_file}"

  # Count IDs in order list
  local z_order_count=0
  for z_id in ${z_order}; do
    z_order_count=$((z_order_count + 1))
  done

  # Verify count matches
  test "${z_order_count}" -eq "${z_pace_count}" \
    || buc_die "Order list has ${z_order_count} IDs but heat has ${z_pace_count} paces"

  # Build JSON array of IDs for jq, checking for duplicates
  local z_order_json="["
  local z_first=1
  local z_seen_ids=""
  for z_id in ${z_order}; do
    buc_trace "Processing pace ID: ${z_id}"

    # Validate ID format (3 digits)
    echo "${z_id}" | grep -Eq '^[0-9]{3}$' \
      || buc_die "Invalid pace ID format: ${z_id} (must be 3 digits)"

    # Check for duplicates
    echo "${z_seen_ids}" | grep -q " ${z_id} " \
      && buc_die "Duplicate pace ID in order list: ${z_id}"
    z_seen_ids="${z_seen_ids} ${z_id} "

    # Verify pace exists
    jq -e --arg heat "${z_heat_favor}" --arg id "${z_id}" \
      '.heats[$heat].paces | any(.id == $id)' "${z_temp}" >/dev/null 2>&1 \
      || buc_die "Pace not found: ${z_id}"

    if test "${z_first}" -eq 1; then
      z_order_json="${z_order_json}\"${z_id}\""
      z_first=0
    else
      z_order_json="${z_order_json},\"${z_id}\""
    fi
  done
  z_order_json="${z_order_json}]"

  # Reorder paces using jq
  local z_temp_final="${BUD_TEMP_DIR}/rail_final.json"
  jq --arg heat "${z_heat_favor}" \
     --argjson order "${z_order_json}" \
     '.heats[$heat].paces = [
        $order[] as $id |
        (.heats[$heat].paces[] | select(.id == $id))
      ]' "${z_temp}" > "${z_temp_final}"

  # Read the new studbook (BCG: $(<file) on same line as declaration)
  local z_new_studbook=$(<"${z_temp_final}")
  test -n "${z_new_studbook}" || buc_die "Failed to read: ${z_temp_final}"

  # Write studbook (validates internally)
  zjju_studbook_write "${z_new_studbook}"

  buc_trace "Railed paces ${z_order}, temp files: ${z_temp}, ${z_temp_final}"
  echo "Paces railed: ${z_order}"
}

jju_tally() {
  zjju_sentinel
  local z_favor="${1:-}"
  local z_state="${2:-}"

  buc_doc_brief "Set pace state"
  buc_doc_param "favor" "Pace Favor (₣HHPPP)"
  buc_doc_param "state" "New state: current|pending|complete|abandoned|malformed"
  buc_doc_shown || return 0

  # Validate parameters
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"
  test -n "${z_state}" || buc_die "Parameter 'state' is required"

  # Validate state value
  case "${z_state}" in
    current|pending|complete|abandoned|malformed)
      ;;
    *)
      buc_die "Invalid state: ${z_state} (must be current|pending|complete|abandoned|malformed)"
      ;;
  esac

  # Parse favor (₣HHPPP format)
  test "${z_favor:0:1}" = "₣" || buc_die "Favor must start with ₣: ${z_favor}"
  test "${#z_favor}" -eq 6 || buc_die "Favor must be 6 characters (₣HHPPP): ${z_favor}"

  # Decode favor to get numeric heat and pace values
  local z_favor_digits="${z_favor:1}"  # Remove ₣ prefix
  local z_decode_file="${BUD_TEMP_DIR}/tally_decode.txt"
  zjju_favor_decode "${z_favor_digits}" > "${z_decode_file}"

  local z_heat_num
  local z_pace_num
  IFS=$'\t' read -r z_heat_num z_pace_num < "${z_decode_file}"

  # Reconstruct heat favor (₣HH)
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  # Format pace ID as 3-digit string
  local z_pace_id
  if test "${z_pace_num}" -lt 10; then
    z_pace_id="00${z_pace_num}"
  elif test "${z_pace_num}" -lt 100; then
    z_pace_id="0${z_pace_num}"
  else
    z_pace_id="${z_pace_num}"
  fi

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_tally.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Verify pace exists
  jq -e --arg heat "${z_heat_favor}" --arg id "${z_pace_id}" \
    '.heats[$heat].paces | any(.id == $id)' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Pace not found: ${z_favor}"

  # Update pace status
  local z_temp_final="${BUD_TEMP_DIR}/tally_final.json"
  jq --arg heat "${z_heat_favor}" \
     --arg id "${z_pace_id}" \
     --arg state "${z_state}" \
     '.heats[$heat].paces |= map(
        if .id == $id then .status = $state else . end
      )' "${z_temp}" > "${z_temp_final}"

  # Read the new studbook (BCG: $(<file) on same line as declaration)
  local z_new_studbook=$(<"${z_temp_final}")
  test -n "${z_new_studbook}" || buc_die "Failed to read: ${z_temp_final}"

  # Write studbook (validates internally)
  zjju_studbook_write "${z_new_studbook}"

  buc_trace "Tallied pace ${z_favor} to ${z_state}, temp files: ${z_temp}, ${z_temp_final}"
  echo "Pace ${z_favor} tallied: ${z_state}"
}

jju_retire_extract() {
  zjju_sentinel
  local z_favor="${1:-}"

  buc_doc_brief "Extract heat data for trophy creation"
  buc_doc_param "favor" "Heat Favor (₣HHAAA for heat-only)"
  buc_doc_shown || return 0

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Normalize favor to 6-char format (BCG: temp file for output)
  local z_norm_file="${BUD_TEMP_DIR}/retire_norm.txt"
  zjju_favor_normalize "${z_favor}" > "${z_norm_file}"
  read -r z_favor < "${z_norm_file}"

  # Extract heat favor (₣HH) from normalized favor
  local z_favor_digits="${z_favor:1}"
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  # Read studbook to temp file
  local z_temp="${BUD_TEMP_DIR}/studbook_retire.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  buc_trace "Extracting heat data for trophy"

  # Extract heat metadata (BCG: temp file + read pattern for each scalar)
  local z_scalar_file="${BUD_TEMP_DIR}/retire_scalar.txt"

  local z_datestamp
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].datestamp' "${z_temp}" > "${z_scalar_file}"
  read -r z_datestamp < "${z_scalar_file}"
  test -n "${z_datestamp}" || buc_die "Failed to read datestamp"

  local z_display
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].display' "${z_temp}" > "${z_scalar_file}"
  read -r z_display < "${z_scalar_file}"
  test -n "${z_display}" || buc_die "Failed to read display"

  local z_silks
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].silks' "${z_temp}" > "${z_scalar_file}"
  read -r z_silks < "${z_scalar_file}"
  test -n "${z_silks}" || buc_die "Failed to read silks"

  # Count paces by status (BCG: temp file + read pattern)
  local z_total
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].paces | length' "${z_temp}" > "${z_scalar_file}"
  read -r z_total < "${z_scalar_file}"

  local z_complete
  jq -r --arg heat "${z_heat_favor}" \
    '.heats[$heat].paces | map(select(.status == "complete")) | length' "${z_temp}" > "${z_scalar_file}"
  read -r z_complete < "${z_scalar_file}"

  local z_pending
  jq -r --arg heat "${z_heat_favor}" \
    '.heats[$heat].paces | map(select(.status == "pending")) | length' "${z_temp}" > "${z_scalar_file}"
  read -r z_pending < "${z_scalar_file}"

  local z_abandoned
  jq -r --arg heat "${z_heat_favor}" \
    '.heats[$heat].paces | map(select(.status == "abandoned")) | length' "${z_temp}" > "${z_scalar_file}"
  read -r z_abandoned < "${z_scalar_file}"

  # Get heat seed (without ₣)
  local z_seed="${z_heat_favor:1}"

  # Read paddock file
  local z_paddock_file="${ZJJU_PADDOCK_DIR}/jjp_${z_seed}.md"
  test -f "${z_paddock_file}" || buc_die "Paddock file not found: ${z_paddock_file}"

  # Output trophy markdown
  echo "# Trophy: ${z_display}"
  echo ""
  echo "**Favor**: ${z_heat_favor}"
  echo "**Silks**: ${z_silks}"
  echo "**Started**: ${z_datestamp}"
  echo "**Paces**: ${z_total} total (${z_complete} complete, ${z_pending} pending, ${z_abandoned} abandoned)"
  echo ""
  echo "---"
  echo ""
  echo "## Paddock"
  echo ""
  cat "${z_paddock_file}"
  echo ""
  echo "---"
  echo ""
  echo "## Paces"
  echo ""

  # Output paces table
  jq -r --arg heat "${z_heat_favor}" \
    '.heats[$heat].paces | .[] |
     "| \(.id) | \(.display) | \(.status) |"' "${z_temp}" | {
    echo "| ID | Description | Status |"
    echo "|---:|:------------|:-------|"
    cat
  }

  echo ""
  echo "---"
  echo ""

  buc_trace "Retire extract for ${z_heat_favor}, temp file: ${z_temp}"

  echo "## Steeplechase"
  echo ""

  # Query git log for steeplechase entries (BCG: temp file, extended-regexp)
  local z_steeple_file="${BUD_TEMP_DIR}/retire_steeple.txt"
  local z_steeple_pattern="^[[]${z_heat_favor}"

  git log --all --extended-regexp --grep="${z_steeple_pattern}" --format="%ai%x09%s" --reverse > "${z_steeple_file}" \
    || buc_die "Git log failed for steeplechase extraction"

  if test -s "${z_steeple_file}"; then
    local z_entry_date=""
    local z_entry_subject=""
    while IFS=$'\t' read -r z_entry_date z_entry_subject; do
      # Format: YYYY-MM-DD HH:MM - subject
      local z_short_datetime="${z_entry_date:0:16}"
      echo "- ${z_short_datetime} ${z_entry_subject}"
    done < "${z_steeple_file}"
  else
    echo "(No steeplechase entries found)"
  fi

  echo ""
}

jju_retire() {
  zjju_sentinel
  local z_favor="${1:-}"

  buc_doc_brief "Retire heat: create trophy, remove from studbook, archive paddock"
  buc_doc_param "favor" "Heat Favor (₣HHAAA for heat-only)"
  buc_doc_shown || return 0

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Normalize favor to 6-char format (BCG: temp file for output)
  local z_norm_file="${BUD_TEMP_DIR}/retire_norm.txt"
  zjju_favor_normalize "${z_favor}" > "${z_norm_file}"
  read -r z_favor < "${z_norm_file}"

  # Extract heat favor (₣HH) from normalized favor
  local z_favor_digits="${z_favor:1}"
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"
  local z_seed="${z_heat_digits}"

  buc_step "Retiring heat ${z_heat_favor}"

  # Validate clean worktree (policy: retire requires clean)
  local z_status_file="${BUD_TEMP_DIR}/retire_status.txt"
  git status --porcelain > "${z_status_file}" 2>&1 \
    || buc_die "Git status failed"

  if test -s "${z_status_file}"; then
    buc_die "Worktree must be clean before retiring heat (commit or stash changes first)"
  fi

  # Read studbook to verify heat exists and get metadata
  local z_temp="${BUD_TEMP_DIR}/studbook_retire_main.json"
  zjju_studbook_read > "${z_temp}"

  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Extract dates for trophy filename (BCG: temp file + read pattern)
  local z_scalar_file="${BUD_TEMP_DIR}/retire_main_scalar.txt"

  local z_datestamp
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].datestamp' "${z_temp}" > "${z_scalar_file}"
  read -r z_datestamp < "${z_scalar_file}"
  test -n "${z_datestamp}" || buc_die "Failed to read datestamp"

  local z_silks
  jq -r --arg heat "${z_heat_favor}" '.heats[$heat].silks' "${z_temp}" > "${z_scalar_file}"
  read -r z_silks < "${z_scalar_file}"
  test -n "${z_silks}" || buc_die "Failed to read silks"

  # Generate trophy filename: jjy_HH_YYMMDD-YYMMDD_silks.md
  local z_start_date="${z_datestamp}"
  local z_end_date="${BUD_NOW_STAMP:0:6}"
  local z_trophy_filename="jjy_${z_seed}_${z_start_date}-${z_end_date}_${z_silks}.md"
  local z_trophy_path="${ZJJU_TROPHY_DIR}/${z_trophy_filename}"

  buc_step "Creating trophy: ${z_trophy_filename}"

  # Ensure retired directory exists
  mkdir -p "${ZJJU_TROPHY_DIR}" || buc_die "Failed to create retired directory"

  # Generate trophy content using jju_retire_extract
  local z_trophy_content="${BUD_TEMP_DIR}/retire_trophy.md"
  jju_retire_extract "${z_favor}" > "${z_trophy_content}" \
    || buc_die "Failed to extract trophy content"

  # Write trophy file
  cp "${z_trophy_content}" "${z_trophy_path}" \
    || buc_die "Failed to write trophy file"

  buc_step "Removing heat from studbook"

  # Remove heat from studbook (BCG: jq transform to temp, then write)
  local z_new_studbook="${BUD_TEMP_DIR}/studbook_retire_new.json"
  jq --arg heat "${z_heat_favor}" 'del(.heats[$heat])' "${z_temp}" > "${z_new_studbook}" \
    || buc_die "Failed to remove heat from studbook"

  # Validate and write new studbook
  local z_new_content
  z_new_content=$(<"${z_new_studbook}")
  zjju_studbook_write "${z_new_content}"

  buc_step "Archiving paddock"

  # Move paddock to retired directory
  local z_paddock_file="${ZJJU_PADDOCK_DIR}/jjp_${z_seed}.md"
  local z_paddock_archive="${ZJJU_TROPHY_DIR}/jjp_${z_seed}_${z_start_date}-${z_end_date}.md"

  if test -f "${z_paddock_file}"; then
    mv "${z_paddock_file}" "${z_paddock_archive}" \
      || buc_die "Failed to archive paddock"
  else
    buc_warn "Paddock file not found: ${z_paddock_file}"
  fi

  buc_step "Committing retirement"

  # Stage and commit (BCG: sequential operations)
  git add "${z_trophy_path}" "${ZJJU_STUDBOOK_FILE}" \
    || buc_die "Failed to stage trophy and studbook"

  if test -f "${z_paddock_archive}"; then
    git add "${z_paddock_archive}" || buc_die "Failed to stage archived paddock"
    git rm --cached "${z_paddock_file}" 2>/dev/null || true
  fi

  git commit -m "[₣${z_seed}AAA] RETIRE: Heat ${z_silks} archived to trophy" \
    || buc_die "Failed to commit retirement"

  buc_step "Pushing retirement"

  git push || buc_die "Failed to push retirement commit"

  buc_success "Heat ${z_heat_favor} retired: ${z_trophy_filename}"
}

######################################################################
# Steeplechase Operations (Git)

jju_chalk() {
  zjju_sentinel
  local z_favor="${1:-}"
  local z_emblem="${2:-}"
  local z_title="${3:-}"

  buc_doc_brief "Write steeplechase entry as empty git commit"
  buc_doc_param "favor" "Pace Favor (₣HHPPP)"
  buc_doc_param "emblem" "Entry type (APPROACH, WRAP, BLOCKED, NOTE, etc.)"
  buc_doc_param "title" "Entry title"
  buc_doc_shown || return 0

  # Validate parameters
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"
  test -n "${z_emblem}" || buc_die "Parameter 'emblem' is required"
  test -n "${z_title}" || buc_die "Parameter 'title' is required"

  # Validate favor format (₣HHPPP)
  test "${z_favor:0:1}" = "₣" || buc_die "Favor must start with ₣: ${z_favor}"
  test "${#z_favor}" -eq 6 || buc_die "Favor must be 6 characters (₣HHPPP): ${z_favor}"

  # Get git status to determine files touched
  local z_status_file="${BUD_TEMP_DIR}/chalk_status.txt"
  git status --short > "${z_status_file}" || buc_die "Git status failed"

  # Build commit message
  local z_commit_msg_file="${BUD_TEMP_DIR}/chalk_commit.txt"
  {
    echo "[${z_favor}] ${z_emblem}: ${z_title}"
    echo ""

    # Add files touched footer if there are any changes
    if test -s "${z_status_file}"; then
      echo "Files touched:"
      cat "${z_status_file}"
    fi
  } > "${z_commit_msg_file}"

  # Create empty commit
  git commit --allow-empty -F "${z_commit_msg_file}" \
    || buc_die "Git commit failed"

  buc_trace "Chalked steeplechase entry: [${z_favor}] ${z_emblem}: ${z_title}"
  echo "Steeplechase entry created: [${z_favor}] ${z_emblem}"
}

jju_rein() {
  zjju_sentinel
  local z_favor="${1:-}"
  local z_pattern=""
  local z_log_file=""
  local z_hash=""
  local z_date=""
  local z_subject=""
  local z_short_date=""

  buc_doc_brief "Query steeplechase entries from git log"
  buc_doc_param "favor" "Favor (₣HHAAA for heat-only, ₣HHPPP for pace-specific)"
  buc_doc_shown || return 0

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Normalize favor to 6-char format (BCG: temp file for output)
  local z_norm_file="${BUD_TEMP_DIR}/rein_norm.txt"
  zjju_favor_normalize "${z_favor}" > "${z_norm_file}"
  read -r z_favor < "${z_norm_file}"

  # Extract pace digits to determine query type
  local z_favor_digits="${z_favor:1}"
  local z_pace_digits="${z_favor_digits:2:3}"

  # Determine search pattern based on pace digits
  # Note: Using extended regexp with [[] and []] to match literal brackets
  if test "${z_pace_digits}" = "AAA"; then
    # Heat-only query (pace=0) - match all paces in this heat
    local z_heat_digits="${z_favor_digits:0:2}"
    local z_heat_favor="₣${z_heat_digits}"
    z_pattern="^[[]${z_heat_favor}"
  else
    # Pace-specific query - exact match
    z_pattern="^[[]${z_favor}[]]"
  fi

  # Query git log for matching commits
  buc_trace "Querying steeplechase entries with pattern: ${z_pattern}"

  # Use git log with --extended-regexp for reliable bracket matching
  # Format: %H = commit hash, %ai = author date ISO, %s = subject
  z_log_file="${BUD_TEMP_DIR}/rein_log.txt"
  git log --all --extended-regexp --grep="${z_pattern}" --format="%H%x09%ai%x09%s" > "${z_log_file}" \
    || buc_die "Git log failed"

  # Check if any entries found
  if ! test -s "${z_log_file}"; then
    echo "No steeplechase entries found for ${z_favor}"
    buc_trace "Rein found no entries, temp file: ${z_log_file}"
    return 0
  fi

  # Output entries
  echo "Steeplechase entries for ${z_favor}:"
  echo ""

  while IFS=$'\t' read -r z_hash z_date z_subject; do
    # Format date (take just the date part, not time)
    z_short_date="${z_date:0:10}"

    printf "%s  %s  %s\n" "${z_short_date}" "${z_hash:0:7}" "${z_subject}"
  done < "${z_log_file}"

  buc_trace "Rein complete, temp file: ${z_log_file}"
}

jju_notch() {
  zjju_sentinel
  local z_message="${1:-}"

  buc_doc_brief "Git commit with JJ metadata, then push"
  buc_doc_param "message" "Commit message (JJ footer auto-added)"
  buc_doc_shown || return 0

  # Validate parameter
  test -n "${z_message}" || buc_die "Parameter 'message' is required"

  # Check for staged or unstaged changes
  if git diff-index --quiet HEAD --; then
    buc_die "No changes to commit (working tree clean)"
  fi

  # Build commit message with JJ footer
  local z_commit_msg_file="${BUD_TEMP_DIR}/notch_commit.txt"
  {
    echo "${z_message}"
    echo ""
    echo "Job Jockey notch"
  } > "${z_commit_msg_file}"

  # Stage all changes (including new and deleted files)
  git add -A || buc_die "Git add failed"

  # Create commit
  git commit -F "${z_commit_msg_file}" \
    || buc_die "Git commit failed"

  # Push to remote
  buc_trace "Pushing to remote"
  git push || buc_die "Git push failed"

  buc_trace "Notched and pushed: ${z_message}"
  echo "Changes committed and pushed"
  echo "Message: ${z_message}"
}

jju_wrap() {
  zjju_sentinel
  local z_favor="${1:-}"

  buc_doc_brief "Complete pace ceremony: tally complete, chalk WRAP, advance, display"
  buc_doc_param "favor" "Pace Favor (₣HHPPP)"
  buc_doc_shown || return 0

  # Validate parameter
  test -n "${z_favor}" || buc_die "Parameter 'favor' is required"

  # Validate favor format (₣HHPPP)
  test "${z_favor:0:1}" = "₣" || buc_die "Favor must start with ₣: ${z_favor}"
  test "${#z_favor}" -eq 6 || buc_die "Favor must be 6 characters (₣HHPPP): ${z_favor}"

  # Guard: Require clean worktree
  if ! git diff-index --quiet HEAD --; then
    buc_die "Uncommitted changes. Run /jjc-notch first."
  fi

  # Push to remote (synchronous - must succeed)
  buc_trace "Pushing to remote before wrap"
  git push || buc_die "Git push failed"

  # Decode favor to get numeric heat and pace values
  local z_favor_digits="${z_favor:1}"  # Remove ₣ prefix
  local z_decode_file="${BUD_TEMP_DIR}/wrap_decode.txt"
  zjju_favor_decode "${z_favor_digits}" > "${z_decode_file}"

  local z_heat_num
  local z_pace_num
  IFS=$'\t' read -r z_heat_num z_pace_num < "${z_decode_file}"

  # Reconstruct heat favor (₣HH)
  local z_heat_digits="${z_favor_digits:0:2}"
  local z_heat_favor="₣${z_heat_digits}"

  # Format pace ID as 3-digit decimal string
  local z_pace_id
  if test "${z_pace_num}" -lt 10; then
    z_pace_id="00${z_pace_num}"
  elif test "${z_pace_num}" -lt 100; then
    z_pace_id="0${z_pace_num}"
  else
    z_pace_id="${z_pace_num}"
  fi

  # Read studbook to get pace display text
  local z_temp="${BUD_TEMP_DIR}/wrap_studbook.json"
  zjju_studbook_read > "${z_temp}"

  # Verify heat exists
  jq -e --arg heat "${z_heat_favor}" '.heats[$heat] != null' "${z_temp}" >/dev/null 2>&1 \
    || buc_die "Heat not found: ${z_heat_favor}"

  # Get pace display text
  local z_scalar_file="${BUD_TEMP_DIR}/wrap_scalar.txt"
  local z_pace_display
  jq -r --arg heat "${z_heat_favor}" --arg pace_id "${z_pace_id}" \
    '.heats[$heat].paces[] | select(.id == $pace_id) | .display' \
    "${z_temp}" > "${z_scalar_file}"
  read -r z_pace_display < "${z_scalar_file}"

  test -n "${z_pace_display}" || buc_die "Pace not found: ${z_favor}"

  # Tally: Mark pace complete in studbook
  buc_trace "Tallying pace ${z_favor} as complete"
  jju_tally "${z_favor}" "complete" >/dev/null

  # Chalk: Write WRAP entry to steeplechase
  buc_trace "Chalking WRAP entry for ${z_favor}"
  jju_chalk "${z_favor}" "WRAP" "${z_pace_display}" >/dev/null

  # Advance: Find next pending pace
  local z_next_pace_file="${BUD_TEMP_DIR}/wrap_next_pace.json"
  zjju_studbook_read > "${z_temp}"  # Re-read after tally
  jq -r --arg heat "${z_heat_favor}" \
    '.heats[$heat].paces | map(select(.status == "pending")) | first // null' \
    "${z_temp}" > "${z_next_pace_file}"

  # Check if there is a next pace
  local z_has_next
  jq -r 'if . == null then "false" else "true" end' "${z_next_pace_file}" > "${z_scalar_file}"
  read -r z_has_next < "${z_scalar_file}"

  # Display: Output wrapped pace and next pace
  echo "Pace wrapped: ${z_favor}"
  echo "  ${z_pace_display}"
  echo ""

  if test "${z_has_next}" = "true"; then
    local z_next_id
    jq -r '.id' "${z_next_pace_file}" > "${z_scalar_file}"
    read -r z_next_id < "${z_scalar_file}"

    local z_next_display
    jq -r '.display' "${z_next_pace_file}" > "${z_scalar_file}"
    read -r z_next_display < "${z_scalar_file}"

    # Convert decimal ID to pace number and encode as proper favor
    local z_next_pace_num=$((10#${z_next_id}))
    local z_next_favor_file="${BUD_TEMP_DIR}/wrap_next_favor.txt"
    zjju_favor_encode "${z_heat_num}" "${z_next_pace_num}" > "${z_next_favor_file}"
    local z_next_favor
    read -r z_next_favor < "${z_next_favor_file}"

    echo "Next pace: ₣${z_next_favor}"
    echo "  ${z_next_display}"
  else
    echo "Heat complete - all paces done"
    echo "Ready to retire heat ${z_heat_favor}"
  fi

  buc_trace "Wrap complete for ${z_favor}, temp files: ${z_temp}, ${z_next_pace_file}"
}

# eof
