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
# BUK Jurisdiction Handbook - Command Line Interface
#
# Thin furnish: handbook display needs only buh_* combinators and the
# buhj module tinder. No regime, no validation stack.

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"

zbuhj_furnish() {
  buc_doc_env "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_done || return 0

  source "${BURD_BUK_DIR}/bubc_constants.sh"     || buc_die "Failed to source bubc_constants.sh"
  source "${BURD_BUK_DIR}/buym_yelp.sh"          || buc_die "Failed to source buym_yelp.sh"
  source "${BURD_BUK_DIR}/buh_handbook.sh"       || buc_die "Failed to source buh_handbook.sh"
  source "${BURD_BUK_DIR}/buz_zipper.sh"         || buc_die "Failed to source buz_zipper.sh"
  source "${BURD_BUK_DIR}/buwz_zipper.sh"        || buc_die "Failed to source buwz_zipper.sh"
  source "${BURD_BUK_DIR}/buhj_jurisdiction.sh"  || buc_die "Failed to source buhj_jurisdiction.sh"

  zbuz_kindle
  zbuwz_kindle
  zbuhj_kindle
}

buc_execute buhj_ "Jurisdiction Handbook" zbuhj_furnish "$@"

# eof
