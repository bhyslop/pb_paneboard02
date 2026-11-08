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
# VVZ Zipper - Colophon registry for the VVK workbench
#
# Dispatch-only (no buz_tome_seat): nothing projects these colophons as consts.
#
# THE RUN DOORS TAKE THE PASSTHROUGH CHANNEL. Each hands its arguments to the
# engine binary untouched, so neither may lose an empty argument, split a spaced
# one, or take the first as a folio — which the three older channels would each
# do to one of them.

set -euo pipefail

# Multiple inclusion guard
test -z "${ZVVZ_SOURCED:-}" || buc_die_now "Module vvz multiply sourced - check sourcing hierarchy"
ZVVZ_SOURCED=1

######################################################################
# Colophon registry initialization

zvvz_kindle() {
  test -z "${ZVVZ_KINDLED:-}" || buc_die_now "vvz already kindled"

  # Verify buz zipper is kindled (workbench kindles buz first)
  zbuz_sentinel

  local z_mod="vvb_cli.sh"
  buz_group VVZ__GROUP_ENGINE "vvw-" "The engine binary: run it and probe the model tiers"

  buz_enroll VVZ_RUN          "vvw-r"  "${z_mod}" "vvb_run"          "buz_passthrough" "Run the engine binary, every argument handed to it as typed"
  buz_enroll VVZ_MODEL_PROBE  "vvw-mp" "${z_mod}" "vvb_model_probe"  "buz_passthrough" "Probe the four model tiers from this station, on demand"

  readonly ZVVZ_KINDLED=1
}

######################################################################
# Internal sentinel

zvvz_sentinel() {
  test "${ZVVZ_KINDLED:-}" = "1" || buc_die_now "Module vvz not kindled - call zvvz_kindle first"
}

# eof
