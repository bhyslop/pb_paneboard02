#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
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
# BUTCFC - Fact-chaining (consume side) test cases for BUK self-test
#
# Exercises buf_relay, buf_read_fact_capture, and buf_elect_fact_capture against
# the live dispatch directories.
# BURD_PREVIOUS_DIR and BURD_OUTPUT_DIR are readonly (locked by the BURD regime),
# so these cases cannot redirect them to scratch — they seed uniquely-named
# (butcfc_*) facts into the real previous/ and current/ dirs and assert on those,
# the same precedent the burx-exchange multi cases use for the output dir. The
# directories are writable even though the path variables are not. The full
# cross-dispatch current/->previous/ promotion is covered by a chaining test
# (deferred). Pure local — no GCP, containers, network.

set -euo pipefail

######################################################################
# Helper

# Seed a fact file under a dir, mirroring the producer's trailing-newline
# format (printf '%s\n'), so the read path exercises newline stripping.
zbutcfc_seed() {
  local -r z_dir="${1}"
  local -r z_name="${2}"
  local -r z_value="${3}"
  printf '%s\n' "${z_value}" > "${z_dir}/${z_name}" || buto_fatal "seed failed: ${z_dir}/${z_name}"
}

######################################################################
# Test cases — direct assertions inside zbute_tcase subshell

butcfc_relay_forwards_tcase() {
  buto_trace "buf_relay: forwards a previous fact into current"

  mkdir -p "${BURD_PREVIOUS_DIR}" || buto_fatal "mkdir previous failed"
  zbutcfc_seed "${BURD_PREVIOUS_DIR}" "butcfc_fwd" "forwarded-value"

  buf_relay || buto_fatal "buf_relay failed"

  test -f "${BURD_OUTPUT_DIR}/butcfc_fwd" || buto_fatal "buf_relay did not forward butcfc_fwd"
  local -r z_got=$(<"${BURD_OUTPUT_DIR}/butcfc_fwd")
  test "${z_got}" = "forwarded-value" || buto_fatal "forwarded content mismatch: '${z_got}'"
}

butcfc_relay_preserves_current_tcase() {
  buto_trace "buf_relay: never clobbers a file already present in current"

  mkdir -p "${BURD_PREVIOUS_DIR}" || buto_fatal "mkdir previous failed"
  zbutcfc_seed "${BURD_PREVIOUS_DIR}" "butcfc_pres" "from-previous"
  zbutcfc_seed "${BURD_OUTPUT_DIR}"   "butcfc_pres" "from-current"

  buf_relay || buto_fatal "buf_relay failed"

  local -r z_got=$(<"${BURD_OUTPUT_DIR}/butcfc_pres")
  test "${z_got}" = "from-current" \
    || buto_fatal "buf_relay clobbered an existing current file: '${z_got}'"
}

butcfc_relay_idempotent_tcase() {
  buto_trace "buf_relay: a second call is a no-op no-clobber and still succeeds"

  mkdir -p "${BURD_PREVIOUS_DIR}" || buto_fatal "mkdir previous failed"
  zbutcfc_seed "${BURD_PREVIOUS_DIR}" "butcfc_idem" "v1"

  buf_relay || buto_fatal "buf_relay first call failed"
  buf_relay || buto_fatal "buf_relay second call failed"

  local -r z_got=$(<"${BURD_OUTPUT_DIR}/butcfc_idem")
  test "${z_got}" = "v1" || buto_fatal "idempotent relay altered content: '${z_got}'"
}

butcfc_read_fact_tcase() {
  buto_trace "buf_read_fact_capture: emits the bare value (newline stripped) from previous"

  mkdir -p "${BURD_PREVIOUS_DIR}" || buto_fatal "mkdir previous failed"
  zbutcfc_seed "${BURD_PREVIOUS_DIR}" "butcfc_greeting" "hello world"

  local z_value
  z_value=$(buf_read_fact_capture "butcfc_greeting") || buto_fatal "buf_read_fact_capture failed on present fact"
  test "${z_value}" = "hello world" \
    || buto_fatal "buf_read_fact_capture returned '${z_value}' expected 'hello world'"
}

butcfc_read_fact_absent_tcase() {
  buto_trace "buf_read_fact_capture: fails hard when the named fact is absent"

  local -r z_stderr="${BUT_TEMP_DIR}/read_absent_stderr.txt"

  local z_status=0
  buf_read_fact_capture "butcfc_definitely_absent_fact" 2>"${z_stderr}" || z_status=$?
  test "${z_status}" -ne 0 \
    || buto_fatal "buf_read_fact_capture should fail on an absent fact"
}

butcfc_elect_express_tcase() {
  buto_trace "buf_elect_fact_capture: a non-empty express value wins; the chained fact is not read"

  # No previous fact seeded — if elect read the (absent) fact it would fail.
  local z_value
  z_value=$(buf_elect_fact_capture "express-wins" "butcfc_definitely_absent_fact") \
    || buto_fatal "buf_elect_fact_capture failed with a non-empty express value"
  test "${z_value}" = "express-wins" \
    || buto_fatal "buf_elect_fact_capture returned '${z_value}' expected 'express-wins'"
}

butcfc_elect_chain_tcase() {
  buto_trace "buf_elect_fact_capture: an empty express value falls back to the chained fact"

  mkdir -p "${BURD_PREVIOUS_DIR}" || buto_fatal "mkdir previous failed"
  zbutcfc_seed "${BURD_PREVIOUS_DIR}" "butcfc_chained" "from-chain"

  local z_value
  z_value=$(buf_elect_fact_capture "" "butcfc_chained") \
    || buto_fatal "buf_elect_fact_capture failed falling back to a present chained fact"
  test "${z_value}" = "from-chain" \
    || buto_fatal "buf_elect_fact_capture returned '${z_value}' expected 'from-chain'"

  # Empty express AND absent fact is the broken-chain failure path.
  local z_status=0
  buf_elect_fact_capture "" "butcfc_definitely_absent_fact" 2>/dev/null || z_status=$?
  test "${z_status}" -ne 0 \
    || buto_fatal "buf_elect_fact_capture should fail when express is empty and the fact is absent"
}

# eof
