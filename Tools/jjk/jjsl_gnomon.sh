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
# JJSL Gnomon - the station date gate, dispatch-side and single-seated.
#
# A gnomon is the pin whose shadow encodes LOCAL time, and that is the property
# this proves: not which clock the station keeps, but whether the time it prints
# carries the reader's own zone. The equerry's own renders are zone-explicit, so
# the one surface log.date governs is the `git log` an operator or a session runs
# by hand in a billet - and a session reading a zone it does not know reports a
# time the operator cannot trust, with nothing in the reading saying so.
#
# ONE SEAT, unlike the neutrality gate beside it: the condition is static and
# does not drift mid-session, and the threshold is the one moment the station is
# judged at all, where a refusal has spent nothing. A second seat, if ever
# wanted, is a monitum and never an interdictum - barring every door over a
# display preference would strand a session for nothing.
#
# NO ARMING PIN, and that too parts it from the perch: there is no ref to cut, so
# it is live from the moment it lands. The refusal names the one-line remedy for
# exactly that reason.
#
# Its refusal carries the threshold genre's token (JJS0 jjdz_denegatio; the
# design is JJSVD-dispatch.adoc jjdd_gnomon).
#
# It carries no BUZ_FOLIO, reads no cwd, and takes a repository root as its
# argument - so a test drives it against a scratch station by sourcing this file
# beside buc_command.sh and nothing else.

set -euo pipefail

# Multiple inclusion detection
test -z "${ZJJSL_GNOMON_SOURCED:-}" || buc_die_now "Module jjsl_gnomon multiply sourced - check sourcing hierarchy"
ZJJSL_GNOMON_SOURCED=1

# The surface forms of the governed words this gate refuses in. IT IS SOURCED
# HERE, in the module that cites it, and not left to the dispatcher: this file is
# driven directly by a test that sources it against a scratch store with the
# dispatcher never running, which is the property its header advertises, and a
# citation resolved only through the dispatcher would die `unbound variable`
# under `set -u` on exactly that path. The breviary carries its own guard, so
# every sibling gate sourcing it too costs nothing.
source "${BASH_SOURCE[0]%/*}/jjsb_breviary.sh"

# The value the remedy names. The gate tests the PROPERTY and not this spelling -
# the whole -local family satisfies it - so this is the recommendation an operator
# is handed, never the requirement the predicate enforces.
zjjsl_gnomon_recommended="iso-local"

# The gate: die unless the log.date a freshly minted billet would resolve from
# this STATION carries the reader's own timezone.
#
# IT ASKS GIT AND NEVER READS A FILE. Where a global config lives is per-platform
# and per-environment (XDG, GIT_CONFIG_GLOBAL, the Windows and macOS system
# files), and its value composes through includes git alone resolves - so on an
# estate that runs on many platform types, git is the only thing that can answer
# what this station actually resolves.
#
# STATION SCOPES ONLY - system, global and command. Local and worktree are
# ignored deliberately: a billet is a worktree sharing its clone's local scope,
# which is that clone's own configuration and not the station's, so a local
# override neither satisfies this gate nor fails it.
#
# AN UNSET KEY IS THE ORDINARY REFUSAL. git exits 1 with no value, which is an
# answer and not a tool failure; anything above 1 is the machine giving way and
# dies as one.
jjsl_gnomon_gate() {
  local -r z_root="${1}"

  # Scope, origin and value in one read: the scope decides whether the line is
  # the station's, and the origin is what lets the refusal name the file a
  # remedy would edit when a bad value is already set somewhere.
  local z_lines=""
  local z_status=0
  z_lines=$(git -C "${z_root}" config --show-scope --show-origin --get-all log.date 2>/dev/null) || z_status=$?

  test "${z_status}" -le 1 \
    || buc_die_now "jjsl ${JJSB_GNOMON_BASE}: cannot read log.date at ${z_root} - git config exited ${z_status}"

  # git lists in order of increasing precedence, so the LAST station line is the
  # one that wins. Split on the first two tabs only: a format: value may carry
  # tabs of its own, and everything past the origin is the value.
  local z_value=""
  local z_scope=""
  local z_origin=""
  local z_line=""
  local z_rest=""
  while IFS= read -r z_line; do
    test -n "${z_line}" || continue
    z_scope="${z_line%%$'\t'*}"
    case "${z_scope}" in
      system|global|command) ;;
      *) continue ;;
    esac
    z_rest="${z_line#*$'\t'}"
    z_origin="${z_rest%%$'\t'*}"
    z_value="${z_rest#*$'\t'}"
  done <<< "${z_lines}"

  # The property, not a spelling. `local` alone and every -local suffix carry the
  # reader's zone; relative and human are timezone-safe and deliberately outside
  # the predicate, so a refusal against one is the signal to widen, not a defect.
  case "${z_value}" in
    local|*-local) return 0 ;;
  esac

  local z_found="is unset on this station"
  test -z "${z_value}" \
    || z_found="resolves to '${z_value}' at ${z_scope} scope (${z_origin})"

  # The remedy is the literal command and never the abuttal door: that door
  # emplaces canon and could not write this setting. The global config is
  # hand-maintained ground carrying identity, aliases and credential helpers, and
  # the estate has no claim to be its writer - so this gate detects and never
  # writes.
  buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the station date gate: log.date ${z_found}, so it carries no timezone. (JJr_qd0)" \
          "A git log run by hand in a billet would report a time whose zone its reader cannot know," \
          "and the ${JJSB_EQUERRY_POSSESSIVE} own renders are zone-explicit, so that reading is the one surface this governs." \
          "The whole -local family satisfies this gate; ${zjjsl_gnomon_recommended} is the recommendation, not the requirement." \
          "Remedy: git config --global log.date ${zjjsl_gnomon_recommended}"
}

# eof
