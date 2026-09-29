#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
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
# JJSL CLI - Command line interface for the JJ operator doors
#
# The gateway alone: the module body it kindles stands beside it in
# jjsl_wicket.sh, which is where the doors themselves are written.

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"
source "${BURD_BUK_DIR}/buym_yelp.sh"

######################################################################
# Furnish and Main

# The lock doors (sight, cashier) sweep an equerry-known roster and take no
# folio, so asserting one for them would open the very report an operator reads
# at their worst moment with a spurious warning.
#
# The two groom doors and the help door join them for a different reason and the
# same remedy: the folio is OPTIONAL on all three, naming none being the estate
# console on the groom doors and the whole family listing on help rather than an
# omission, so a row asserting it would warn on each door's own ordinary path.
# What the row would have taught is carried by the colophon's enrolled
# description instead, which is where an operator meets these doors anyway.
zjjsl_furnish() {
  local -r z_command="${1:-}"

  buc_doc_env_row "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_row "BURD_TOOLS_DIR        " "Project tools root directory (dispatch-provided)"
  buc_doc_env_row "BURD_COLOR            " "Resolved color verdict (dispatch-provided); the abuttal diff forces git's color from it"
  case "${z_command}" in
    jjsl_sight|jjsl_cashier|jjsl_found|jjsl_abuttal|jjsl_ostler|jjsl_drover|jjsl_help) ;;
    # The admission door takes a folio like a dispatch door and means something
    # else by it — the infield clone to admit, never a coronet or firemark to
    # resolve — so it earns a row of its own rather than the generic one, which
    # would name two identity kinds this door refuses.
    jjsl_keuring) buc_doc_env_row "BUZ_FOLIO             " "The infield clone to admit, by dirname; the handle to allot follows as the next argument (param1 channel)" ;;
    # The removal door means a THIRD thing by its folio — a sire handle, neither
    # a clone nor an identity to resolve — so it earns its own row for the same
    # reason the admission above does.
    jjsl_turnout) buc_doc_env_row "BUZ_FOLIO             " "The handle of the sire to strike; no tree is read, so this is the door's only value (param1 channel)" ;;
    *) buc_doc_env_row "BUZ_FOLIO             " "Dispatch target: a coronet or firemark (param1 channel)" ;;
  esac
  buc_doc_env_done || return 0

  local -r z_jjk_dir="${BURD_TOOLS_DIR}/jjk"

  source "${z_jjk_dir}/jjsl_wicket.sh"

  # The studbook neutrality gate the working doors carry, in its own module so a
  # test can source it against a scratch store without this dispatcher running
  # (see its header).
  source "${z_jjk_dir}/jjsl_perch.sh"

  # The station date gate beside it, in its own module for the same reason and
  # driven the same way (see its header).
  source "${z_jjk_dir}/jjsl_gnomon.sh"

  # Every door kindles the zipper, unconditionally. A hand-kept subset was
  # tried here once and cost the founding door's own no-argument refusal: its
  # JJZ_DISPATCH_HELP citation named the help door only where the list
  # remembered to include it, and it didn't, so the refusal died unbound
  # instead of naming the help door. A door earns its way onto the wicket's
  # refusal paths without ever earning a line in a list kept here, so the list
  # drifts behind the doors it was meant to cover. What kindling costs is
  # sourcing two small files and a few dozen array appends — noise beside the
  # process this command already pays to start — so nothing is bought by
  # excluding the two doors (sight, cashier) that happen not to need it.
  source "${BURD_BUK_DIR}/buz_zipper.sh"
  source "${z_jjk_dir}/jjz_zipper.sh"
  zbuz_kindle
  zjjz_kindle

  zjjsl_kindle
}

buc_execute jjsl_ "JJ Operator Doors" zjjsl_furnish "$@"

# eof
