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
# BURS Template - single-home data for the BURS station file's required
# fields. Read by both tt/buw-SI.StationInit.sh (bootstrap writer, no BUK
# modules available) and Tools/buk/bul_launcher.sh (guided SETUP NEEDED
# display) so the two paths cannot drift. Pure data, no sourcing guard —
# safe to source from either bootstrap or fully-kindled contexts, more than
# once if needed.
#
# Field order is the write/display order. Three parallel arrays, indexed
# together: name, default value, one-line purpose comment.

ZBURS_TEMPLATE_NAMES=(
  "BURS_LOG_DIR"
  "BURS_USER"
  "BURS_TINCTURE"
)

ZBURS_TEMPLATE_VALUES=(
  "../logs-buk"
  "<your-username>"
  "a"
)

ZBURS_TEMPLATE_COMMENTS=(
  "Directory for BUK operation logs. All tabtargets run from the project root, so relative paths resolve from there."
  "Local developer username (1-32 chars). Per-user profile lookups under the moorings users directory key on this name."
  "1-3 char tag (lowercase alphanumeric, leading letter, no hyphen). Use 'a' until you have a reason to change it; downstream tooling may compose it into per-station resource names so concurrent stations sharing an upstream account stay disjoint."
)

# eof
