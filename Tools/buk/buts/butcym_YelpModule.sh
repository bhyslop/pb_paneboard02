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
# BUTCYM - Yelp module test cases for BUK self-test
#
# Exercises buym_yelp.sh: diastema markers, yawp functions,
# buyf_format_yawp resolver, configurators, and buh semantic
# line functions.  Pure local — no GCP, no containers.

set -euo pipefail

######################################################################
# Helpers — each runs in a subshell via zbuto_invoke

zbutcym_cmd_resolve() {
  buyc_unconditional
  zbuym_kindle
  buyy_cmd_yawp "git status"
  buyf_format_yawp "" "${z_buym_yelp}"
  printf '%b' "${z_buym_format}" >&2
}

zbutcym_link_osc8() {
  buyc_unconditional
  zbuym_kindle
  buyy_link_yawp "https://example.com" "Depot"
  buyf_format_yawp "" "${z_buym_yelp}"
  printf '%b' "${z_buym_format}" >&2
}

zbutcym_link_fallback() {
  export BURD_NO_HYPERLINKS=1
  buyc_unconditional
  zbuym_kindle
  buyy_link_yawp "https://example.com" "Depot"
  buyf_format_yawp "" "${z_buym_yelp}"
  printf '%b' "${z_buym_format}" >&2
}

zbutcym_ambient_preservation() {
  buyc_unconditional
  zbuym_kindle
  buyy_cmd_yawp "test"
  buyf_format_yawp "\033[1;33m" "${z_buym_yelp}"
  printf '%b' "${z_buym_format}" >&2
}

zbutcym_fast_path() {
  buyc_unconditional
  zbuym_kindle
  buyf_format_yawp "" "plain text no markers"
  printf '%b' "${z_buym_format}" >&2
}

zbutcym_multi_markers() {
  buyc_unconditional
  zbuym_kindle
  buyy_link_yawp "https://example.com" "Vessel"
  local z_vessel="${z_buym_yelp}"
  buyy_link_yawp "https://example.com" "Depot"
  local z_depot="${z_buym_yelp}"
  buyy_cmd_yawp "run"
  local z_cmd="${z_buym_yelp}"
  buyf_format_yawp "" "A ${z_vessel} in a ${z_depot} via ${z_cmd}."
  printf '%b' "${z_buym_format}" >&2
}

zbutcym_plain_mode() {
  buyc_plain
  zbuym_kindle
  buyy_cmd_yawp "test"
  buyf_format_yawp "" "${z_buym_yelp}"
  printf '%b' "${z_buym_format}" >&2
}

######################################################################
# Test cases

butcym_cmd_resolve_tcase() {
  buto_trace "buyy_cmd_yawp: CMD diastema resolves to cyan ANSI"
  zbuto_invoke zbutcym_cmd_resolve
  buto_fatal_on_error "${ZBUTO_STATUS}" "cmd resolve failed" "STDERR: ${ZBUTO_STDERR}"
  local z_cyan
  z_cyan=$(printf '\033[36m')
  case "${ZBUTO_STDERR}" in
    *"${z_cyan}git status"*) ;;
    *) buto_fatal "Cyan escape not found around 'git status'" "Got: ${ZBUTO_STDERR}" ;;
  esac
  # Verify no diastema bytes survive
  case "${ZBUTO_STDERR}" in
    *$'\x02'*) buto_fatal "Diastema byte survived in output" "Got: ${ZBUTO_STDERR}" ;;
    *) ;;
  esac
}

butcym_link_osc8_tcase() {
  buto_trace "buyy_link_yawp: LINK diastema resolves to OSC-8 hyperlink"
  zbuto_invoke zbutcym_link_osc8
  buto_fatal_on_error "${ZBUTO_STATUS}" "link osc8 failed" "STDERR: ${ZBUTO_STDERR}"
  local z_osc
  z_osc=$(printf '\033]8;;')
  case "${ZBUTO_STDERR}" in
    *"${z_osc}https://example.com#Depot"*) ;;
    *) buto_fatal "OSC-8 URL not found" "Got: ${ZBUTO_STDERR}" ;;
  esac
  case "${ZBUTO_STDERR}" in
    *"Depot"*) ;;
    *) buto_fatal "Display text 'Depot' not found" "Got: ${ZBUTO_STDERR}" ;;
  esac
}

butcym_link_fallback_tcase() {
  buto_trace "buyy_link_yawp: BURD_NO_HYPERLINKS falls back to angle-bracket URL"
  zbuto_invoke zbutcym_link_fallback
  buto_fatal_on_error "${ZBUTO_STATUS}" "link fallback failed" "STDERR: ${ZBUTO_STDERR}"
  case "${ZBUTO_STDERR}" in
    *"<https://example.com#Depot>"*) ;;
    *) buto_fatal "Fallback angle-bracket URL not found" "Got: ${ZBUTO_STDERR}" ;;
  esac
  local z_osc
  z_osc=$(printf '\033]8;;')
  case "${ZBUTO_STDERR}" in
    *"${z_osc}"*) buto_fatal "OSC-8 should not appear in fallback mode" ;;
    *) ;;
  esac
}

butcym_ambient_preservation_tcase() {
  buto_trace "buyf_format_yawp: DIASTEMA_END restores ambient color, not terminal default"
  zbuto_invoke zbutcym_ambient_preservation
  buto_fatal_on_error "${ZBUTO_STATUS}" "ambient preservation failed" "STDERR: ${ZBUTO_STDERR}"
  # After the CMD region closes, the ambient (bright yellow) should appear
  local z_yellow
  z_yellow=$(printf '\033[1;33m')
  local z_cyan
  z_cyan=$(printf '\033[36m')
  # Pattern: cyan "test" then ambient yellow (not reset)
  case "${ZBUTO_STDERR}" in
    *"${z_cyan}test${z_yellow}"*) ;;
    *) buto_fatal "Ambient color not restored after DIASTEMA_END" "Got: ${ZBUTO_STDERR}" ;;
  esac
}

butcym_fast_path_tcase() {
  buto_trace "buyf_format_yawp: no diastema markers takes fast path"
  zbuto_invoke zbutcym_fast_path
  buto_fatal_on_error "${ZBUTO_STATUS}" "fast path failed" "STDERR: ${ZBUTO_STDERR}"
  case "${ZBUTO_STDERR}" in
    *"plain text no markers"*) ;;
    *) buto_fatal "Plain text not found in output" "Got: ${ZBUTO_STDERR}" ;;
  esac
  case "${ZBUTO_STDERR}" in
    *$'\x02'*) buto_fatal "Diastema byte in fast-path output" "Got: ${ZBUTO_STDERR}" ;;
    *) ;;
  esac
}

butcym_multi_markers_tcase() {
  buto_trace "buyf_format_yawp: multiple links and cmd in one string all resolve"
  zbuto_invoke zbutcym_multi_markers
  buto_fatal_on_error "${ZBUTO_STATUS}" "multi markers failed" "STDERR: ${ZBUTO_STDERR}"
  local z_osc
  z_osc=$(printf '\033]8;;')
  local z_cyan
  z_cyan=$(printf '\033[36m')
  # Two OSC-8 links (Vessel and Depot)
  local z_count=0
  local z_tmp="${ZBUTO_STDERR}"
  while test "${z_tmp}" != "${z_tmp#*"${z_osc}"}"; do
    z_count=$((z_count + 1))
    z_tmp="${z_tmp#*"${z_osc}"}"
  done
  # Each link has two OSC-8 sequences (open + close), so 2 links = 4 occurrences
  test "${z_count}" -ge 4 || buto_fatal "Expected at least 4 OSC-8 sequences for 2 links, got ${z_count}"
  # CMD marker resolved
  case "${ZBUTO_STDERR}" in
    *"${z_cyan}run"*) ;;
    *) buto_fatal "CMD marker not resolved" "Got: ${ZBUTO_STDERR}" ;;
  esac
  # No diastema survivors
  case "${ZBUTO_STDERR}" in
    *$'\x02'*) buto_fatal "Diastema byte survived in multi-marker output" ;;
    *) ;;
  esac
}

butcym_plain_mode_tcase() {
  buto_trace "buyc_plain: no ANSI escapes in output"
  zbuto_invoke zbutcym_plain_mode
  buto_fatal_on_error "${ZBUTO_STATUS}" "plain mode failed" "STDERR: ${ZBUTO_STDERR}"
  case "${ZBUTO_STDERR}" in
    *$'\033'*) buto_fatal "ESC byte found in plain mode output" "Got: ${ZBUTO_STDERR}" ;;
    *) ;;
  esac
  case "${ZBUTO_STDERR}" in
    *"test"*) ;;
    *) buto_fatal "Content 'test' not found in plain mode output" "Got: ${ZBUTO_STDERR}" ;;
  esac
  case "${ZBUTO_STDERR}" in
    *$'\x02'*) buto_fatal "Diastema byte survived in plain mode" ;;
    *) ;;
  esac
}

# eof
