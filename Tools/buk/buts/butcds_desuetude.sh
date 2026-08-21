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
# BUTCDS - Bootstrap containment guard test cases for BUK self-test
#
# Proves the guard burc_regime carries at the seam between two custodies: a
# moorings launcher stub predating the bootstrap contract meets a named
# refusal carrying its remedy, rather than the bash command-not-found the
# absent validation module used to produce; and a bootstrap that meets the
# contract passes the guard with nothing added to its output.
#
# Each fixture is a whole bash process rather than a subshell, because the
# guard reads a source-time sentinel that a subshell would inherit from the
# testbench's own fully-loaded state.

set -euo pipefail

######################################################################
# Fixture writers — each emits a bootstrap taking the BUK module dir as $1

# The pre-contract shape: console library and regime module sourced directly,
# validation and constants never loaded. This is the shape that left a live
# consumer station dark.
zbutcds_write_stale_bootstrap() {
  local -r z_path="${1}"
  printf '%s\n'                       \
    '#!/bin/bash'                     \
    'source "${1}/buc_command.sh"'    \
    'source "${1}/burc_regime.sh"'    \
    'zburc_kindle'                    \
    > "${z_path}"
}

# The contract met: validation loads first, exactly as bul_launcher orders it.
zbutcds_write_sound_bootstrap() {
  local -r z_path="${1}"
  printf '%s\n'                          \
    '#!/bin/bash'                        \
    'source "${1}/buv_validation.sh"'    \
    'source "${1}/burc_regime.sh"'       \
    'echo "burc regime module loaded"'   \
    > "${z_path}"
}

# Assert a substring stands in the refusal, naming what was sought when absent.
zbutcds_stderr_carries() {
  local z_needle="${1}"
  local z_what="${2}"
  case "${ZBUTO_STDERR}" in
    *"${z_needle}"*) return 0 ;;
  esac
  buto_fatal_now "Refusal does not state ${z_what}"  \
                 "Sought: ${z_needle}"               \
                 "STDERR: ${ZBUTO_STDERR}"
}

######################################################################
# Cases

butcds_stale_bootstrap_refuses_tcase() {
  buto_trace "Desuetude: a stale bootstrap exits on the guard's own band code"
  local -r z_fixture="${BUT_TEMP_DIR}/butcds-stale-bootstrap.sh"
  zbutcds_write_stale_bootstrap "${z_fixture}"
  buto_unit_expect_code "${BUBC_band_desuetude}" bash "${z_fixture}" "${BURD_BUK_DIR}"
}

butcds_refusal_names_condition_and_remedy_tcase() {
  buto_trace "Desuetude: the refusal names the condition, the remedy, and the canonical stub"
  local -r z_fixture="${BUT_TEMP_DIR}/butcds-stale-bootstrap-message.sh"
  zbutcds_write_stale_bootstrap "${z_fixture}"

  zbuto_invoke bash "${z_fixture}" "${BURD_BUK_DIR}"

  zbutcds_stderr_carries "STALE LAUNCHER STUB"                "the stale-launcher condition"
  zbutcds_stderr_carries "buut_launcher"                      "the emitter that regenerates a stub"
  zbutcds_stderr_carries "tt/buw-tt-cl.CreateLauncher.sh"     "the tabtarget the emitter stands behind"
  zbutcds_stderr_carries 'source "Tools/buk/bul_launcher.sh"' "the canonical stub's binding line"
}

butcds_bash_command_not_found_is_gone_tcase() {
  buto_trace "Desuetude: the stale bootstrap no longer dies as a bash command-not-found"
  local -r z_fixture="${BUT_TEMP_DIR}/butcds-stale-bootstrap-shape.sh"
  zbutcds_write_stale_bootstrap "${z_fixture}"

  zbuto_invoke bash "${z_fixture}" "${BURD_BUK_DIR}"

  test "${ZBUTO_STATUS}" != "127" || buto_fatal_now "The exit-127 death shape survives" \
                                                    "STDERR: ${ZBUTO_STDERR}"
  case "${ZBUTO_STDERR}" in
    *"command not found"*) buto_fatal_now "A bash command-not-found still reaches the operator" \
                                          "STDERR: ${ZBUTO_STDERR}" ;;
  esac
}

butcds_sound_bootstrap_passes_tcase() {
  buto_trace "Desuetude: a bootstrap meeting the contract passes the guard untouched"
  local -r z_fixture="${BUT_TEMP_DIR}/butcds-sound-bootstrap.sh"
  zbutcds_write_sound_bootstrap "${z_fixture}"
  buto_unit_expect_ok_stdout "burc regime module loaded" bash "${z_fixture}" "${BURD_BUK_DIR}"
}

# eof
