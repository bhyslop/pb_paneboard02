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
# BUG Git - bash git utilities (BUK domain)
#
# Home for the "tools never commit, but gate on a clean tree" convention: a tool
# may presume git and refuse downstream steps on a dirty tree, but never commits
# in the consumer's codebase. Bash-only — Rust git use is outside BUK framing.

set -euo pipefail

# Multiple inclusion guard
test -z "${ZBUG_SOURCED:-}" || buc_die "Module bug multiply sourced - check sourcing hierarchy"
ZBUG_SOURCED=1

# Refuse to proceed unless the git working tree is clean — no unstaged and no
# staged changes (untracked files are not gated, matching the prior per-verb
# guards). The caller names the gated operation; it is surfaced in the failure
# message so the operator knows what to commit before.
# Args: <operation-context>
bug_require_clean_tree() {
  local -r z_context="${1:-}"
  test -n "${z_context}" || buc_die "bug_require_clean_tree: operation context required"

  buc_step "Verifying clean working tree"
  git diff --quiet \
    || buc_die "Working tree has unstaged changes — commit before ${z_context}"
  git diff --cached --quiet \
    || buc_die "Index has staged changes — commit before ${z_context}"
}

# eof
