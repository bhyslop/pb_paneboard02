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
# BUG Git - bash git utilities (BUK domain)
#
# The bash arm of rivet BUr_k7d: tooling never stages or commits in a repository
# it does not own. The rivet is dialect-neutral and binds every tool alike, so
# this module is where bash meets it rather than where the rule is stated. The
# clean-tree gate below is that rivet's ergonomic backstop, never its safety
# mechanism — the caller's seal is.

set -euo pipefail

# The gate codes this module rejects with, from the substrate's generated
# constants, sourced above the inclusion guard so the tinder block stays the run
# behind it. The sourced file carries its own inclusion guard, so a sibling
# sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"

# Multiple inclusion guard
test -z "${ZBUG_SOURCED:-}" || buc_die_now "Module bug multiply sourced - check sourcing hierarchy"
ZBUG_SOURCED=1

# Tinder constant (pure string literal — available at source time). The detailed
# clean-tree error condition, carried as a structured constant rather than an
# inline free string, so the well-formed gate below states one canonical grievance.
# Untracked files are not gated, so the condition names staged-or-unstaged only.
readonly BUG_clean_tree_condition="git working tree carries uncommitted changes (staged or unstaged)"

# Tinder constant, sibling to the clean-tree condition above: the branch-synchrony
# grievance, stated once so every rule of that gate opens with the same sentence.
# The condition names publication, not direction — behind, ahead, diverged, and
# never-published all fail the same requirement, and the gate's message supplies
# which one.
readonly BUG_synchrony_condition="git branch does not stand at its published upstream tip"

# Tinder constant, third of the family: the linked-worktree grievance. The
# condition names the tree the operation was entered from, and the gate's message
# supplies where the main checkout stands.
readonly BUG_worktree_condition="git working tree is a linked worktree, not the main checkout"

# Clean-tree gate — the sole clean-tree guard (a deliberate-rejection gate):
# it buc_rejects the named clean-tree band
# rather than dying imprecisely, and states the error condition from the
# BUG_clean_tree_condition constant. BUG holds no opinion on WHY a clean tree
# matters — the caller supplies its rationale as a creed, appended to the
# condition, so the opinion stays kit-side and BUG stays kit-agnostic. Untracked
# files are not gated (staged/unstaged only).
# Args: <creed>  (the caller's rationale for demanding a clean tree)
bug_require_clean_tree_creed() {
  local -r z_creed="${1:-}"
  test -n "${z_creed}" || buc_die_now "bug_require_clean_tree_creed: creed (rationale) required"

  buc_step "Verifying clean working tree"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    buc_reject "${BUBG_CLEAN_DENTIL}" "${BUG_clean_tree_condition} — ${z_creed}"
  fi
}

# Branch-synchrony gate — the second deliberate-rejection gate,
# independent of the clean-tree gate above and never implied by
# it: a clean working tree says only that nothing is uncommitted, and says
# nothing about whether the commits already made have reached the remote. An
# operation that writes into a branch other clones read crosses both.
#
# The remote tip is fetched AT THE GATE and read from FETCH_HEAD. A
# remote-tracking ref carries whatever the last fetch left there, so comparing
# against it returns a false green exactly when the branch has moved elsewhere —
# the case the gate exists to catch. FETCH_HEAD is written by this fetch alone
# and consults no tracking-ref configuration.
#
# A detached HEAD, an unconfigured upstream, a remote that carries no such
# branch, and a tip mismatch are four rules of this one gate rather than four
# gates (allocation rule: one code per gate, never per rule). Each is the
# condition stated. BUG holds no opinion on WHY
# synchrony matters — the caller supplies its rationale as a creed, appended to
# the condition, so the opinion stays kit-side and BUG stays kit-agnostic.
# Args: <creed>  (the caller's rationale for demanding branch synchrony)
bug_require_branch_synchrony_creed() {
  local -r z_creed="${1:-}"
  test -n "${z_creed}" || buc_die_now "bug_require_branch_synchrony_creed: creed (rationale) required"

  buc_step "Verifying branch stands at its published upstream tip"

  local z_branch=""
  z_branch=$(git rev-parse --abbrev-ref HEAD) || buc_die_now "Failed to resolve current branch"
  test "${z_branch}" != "HEAD" \
    || buc_reject "${BUBG_SYNCHRONY_DENTIL}" "${BUG_synchrony_condition}: HEAD is detached, so no branch is published — ${z_creed}"

  local z_remote=""
  local z_remote_status=0
  z_remote=$(git config --get "branch.${z_branch}.remote") || z_remote_status=$?
  test "${z_remote_status}" -eq 0 \
    || buc_reject "${BUBG_SYNCHRONY_DENTIL}" "${BUG_synchrony_condition}: branch '${z_branch}' has no configured remote, so nothing on it is published — ${z_creed}"

  local z_upstream_ref=""
  local z_upstream_ref_status=0
  z_upstream_ref=$(git config --get "branch.${z_branch}.merge") || z_upstream_ref_status=$?
  test "${z_upstream_ref_status}" -eq 0 \
    || buc_reject "${BUBG_SYNCHRONY_DENTIL}" "${BUG_synchrony_condition}: branch '${z_branch}' has no configured upstream ref, so nothing on it is published — ${z_creed}"

  local z_upstream_name="${z_remote}/${z_upstream_ref#refs/heads/}"

  buc_log_args "Branch:   ${z_branch}"
  buc_log_args "Upstream: ${z_upstream_name}"

  local z_fetch_status=0
  git fetch "${z_remote}" "${z_upstream_ref}" || z_fetch_status=$?

  # A branch the remote does not carry and an unreachable remote both fail the
  # fetch, and they are not the same finding: the first has published nothing,
  # which is this gate's own condition, while the second leaves the question
  # unanswered and is imprecise death. Upstream config is set locally and proves
  # nothing about the remote — a branch pushed by no one still carries it. The
  # two are separated by ls-remote's exit status (2 = no matching ref) rather
  # than by reading the fetch's wording, which an innocuous message edit breaks.
  if test "${z_fetch_status}" -ne 0; then
    local z_probe_status=0
    git ls-remote --exit-code "${z_remote}" "${z_upstream_ref}" > /dev/null || z_probe_status=$?
    test "${z_probe_status}" -ne 0 \
      || buc_die_now "Failed to fetch ${z_upstream_name} though the remote carries it (fetch exit ${z_fetch_status})"
    test "${z_probe_status}" -eq 2 \
      || buc_die_now "Failed to reach ${z_remote} to resolve ${z_upstream_name} (fetch exit ${z_fetch_status}, ls-remote exit ${z_probe_status})"
    buc_reject "${BUBG_SYNCHRONY_DENTIL}" "${BUG_synchrony_condition}: the remote carries no ${z_upstream_name}, so branch '${z_branch}' has published nothing — ${z_creed}"
  fi

  local z_local_tip=""
  z_local_tip=$(git rev-parse HEAD) || buc_die_now "Failed to read local tip"

  local z_remote_tip=""
  z_remote_tip=$(git rev-parse FETCH_HEAD) || buc_die_now "Failed to read fetched tip of ${z_upstream_name}"

  buc_log_args "Local tip:   ${z_local_tip}"
  buc_log_args "Fetched tip: ${z_remote_tip}"

  test "${z_local_tip}" != "${z_remote_tip}" || return 0

  # Name the relation, because the operator's remedy differs by direction:
  # behind wants a pull, ahead wants a push, diverged wants a reconciliation.
  local z_relation="diverged from"
  if git merge-base --is-ancestor "${z_remote_tip}" "${z_local_tip}"; then
    z_relation="ahead of"
  elif git merge-base --is-ancestor "${z_local_tip}" "${z_remote_tip}"; then
    z_relation="behind"
  fi

  buc_reject "${BUBG_SYNCHRONY_DENTIL}" \
    "${BUG_synchrony_condition}: '${z_branch}' is ${z_relation} ${z_upstream_name} (local ${z_local_tip}, fetched ${z_remote_tip}) — ${z_creed}"
}

# Linked-worktree gate — the third deliberate-rejection gate, independent of the
# clean-tree and branch-synchrony gates above. An operation that allocates a
# resource shared across every clone (a release number, a serial) and is entered from a
# linked worktree allocates against a branch its sibling worktrees never see, so
# two of them hand out the same value and the collision surfaces only later, as
# a merge conflict on the file that recorded it.
#
# The reading is git's own: the repository's git directory and its common
# directory are one directory at a main checkout and part at a linked worktree,
# where the git directory stands beneath the common directory's `worktrees`
# directory. The main checkout is the parent of the common directory, which is
# what the refusal names. BUG holds no opinion on WHY the operation belongs at
# the main checkout — the caller supplies its rationale as a creed, appended to
# the condition, so the opinion stays kit-side and BUG stays kit-agnostic.
# Args: <creed>  (the caller's rationale for demanding the main checkout)
bug_require_main_worktree_creed() {
  buc_doc_brief "Refuse an operation entered from a linked worktree, naming the main worktree and the caller's creed"
  buc_doc_param "creed" "The caller's rationale for demanding the main worktree"
  buc_doc_shown || return 0

  local -r z_creed="${1:-}"
  test -n "${z_creed}" || buc_die_now "bug_require_main_worktree_creed: creed (rationale) required"

  buc_step "Verifying the operation is entered from the main checkout"

  local z_git_dir=""
  z_git_dir=$(git rev-parse --path-format=absolute --git-dir) || buc_die_now "Failed to resolve the git directory"
  local z_common_dir=""
  z_common_dir=$(git rev-parse --path-format=absolute --git-common-dir) || buc_die_now "Failed to resolve the git common directory"

  test "${z_git_dir}" != "${z_common_dir}" || return 0

  buc_reject "${BUBG_WORKTREE_DENTIL}" "${BUG_worktree_condition}: this tree is a linked worktree of the main checkout at ${z_common_dir%/*} — ${z_creed}"
}

# eof
