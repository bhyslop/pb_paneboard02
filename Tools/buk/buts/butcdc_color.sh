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
# BUTCDC - dispatch color-verdict test cases for BUK self-test
#
# Exercises zbud_resolve_color's read-input/write-verdict split (BUr_q2m):
# BURE_COLOR is read as the operator's optional override and never written;
# the resolved 0/1 verdict lands under BURD_COLOR instead.
#
# Each case drives the resolver in a FRESH BASH PROCESS rather than in the
# case's own isolation subshell.  Two constraints force this and neither is
# incidental: the testbench has already run zburd_kindle, whose buv_lock BURD
# makes every enrolled BURD_ name readonly, and readonly is inherited by
# subshells but never survives a new process.  Sourcing the dispatch spine
# in-subshell would die on its own top-level BURD_REGIME_FILE assignment,
# and calling the resolver there would die re-exporting the locked
# BURD_COLOR.  The spine's execute-only guard is what makes sourcing it
# inert.  A fresh process also confines whatever the spine defines at its
# own top level, which is what keeps this case sound as the spine grows —
# the spine declares no sentinel at all, being bootstrap infrastructure
# rather than a full module, so nothing it defines can shadow the
# testbench's zburd_sentinel.
#
# All tests are pure local — no GCP, no containers, no network.

set -euo pipefail

######################################################################
# Internal helper

# Drive zbud_resolve_color in a fresh process under a controlled environment.
# Writes "<BURD_COLOR>|<BURE_COLOR or UNSET>" to the named file.
# Usage: zbutcdc_probe <outfile> [env-assignment-or--u-name ...]
zbutcdc_probe() {
  local -r z_out="${1}"
  shift

  local -r z_body='source "${BURD_BUK_DIR}/bud_dispatch.sh"
                   zbud_resolve_color
                   printf "%s|%s\n" "${BURD_COLOR}" "${BURE_COLOR:-UNSET}"'

  env "$@" bash -c "${z_body}" > "${z_out}" 2>"${z_out}.err" \
    || buto_fatal_now "Resolver probe failed — see ${z_out}.err"
}

######################################################################
# Test cases

butcdc_no_color_forces_zero_tcase() {
  buto_trace "COLOR: NO_COLOR forces BURD_COLOR=0 and leaves BURE_COLOR untouched"

  local -r z_out="${BUT_TEMP_DIR}/butcdc_no_color.txt"
  zbutcdc_probe "${z_out}" NO_COLOR=1 BURE_COLOR=1

  local -r z_got=$(<"${z_out}")
  test "${z_got}" = "0|1" \
    || buto_fatal_now "NO_COLOR must force BURD_COLOR=0 with BURE_COLOR intact, got '${z_got}' (expected '0|1')"
}

butcdc_explicit_one_passes_through_tcase() {
  buto_trace "COLOR: BURE_COLOR=1 resolves BURD_COLOR=1, BURE_COLOR unwritten"

  local -r z_out="${BUT_TEMP_DIR}/butcdc_explicit_one.txt"
  zbutcdc_probe "${z_out}" -u NO_COLOR BURE_COLOR=1

  local -r z_got=$(<"${z_out}")
  test "${z_got}" = "1|1" \
    || buto_fatal_now "BURE_COLOR=1 must resolve BURD_COLOR=1 with BURE_COLOR intact, got '${z_got}' (expected '1|1')"
}

butcdc_explicit_zero_passes_through_tcase() {
  buto_trace "COLOR: BURE_COLOR=0 resolves BURD_COLOR=0, BURE_COLOR unwritten"

  local -r z_out="${BUT_TEMP_DIR}/butcdc_explicit_zero.txt"
  zbutcdc_probe "${z_out}" -u NO_COLOR BURE_COLOR=0

  local -r z_got=$(<"${z_out}")
  test "${z_got}" = "0|0" \
    || buto_fatal_now "BURE_COLOR=0 must resolve BURD_COLOR=0 with BURE_COLOR intact, got '${z_got}' (expected '0|0')"
}

butcdc_auto_leaves_operator_input_unset_tcase() {
  buto_trace "COLOR: auto (BURE_COLOR unset) + TERM=dumb resolves 0 and never invents a BURE_COLOR"

  local -r z_out="${BUT_TEMP_DIR}/butcdc_auto_dumb.txt"
  zbutcdc_probe "${z_out}" -u NO_COLOR -u BURE_COLOR TERM=dumb

  # The whole point of the re-file: dispatch resolving a verdict must not
  # leave an operator-ambient BURE_COLOR behind for a child to inherit.
  local -r z_got=$(<"${z_out}")
  test "${z_got}" = "0|UNSET" \
    || buto_fatal_now "auto+TERM=dumb must resolve BURD_COLOR=0 leaving BURE_COLOR unset, got '${z_got}' (expected '0|UNSET')"
}

# eof
