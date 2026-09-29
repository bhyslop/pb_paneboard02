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
# JJSL Perch - the studbook neutrality gate, dispatch-side seat.
#
# The predicate has two seats and this is the shell one: the dispatch preflight
# saddle and lunge share, so a kraal is refused before it exists. The equerry
# carries the other, at the one entry every jjx command passes
# (jjdb_perch_gate, vov_veiled/jjk/src/jjr0/jjrvb_blotter.rs) — that seat cannot
# reach this moment, because dispatch never enters the command surface, which
# is why the predicate is stated twice rather than called once. Both name the
# same findings and the same remedy, and differ only in genre: the equerry's
# rides an INTERDICTUM token and breaks its remedy onto its own line, this one
# carries the threshold genre's token at the operator's terminal (JJS0
# jjdz_denegatio, whose instance census names this seat its type specimen).
#
# It carries no BUZ_FOLIO, reads no cwd, and takes the clone's root as its
# argument — so a test drives it against a scratch store by sourcing this file
# beside buc_command.sh and nothing else.

set -euo pipefail

# Multiple inclusion detection
test -z "${ZJJSL_PERCH_SOURCED:-}" || buc_die_now "Module jjsl_perch multiply sourced - check sourcing hierarchy"
ZJJSL_PERCH_SOURCED=1

# The surface forms of the governed words this gate refuses in. IT IS SOURCED
# HERE, in the module that cites it, and not left to the dispatcher: this file is
# driven directly by a test that sources it against a scratch store with the
# dispatcher never running, which is the property its header advertises, and a
# citation resolved only through the dispatcher would die `unbound variable`
# under `set -u` on exactly that path. The breviary carries its own guard, so
# every sibling gate sourcing it too costs nothing.
source "${BASH_SOURCE[0]%/*}/jjsb_breviary.sh"

# The branch a dark studbook clone rests on. Bash face of the equerry's
# JJDB_PERCH_BRANCH (vov_veiled/jjk/src/jjr0/jjrvb_blotter.rs), which carries the
# doctrine; this is the same string, not a second decision.
zjjsl_perch_branch="perch"

# How many dirty paths a refusal names before it stops counting. Bash face of
# the equerry's ZJJDB_PERCH_DIRT_SHOWN, and for the same reason: an operator
# about to go inspect the tree is served by the first handful plus a count,
# never by a hundred lines to scroll.
zjjsl_perch_dirt_shown=10

# The gate: die unless the studbook clone at ${1} is at rest — HEAD attached to
# the perch, and nothing dirty or untracked.
#
# DORMANT WITHOUT THE PIN. The perch ref's existence is the arming pin: absent
# it — which is every store today, and every store that is not a studbook at
# all — this checks nothing and refuses nothing, so the gate lands ahead of the
# darkness it enforces and goes live in the same act that cuts the ref.
#
# JUDGES THE CLONE'S OWN TREE ONLY. The worktrees hanging off it — every
# vulgate billet — are legitimately non-neutral by design, and `git -C <clone>
# status` cannot see them, so the scoping is git's rather than a filter this
# has to get right.
#
# JJ NEVER CLEANS THE STORE. The remedy is operator ceremony, and the refusal
# says so.
jjsl_perch_gate() {
  local -r z_root="${1}"
  local -r z_ref="refs/heads/${zjjsl_perch_branch}"

  # The arming pin, and the one read a dormant store pays. A non-zero exit is
  # the ordinary answer here — the ref is absent — rather than a failure.
  git -C "${z_root}" show-ref --verify --quiet "${z_ref}" || return 0

  local z_findings=""

  # Where HEAD stands. A detached HEAD fails symbolic-ref rather than naming
  # some other branch, so it is its own finding: the operator has to hear
  # "detached", not a bare sha.
  local z_head=""
  if z_head=$(git -C "${z_root}" symbolic-ref --quiet HEAD); then
    test "${z_head}" = "${z_ref}" \
      || z_findings="it stands on ${z_head} rather than the perch (${z_ref})"
  else
    z_findings="its HEAD is detached rather than attached to the perch (${z_ref})"
  fi

  local z_dirt=""
  z_dirt=$(git -C "${z_root}" status --porcelain) \
    || buc_die_now "jjsl perch: cannot read the working tree of the studbook at ${z_root}"

  if test -n "${z_dirt}"; then
    # Porcelain v1, line-oriented: each line is "XY <path>", so the first three
    # characters come off — what the operator needs is which paths to go look
    # at. Split and joined in bash rather than through a text-tool pipeline: a
    # path may carry any character a delimiter would, the comma this joins on
    # included.
    local -a z_lines=()
    local z_line=""
    while IFS= read -r z_line; do
      test -z "${z_line}" || z_lines+=("${z_line}")
    done <<< "${z_dirt}"

    local -r z_count="${#z_lines[@]}"
    local z_shown=""
    local z_i=0
    while test "${z_i}" -lt "${z_count}" && test "${z_i}" -lt "${zjjsl_perch_dirt_shown}"; do
      z_shown="${z_shown}${z_shown:+, }${z_lines[z_i]:3}"
      z_i=$((z_i + 1))
    done

    local z_tail=""
    test "${z_count}" -le "${zjjsl_perch_dirt_shown}" \
      || z_tail=" (and $((z_count - zjjsl_perch_dirt_shown)) more)"

    local -r z_dirty_finding="it is dirty: ${z_shown}${z_tail}"
    if test -n "${z_findings}"; then
      z_findings="${z_findings}; and ${z_dirty_finding}"
    else
      z_findings="${z_dirty_finding}"
    fi
  fi

  test -n "${z_findings}" || return 0

  buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the neutrality gate: the studbook at ${z_root} is not at rest - ${z_findings}. (JJr_58n)" \
          "Remedy: JJ never cleans the store itself." \
          "Inspect the tree, land any strays through a vulgate billet or discard them on your own word," \
          "then return the clone to the perch (${zjjsl_perch_branch})."
}

# eof
