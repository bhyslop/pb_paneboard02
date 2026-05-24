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
# JJZ Zipper - Colophon registry for JJK workbench dispatch

set -euo pipefail

# Multiple inclusion guard
test -z "${ZJJZ_SOURCED:-}" || return 0
ZJJZ_SOURCED=1

######################################################################
# Colophon registry initialization

zjjz_kindle() {
  test -z "${ZJJZ_KINDLED:-}" || buc_die "jjz already kindled"

  # Verify buz zipper is kindled
  zbuz_sentinel

  # Fundus — test account and scenario infrastructure (jjw-tf)
  buz_group JJZ__GROUP_FUNDUS   "jjw-tf"  "Fundus — Test account and scenario infrastructure"
  buz_enroll JJZ_FUNDUS_PHASE1    "jjw-tfP1" "jjfp_cli.sh" "jjfp_provision" ""        "Phase 1: Create accounts and install keypairs (requires root)"
  buz_enroll JJZ_FUNDUS_PHASE2    "jjw-tfP2" "jjfp_cli.sh" "jjfp_repo"      "imprint" "Phase 2: Clone repos and install BUK via SSH"
  buz_enroll JJZ_FUNDUS_SCENARIO  "jjw-tfs"  "jjfp_cli.sh" "jjfp_scenario"  "imprint" "Run fundus scenario suite"
  buz_enroll JJZ_FUNDUS_SINGLE    "jjw-tfS"  "jjfp_cli.sh" "jjfp_single"    "imprint" "Run single fundus test"

  readonly ZJJZ_KINDLED=1
}

######################################################################
# Healthcheck (validates all enrolled tabtargets exist on disk)

zjjz_healthcheck() {
  zjjz_sentinel
  buz_healthcheck
}

######################################################################
# Internal sentinel

zjjz_sentinel() {
  test "${ZJJZ_KINDLED:-}" = "1" || buc_die "Module jjz not kindled - call zjjz_kindle first"
}

# eof
