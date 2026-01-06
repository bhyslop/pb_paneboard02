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
# JJT Testbench - Job Jockey test execution

set -euo pipefail

# Get script directory
JJT_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${JJT_SCRIPT_DIR}/../buk/buc_command.sh"
source "${JJT_SCRIPT_DIR}/../buk/buv_validation.sh"
source "${JJT_SCRIPT_DIR}/../buk/but_test.sh"
source "${JJT_SCRIPT_DIR}/jju_utility.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Kindle JJU (assumes BUD environment is already set by dispatcher)
zjju_kindle

######################################################################
# Test Wrappers
#
# These wrap internal zjju_* functions for testing

jjt_favor_encode() {
  zjju_favor_encode "$@"
}

jjt_favor_decode() {
  zjju_favor_decode "$@"
}

jjt_studbook_validate() {
  zjju_studbook_validate "$@"
}

jjt_heat_seed_next() {
  zjju_heat_seed_next "$@"
}

jjt_nominate() {
  jju_nominate "$@"
}

jjt_slate() {
  jju_slate "$@"
}

jjt_tally() {
  jju_tally "$@"
}

jjt_muster() {
  jju_muster "$@"
}

jjt_reslate() {
  jju_reslate "$@"
}

jjt_rail() {
  jju_rail "$@"
}

jjt_retire_extract() {
  jju_retire_extract "$@"
}

jjt_studbook_read() {
  zjju_studbook_read "$@"
}

jjt_studbook_write() {
  zjju_studbook_write "$@"
}

jjt_chalk() {
  jju_chalk "$@"
}

jjt_rein() {
  jju_rein "$@"
}

jjt_favor_normalize() {
  zjju_favor_normalize "$@"
}

######################################################################
# Test Suites

jjt_test_favor_encoding() {
  but_section "=== Favor Encoding Tests ==="

  # Test 1: Minimum values
  but_info "Test 1: heat=0, pace=0 (minimum)"
  but_expect_ok_stdout "AAAAA" jjt_favor_encode 0 0
  but_expect_ok_stdout "0	0" jjt_favor_decode "AAAAA"

  # Test 2: Heat-only reference (heat=667, pace=0)
  but_info "Test 2: heat=667, pace=0 (heat-only reference)"
  but_expect_ok_stdout "KbAAA" jjt_favor_encode 667 0
  but_expect_ok_stdout "667	0" jjt_favor_decode "KbAAA"

  # Test 3: Heat 667, Pace 1
  but_info "Test 3: heat=667, pace=1"
  but_expect_ok_stdout "KbAAB" jjt_favor_encode 667 1
  but_expect_ok_stdout "667	1" jjt_favor_decode "KbAAB"

  # Test 4: Heat 667, Pace 2
  but_info "Test 4: heat=667, pace=2"
  but_expect_ok_stdout "KbAAC" jjt_favor_encode 667 2
  but_expect_ok_stdout "667	2" jjt_favor_decode "KbAAC"

  # Test 5: Maximum values
  but_info "Test 5: heat=4095, pace=262143 (maximum)"
  but_expect_ok_stdout "_____" jjt_favor_encode 4095 262143
  but_expect_ok_stdout "4095	262143" jjt_favor_decode "_____"

  # Test 6: Round-trip multiple values
  but_info "Test 6: Round-trip various values"
  local z_favor
  z_favor=$(jjt_favor_encode 100 500)
  but_expect_ok_stdout "100	500" jjt_favor_decode "${z_favor}"

  z_favor=$(jjt_favor_encode 2048 131072)
  but_expect_ok_stdout "2048	131072" jjt_favor_decode "${z_favor}"

  # Test 7: Invalid inputs (should fail)
  but_info "Test 7: Invalid inputs (expect failures)"
  but_expect_fatal jjt_favor_encode 4096 0  # heat too large
  but_expect_fatal jjt_favor_encode 0 262144  # pace too large
  but_expect_fatal jjt_favor_encode -1 0  # heat negative
  but_expect_fatal jjt_favor_decode "ABCD"  # too short
  but_expect_fatal jjt_favor_decode "ABCDEF"  # too long
  but_expect_fatal jjt_favor_decode "ABC@D"  # invalid char

  but_section "=== All favor encoding tests passed ==="
}

jjt_test_favor_normalization() {
  but_section "=== Favor Normalization Tests ==="

  # Test 1: 3-char input (₣HH) → 6-char output (₣HHAAA)
  but_info "Test 1: Normalize 3-char heat favor ₣AA to ₣AAAAA"
  but_expect_ok_stdout "₣AAAAA" jjt_favor_normalize "₣AA"

  # Test 2: 3-char input (₣Kb) → 6-char output (₣KbAAA)
  but_info "Test 2: Normalize 3-char heat favor ₣Kb to ₣KbAAA"
  but_expect_ok_stdout "₣KbAAA" jjt_favor_normalize "₣Kb"

  # Test 3: 6-char input (₣HHPPP) → pass through unchanged
  but_info "Test 3: Normalize 6-char pace favor ₣KbAAB (pass through)"
  but_expect_ok_stdout "₣KbAAB" jjt_favor_normalize "₣KbAAB"

  # Test 4: 6-char input with AAA (heat-only reference) → pass through
  but_info "Test 4: Normalize 6-char heat-only favor ₣AAAAA (pass through)"
  but_expect_ok_stdout "₣AAAAA" jjt_favor_normalize "₣AAAAA"

  # Test 5: Invalid inputs (should fail)
  but_info "Test 5: Invalid inputs (expect failures)"
  but_expect_fatal jjt_favor_normalize "AA"          # Missing ₣ prefix
  but_expect_fatal jjt_favor_normalize "₣A"          # Too short (2 chars)
  but_expect_fatal jjt_favor_normalize "₣AAAA"       # 5 chars (invalid length)
  but_expect_fatal jjt_favor_normalize "₣AAAAAAA"    # 8 chars (too long)
  but_expect_fatal jjt_favor_normalize ""            # Empty string

  but_section "=== All favor normalization tests passed ==="
}

jjt_test_studbook_validation() {
  but_section "=== Studbook Validation Tests ==="

  # Test 1: Valid empty studbook
  but_info "Test 1: Valid empty studbook"
  but_expect_ok jjt_studbook_validate '{"heats":{},"next_heat_seed":"AA"}'

  # Test 2: Valid studbook with heat and paces
  but_info "Test 2: Valid studbook with heat and paces"
  local z_valid_full='{
    "heats": {
      "₣Kb": {
        "datestamp": "260101",
        "display": "Test Heat",
        "silks": "test-heat",
        "status": "current",
        "paces": [
          {"id": "001", "display": "First pace", "status": "current"},
          {"id": "002", "display": "Second pace\nWith newlines\nIn description", "status": "pending"}
        ]
      }
    },
    "next_heat_seed": "Kc"
  }'
  but_expect_ok jjt_studbook_validate "${z_valid_full}"

  # Test 3: Valid with all pace statuses
  but_info "Test 3: Valid with all pace statuses"
  local z_all_statuses='{
    "heats": {
      "₣AA": {
        "datestamp": "260101",
        "display": "Status Test",
        "silks": "status-test",
        "status": "current",
        "paces": [
          {"id": "001", "display": "Current", "status": "current"},
          {"id": "002", "display": "Pending", "status": "pending"},
          {"id": "003", "display": "Complete", "status": "complete"},
          {"id": "004", "display": "Abandoned", "status": "abandoned"},
          {"id": "005", "display": "Malformed", "status": "malformed"}
        ]
      }
    },
    "next_heat_seed": "AB"
  }'
  but_expect_ok jjt_studbook_validate "${z_all_statuses}"

  # Test 4: Invalid - bad heat key (missing ₣ prefix)
  but_info "Test 4: Invalid - bad heat key (missing ₣)"
  but_expect_fatal jjt_studbook_validate '{"heats":{"Kb":{"datestamp":"260101","display":"X","silks":"x","status":"current","paces":[]}},"next_heat_seed":"AA"}'

  # Test 5: Invalid - bad pace status
  but_info "Test 5: Invalid - bad pace status"
  local z_bad_status='{
    "heats": {
      "₣Kb": {
        "datestamp": "260101",
        "display": "Test",
        "silks": "test",
        "status": "current",
        "paces": [{"id": "001", "display": "Bad", "status": "invalid"}]
      }
    },
    "next_heat_seed": "Kc"
  }'
  but_expect_fatal jjt_studbook_validate "${z_bad_status}"

  # Test 6: Invalid - bad datestamp format
  but_info "Test 6: Invalid - bad datestamp format"
  local z_bad_date='{
    "heats": {
      "₣Kb": {
        "datestamp": "2026-01-01",
        "display": "Test",
        "silks": "test",
        "status": "current",
        "paces": []
      }
    },
    "next_heat_seed": "Kc"
  }'
  but_expect_fatal jjt_studbook_validate "${z_bad_date}"

  # Test 7: Invalid - bad silks format (uppercase)
  but_info "Test 7: Invalid - bad silks format"
  local z_bad_silks='{
    "heats": {
      "₣Kb": {
        "datestamp": "260101",
        "display": "Test",
        "silks": "Test_Heat",
        "status": "current",
        "paces": []
      }
    },
    "next_heat_seed": "Kc"
  }'
  but_expect_fatal jjt_studbook_validate "${z_bad_silks}"

  but_section "=== All studbook validation tests passed ==="
}

jjt_test_studbook_ops() {
  but_section "=== Studbook Operations Tests ==="

  # Redirect studbook and paddock to temp directory for test isolation
  buc_trace "Redirecting studbook paths to BUD_TEMP_DIR"
  ZJJU_STUDBOOK_FILE="${BUD_TEMP_DIR}/jjs_studbook.json"
  ZJJU_PADDOCK_DIR="${BUD_TEMP_DIR}"

  # Setup: Create empty studbook
  but_info "Setup: Creating test studbook"
  local z_empty='{"heats":{},"next_heat_seed":"AA"}'
  jjt_studbook_write "${z_empty}"

  # Test 1: Heat seed increment
  but_info "Test 1: Heat seed increment"
  but_expect_ok_stdout "AB" jjt_heat_seed_next "AA"
  but_expect_ok_stdout "AC" jjt_heat_seed_next "AB"
  but_expect_ok_stdout "BA" jjt_heat_seed_next "A_"
  but_expect_ok_stdout "Aa" jjt_heat_seed_next "AZ"

  # Test 2: Nominate first heat
  but_info "Test 2: Nominate first heat"
  but_expect_ok jjt_nominate "Test Heat One" "test-heat-one"

  # Verify heat was created
  local z_studbook
  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AA"] != null' >/dev/null 2>&1 \
    || but_fatal "Heat ₣AA not found after nominate"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].silks == "test-heat-one"' >/dev/null 2>&1 \
    || but_fatal "Heat silks incorrect"
  echo "${z_studbook}" | jq -e '.next_heat_seed == "AB"' >/dev/null 2>&1 \
    || but_fatal "next_heat_seed not incremented"

  # Test 3: Nominate second heat
  but_info "Test 3: Nominate second heat"
  but_expect_ok jjt_nominate "Test Heat Two" "test-heat-two"

  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AB"] != null' >/dev/null 2>&1 \
    || but_fatal "Heat ₣AB not found"
  echo "${z_studbook}" | jq -e '.next_heat_seed == "AC"' >/dev/null 2>&1 \
    || but_fatal "next_heat_seed not incremented to AC"

  # Test 4: Muster (list heats)
  but_info "Test 4: Muster lists heats"
  but_expect_ok jjt_muster

  # Test 5: Slate first pace (should be status "current")
  but_info "Test 5: Slate first pace to ₣AA"
  but_expect_ok jjt_slate "₣AAAAA" "First pace"

  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces | length == 1' >/dev/null 2>&1 \
    || but_fatal "Pace count should be 1"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[0].id == "001"' >/dev/null 2>&1 \
    || but_fatal "First pace ID should be 001"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[0].status == "current"' >/dev/null 2>&1 \
    || but_fatal "First pace status should be current"

  # Test 6: Slate second pace (should be status "pending")
  but_info "Test 6: Slate second pace to ₣AA"
  but_expect_ok jjt_slate "₣AAAAA" "Second pace"

  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces | length == 2' >/dev/null 2>&1 \
    || but_fatal "Pace count should be 2"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[1].status == "pending"' >/dev/null 2>&1 \
    || but_fatal "Second pace status should be pending"

  # Test 7: Slate third pace to ₣AA
  but_info "Test 7: Slate third pace to ₣AA"
  but_expect_ok jjt_slate "₣AAAAA" "Third pace"

  # Test 8: Tally - change pace status
  but_info "Test 8: Tally - mark pace complete"
  but_expect_ok jjt_tally "₣AAAAB" "complete"

  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[0].status == "complete"' >/dev/null 2>&1 \
    || but_fatal "Pace 001 should be marked complete"

  # Test 9: Tally - invalid state
  but_info "Test 9: Tally - invalid state (expect failure)"
  but_expect_fatal jjt_tally "₣AAAAB" "invalid-state"

  # Test 10: Reslate - change pace description
  but_info "Test 10: Reslate - revise pace description"
  but_expect_ok jjt_reslate "₣AAAAC" "Second pace (revised)"

  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[1].display == "Second pace (revised)"' >/dev/null 2>&1 \
    || but_fatal "Pace 002 description should be revised"

  # Test 11: Rail - reorder paces
  but_info "Test 11: Rail - reorder paces for ₣AA (003 001 002)"
  but_expect_ok jjt_rail "₣AAAAA" "003 001 002"

  z_studbook="$(jjt_studbook_read)"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[0].id == "003"' >/dev/null 2>&1 \
    || but_fatal "First pace should be 003 after reordering"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[1].id == "001"' >/dev/null 2>&1 \
    || but_fatal "Second pace should be 001 after reordering"
  echo "${z_studbook}" | jq -e '.heats["₣AA"].paces[2].id == "002"' >/dev/null 2>&1 \
    || but_fatal "Third pace should be 002 after reordering"

  # Test 12: Rail - wrong count (expect failure)
  but_info "Test 12: Rail - wrong count (expect failure)"
  but_expect_fatal jjt_rail "₣AAAAA" "001 002"

  # Test 13: Rail - duplicate ID (expect failure)
  but_info "Test 13: Rail - duplicate ID (expect failure)"
  but_expect_fatal jjt_rail "₣AAAAA" "001 001 002"

  # Test 14: Retire extract
  but_info "Test 14: Retire extract - generate trophy content"
  but_expect_ok jjt_retire_extract "₣AAAAA"

  # Test 15: Nominate with invalid silks
  but_info "Test 15: Nominate with invalid silks (expect failure)"
  but_expect_fatal jjt_nominate "Bad Silks" "Bad_Silks_Here"

  but_section "=== All studbook operations tests passed ==="
}

jjt_test_steeplechase() {
  but_section "=== Steeplechase Operations Tests ==="

  # Local declarations
  local z_rein_out="${BUD_TEMP_DIR}/rein_test.txt"
  local z_chalk_verify="${BUD_TEMP_DIR}/chalk_verify.txt"

  # These tests operate on the real git repo, so use test favors that won't
  # conflict with actual heats: ₣ZZ (heat) with paces ₣ZZAAA, ₣ZZAAB, etc.

  # Test 1: Chalk creates a commit
  but_info "Test 1: Chalk - create steeplechase entry"
  but_expect_ok jjt_chalk "₣ZZAAA" "TEST" "Test steeplechase entry 1"

  # Verify the commit was created by checking git log (BCG: temp file, not pipeline)
  git log -1 --grep="^\[₣ZZAAA\] TEST" --format="%s" > "${z_chalk_verify}" \
    || but_fatal "git log failed"
  grep -q "^\[₣ZZAAA\] TEST: Test steeplechase entry 1$" "${z_chalk_verify}" \
    || but_fatal "Chalk commit not found in git log"

  # Test 2: Chalk creates another entry for same heat
  but_info "Test 2: Chalk - create second entry for same heat"
  but_expect_ok jjt_chalk "₣ZZAAB" "APPROACH" "Starting test pace 2"

  # Test 3: Chalk creates entry for different pace
  but_info "Test 3: Chalk - create entry for different heat"
  but_expect_ok jjt_chalk "₣ZYAAA" "NOTE" "Different heat entry"

  # Test 4: Rein queries heat entries
  but_info "Test 4: Rein - query entries for heat ₣ZZ"
  jjt_rein "₣ZZ" > "${z_rein_out}"

  # Should find at least 2 entries for ₣ZZ heat (₣ZZAAA and ₣ZZAAB)
  grep -q "₣ZZAAA" "${z_rein_out}" \
    || but_fatal "Rein did not find ₣ZZAAA entry"
  grep -q "₣ZZAAB" "${z_rein_out}" \
    || but_fatal "Rein did not find ₣ZZAAB entry"

  # Should NOT find ₣ZY entry when querying ₣ZZ
  grep -q "₣ZYAAA" "${z_rein_out}" \
    && but_fatal "Rein should not find ₣ZYAAA when querying ₣ZZ"

  # Test 5: Rein queries specific pace
  but_info "Test 5: Rein - query entries for specific pace ₣ZZAAB"
  jjt_rein "₣ZZAAB" > "${z_rein_out}"

  # Should find ₣ZZAAB but not ₣ZZAAA (AAA is heat-only, AAB is pace-specific)
  grep -q "₣ZZAAB" "${z_rein_out}" \
    || but_fatal "Rein did not find ₣ZZAAB entry"
  grep -q "₣ZZAAA" "${z_rein_out}" \
    && but_fatal "Rein should not find ₣ZZAAA when querying ₣ZZAAB specifically"

  # Test 6: Rein with invalid favor format
  but_info "Test 6: Rein - invalid favor format (expect failure)"
  but_expect_fatal jjt_rein "INVALID"

  # Test 7: Chalk with missing parameters
  but_info "Test 7: Chalk - missing parameters (expect failure)"
  but_expect_fatal jjt_chalk "₣ZZAAA" ""
  but_expect_fatal jjt_chalk "₣ZZAAA" "EMBLEM"

  but_section "=== All steeplechase operations tests passed ==="
}

######################################################################
# Main

# When called via BUD dispatch: $1=tabtarget-stem, $2=suite-name
# When called directly: $1=suite-name
z_suite="${2:-${1:-}}"

case "${z_suite}" in
  favor)
    jjt_test_favor_encoding
    jjt_test_favor_normalization
    ;;
  studbook)
    jjt_test_studbook_validation
    ;;
  ops)
    jjt_test_studbook_ops
    ;;
  steeple)
    jjt_test_steeplechase
    ;;
  all)
    jjt_test_favor_encoding
    jjt_test_favor_normalization
    jjt_test_studbook_validation
    jjt_test_studbook_ops
    jjt_test_steeplechase
    ;;
  *)
    echo "JJT Testbench - Job Jockey test execution"
    echo ""
    echo "Usage: ${0##*/} <suite>"
    echo ""
    echo "Test Suites:"
    echo "  favor     Test favor encoding/decoding"
    echo "  studbook  Test studbook validation"
    echo "  ops       Test studbook operations"
    echo "  steeple   Test steeplechase operations (git)"
    echo "  all       Run all test suites"
    exit 1
    ;;
esac

# eof
