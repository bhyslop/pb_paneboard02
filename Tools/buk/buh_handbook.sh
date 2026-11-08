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
# Bash Utility Handbook - Always-visible user interaction output
#
# This module provides formatted output for interactive procedures where
# the user MUST see the output to proceed (OAuth flows, manual steps, etc).
# All output goes to stderr and is NOT subject to verbosity control.
#
# All display is routed through yelp-aware functions:
#   buh_line   — prose (BUYC_RESET ambient)
#   buh_code   — command/code (BUYC_CYAN ambient)
#   buh_warn   — warning (BUYC_BRIGHT_YELLOW ambient)
#   buh_error  — error (BUYC_BRIGHT_RED ambient)
#   buh_link   — OSC-8 hyperlink with prefix/suffix
#   buh_tt     — resolved tabtarget display
#
# A generated track renders through these beside them, printing its
# performance and running none of it:
#   buh_control_*   — one per handbook control motif, its label at the line's head
#   buh_ending      — the line that closes a track
#
# Callers compose lines from yelp yawp captures (buym_*_yawp)
# and pass the pre-rendered string to buh_line:
#   buym_cmd_yawp "gcloud"; local -r z_cmd="${z_buym_yelp}"
#   buh_line "Run ${z_cmd} to authenticate."

set -euo pipefail

# Multiple inclusion guard
test -z "${ZBUH_SOURCED:-}" || buc_die_now "Module buh multiply sourced - check sourcing hierarchy"
ZBUH_SOURCED=1

# Handbook control labels — the word a rendered track prints for a handbook
# control, one per control kind. Each name's tail is the kind's own word, so
# a renderer finds the label by the kind it renders.
readonly BUH_label_fatal="STOP"
readonly BUH_label_warn="CAUTION"
readonly BUH_label_stow="STOW"
readonly BUH_label_require="VERIFY"
readonly BUH_label_show="NOTE"

######################################################################
# Internal: Kindle and Sentinel

zbuh_kindle() {
  test -z "${ZBUH_KINDLED:-}" || return 0

  # Ensure yelp module is kindled — buh_section/buh_line/buh_code use BUYC_* constants
  zbuym_sentinel

  # Color support detection
  local z_use_color=0
  if test -z "${NO_COLOR:-}" && test -n "${TERM:-}" && test "${TERM}" != "dumb"; then
    z_use_color=1
  fi

  if test "${z_use_color}" = "1"; then
    readonly ZBUH_R="${ZBUYM_ESC}[0m"          # Reset
    readonly ZBUH_E="${ZBUYM_ESC}[1;31m"       # Error (bright red)
    readonly ZBUH_S="${ZBUYM_ESC}[1;37m"       # Section (bright white)
  else
    readonly ZBUH_R=""
    readonly ZBUH_E=""
    readonly ZBUH_S=""
  fi

  # Mutable kindle state — step counters, body indent, step format
  z_buh_step1_n=0
  z_buh_step2_n=0
  z_buh_body_indent=""
  z_buh_step_prefix=""
  z_buh_step_separator=". "

  readonly ZBUH_KINDLED=1
}

zbuh_sentinel() {
  test "${ZBUH_KINDLED:-}" = "1" || { zbuh_kindle; }
}

######################################################################
# Public: Section headers and numbered steps

buh_section() {
  zbuh_sentinel
  z_buh_body_indent=""
  buym_format_yawp "${BUYC_BRIGHT_WHITE}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_formatted}" >&2 || buc_die_now
}
buh_e()       { zbuh_sentinel; echo "" >&2 || buc_die_now; }

buh_step_style() {
  zbuh_sentinel
  z_buh_step_prefix="${1:-}"
  z_buh_step_separator="${2:-". "}"
}

buh_step1() {
  zbuh_sentinel
  z_buh_step1_n=$((z_buh_step1_n + 1))
  z_buh_step2_n=0
  z_buh_body_indent="   "
  buym_format_yawp "${BUYC_BRIGHT_WHITE}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${ZBUH_S}${z_buh_step_prefix}${z_buh_step1_n}${z_buh_step_separator}${z_formatted}" >&2 || buc_die_now
}

buh_step2() {
  zbuh_sentinel
  z_buh_step2_n=$((z_buh_step2_n + 1))
  z_buh_body_indent="      "
  buym_format_yawp "${BUYC_BRIGHT_WHITE}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "   ${ZBUH_S}${z_buh_step_prefix}${z_buh_step1_n}.${z_buh_step2_n}${z_buh_step_separator}${z_formatted}" >&2 || buc_die_now
}

######################################################################
# Public: Hyperlinks
#
# buh_link "prefix text" "link text" "url" "suffix text"
# Renders through the yelp module's one hyperlink decision: an OSC-8 escape
# where the palette renders one, the URL beside the text where it does not.

buh_link() {
  zbuh_sentinel
  local z_prefix="${1:-}"
  local z_text="${2:-}"
  local z_url="${3:-}"
  local z_suffix="${4:-}"

  buym_href_yawp "${z_url}" "${z_text}"; local -r z_href="${z_buym_yelp}"
  buym_format_yawp "${BUYC_RESET}" "${z_prefix}${z_href}${z_suffix}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_buh_body_indent}${z_formatted}" >&2 || buc_die_now
}

######################################################################
# Public: Yelp-aware tabtarget display
#
# buh_tt prefix colophon [imprint] [args]
#   Resolves tabtarget via yawp, displays with prefix.

buh_tt() {
  zbuh_sentinel
  buym_tt_yawp "${2:-}" "${3:-}" "${4:-}"; local -r z_tt="${z_buym_yelp}"
  buh_line "${1:-}${z_tt}"
}

######################################################################
# Public: Pre-composed line output
#
# buh_line string
#   Indent-aware (respects z_buh_body_indent from step context).
#   Designed for lines pre-composed from yelp capture fragments
#   via direct bash variable interpolation:
#     buh_line "A ${RBYC_DEPOT} is where images live."
#   Yelps are pre-rendered (literal ESC bytes) and must not contain %.

buh_line() {
  zbuh_sentinel
  buym_format_yawp "${BUYC_RESET}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_buh_body_indent}${z_formatted}" >&2 || buc_die_now
}

######################################################################
# Public: Semantic line functions
#
# Each routes through buym_format_yawp with a BUYC_* ambient color,
# then prints via indent-aware printf.  Diastema markers in the string
# are resolved to ANSI/OSC-8 at display time.
#
# buh_line   — prose default (BUYC_RESET ambient)
# buh_code   — command/code (BUYC_CYAN ambient)
# buh_warn   — warning (BUYC_BRIGHT_YELLOW ambient)
# buh_error  — error (BUYC_BRIGHT_RED ambient)

buh_code() {
  zbuh_sentinel
  buym_format_yawp "${BUYC_CYAN}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_buh_body_indent}${z_formatted}" >&2 || buc_die_now
}

buh_warn() {
  zbuh_sentinel
  buym_format_yawp "${BUYC_BRIGHT_YELLOW}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_buh_body_indent}${z_formatted}" >&2 || buc_die_now
}

buh_error() {
  zbuh_sentinel
  buym_format_yawp "${BUYC_BRIGHT_RED}" "${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_buh_body_indent}${z_formatted}" >&2 || buc_die_now
}

######################################################################
# Public: Conditional display
#
# buh_ternary condition yelp-string-if-true yelp-string-if-false
#   Displays one of two pre-composed yelp strings based on condition.
#   Condition follows test semantics: "1" is true, anything else is false.

buh_ternary() {
  zbuh_sentinel
  if test "${1:-}" = "1"; then
    buh_line "${2:-}"
  else
    buh_line "${3:-}"
  fi
}

######################################################################
# Public: Critical warnings (box format)

buh_critical() {
  zbuh_sentinel
  printf '\n' >&2 || buc_die_now
  printf '%s\n' "${z_buh_body_indent}${ZBUH_E}===============================================${ZBUH_R}" >&2 || buc_die_now
  printf '%s\n' "${z_buh_body_indent}${ZBUH_E}  CRITICAL: ${1}${ZBUH_R}" >&2 || buc_die_now
  printf '%s\n' "${z_buh_body_indent}${ZBUH_E}===============================================${ZBUH_R}" >&2 || buc_die_now
  printf '\n' >&2 || buc_die_now
}

######################################################################
# Public: Handbook controls
#
# buh_control_«motif» text
#   One renderer per control motif, printing that motif's label at the head
#   of the text it governs: "STOP: text". Indent-aware, as buh_line is. Each
#   renders and nothing more — a fatal control tells the performer to stop,
#   and the track's own drives are what stop it.

zbuh_control() {
  zbuh_sentinel
  buym_format_yawp "${1:-}" "${2:-}: ${3:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_buh_body_indent}${z_formatted}" >&2 || buc_die_now
}

buh_control_fatal() {
  buc_doc_brief "Render the fatal control: the performer stops here"
  buc_doc_param "text" "What the performer must not go past"
  buc_doc_shown || return 0

  zbuh_sentinel
  zbuh_control "${BUYC_BRIGHT_RED}" "${BUH_label_fatal}" "${1:-}"
}

buh_control_warn() {
  buc_doc_brief "Render the warn control: a caution the performer acknowledges"
  buc_doc_param "text" "The caution"
  buc_doc_shown || return 0

  zbuh_sentinel
  zbuh_control "${BUYC_BRIGHT_YELLOW}" "${BUH_label_warn}" "${1:-}"
}

buh_control_stow() {
  buc_doc_brief "Render the control for a value the performer keeps for a later step"
  buc_doc_param "text" "What to keep and where"
  buc_doc_shown || return 0

  zbuh_sentinel
  zbuh_control "${BUYC_CYAN}" "${BUH_label_stow}" "${1:-}"
}

buh_control_require() {
  buc_doc_brief "Render the require control: a condition the performer confirms"
  buc_doc_param "text" "The condition to confirm"
  buc_doc_shown || return 0

  zbuh_sentinel
  zbuh_control "${BUYC_BRIGHT_WHITE}" "${BUH_label_require}" "${1:-}"
}

buh_control_show() {
  buc_doc_brief "Render the show control: teaching text set off from the procedure"
  buc_doc_param "text" "One line of the shown text"
  buc_doc_shown || return 0

  zbuh_sentinel
  zbuh_control "${BUYC_RESET}" "${BUH_label_show}" "${1:-}"
}

######################################################################
# Public: The ending
#
# buh_ending text
#   Closes a track, after its last step: what stands once the performance
#   is done, at the left margin.

buh_ending() {
  buc_doc_brief "Close a track with what stands once the performance is done"
  buc_doc_param "text" "What stands"
  buc_doc_shown || return 0

  zbuh_sentinel
  z_buh_body_indent=""
  buym_pass_yawp " [*] "; local -r z_pass="${z_buym_yelp}"
  buym_format_yawp "${BUYC_BRIGHT_WHITE}" "${z_pass}Done: ${1:-}"; local -r z_formatted="${z_buym_format}"
  printf '%s\n' "${z_formatted}" >&2 || buc_die_now
}

# eof
