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
# BUW Zipper - Colophon registry for BUK workbench dispatch

set -euo pipefail

# Multiple inclusion guard
test -z "${ZBUWZ_SOURCED:-}" || return 0
ZBUWZ_SOURCED=1

######################################################################
# Colophon registry initialization

zbuwz_kindle() {
  test -z "${ZBUWZ_KINDLED:-}" || buc_die "buwz already kindled"

  # Verify buz zipper is kindled (CLI furnish must kindle buz first)
  zbuz_sentinel

  # TabTarget subsystem (buut_cli.sh)
  local z_mod="buut_cli.sh"
  buz_enroll BUWZ_TT_LIST_LAUNCHERS      "buw-tt-ll"  "${z_mod}" "buut_list_launchers"               ""  "List all registered launchers"
  buz_enroll BUWZ_TT_BATCH_LOGGING       "buw-tt-cbl" "${z_mod}" "buut_tabtarget_batch_logging"      ""  "Create batch tabtarget with logging"
  buz_enroll BUWZ_TT_BATCH_NOLOG         "buw-tt-cbn" "${z_mod}" "buut_tabtarget_batch_nolog"        ""  "Create batch tabtarget without logging"
  buz_enroll BUWZ_TT_INTERACTIVE_LOGGING "buw-tt-cil" "${z_mod}" "buut_tabtarget_interactive_logging" ""  "Create interactive tabtarget with logging"
  buz_enroll BUWZ_TT_INTERACTIVE_NOLOG   "buw-tt-cin" "${z_mod}" "buut_tabtarget_interactive_nolog"  ""  "Create interactive tabtarget without logging"
  buz_enroll BUWZ_TT_LAUNCHER            "buw-tt-cl"  "${z_mod}" "buut_launcher"                     ""  "Create launcher script"

  # Config Regime subsystem (burc_cli.sh)
  z_mod="burc_cli.sh"
  buz_enroll BUWZ_RC_VALIDATE "buw-rcv" "${z_mod}" "burc_validate"  ""  "Validate BURC regime"
  buz_enroll BUWZ_RC_RENDER   "buw-rcr" "${z_mod}" "burc_render"    ""  "Render BURC regime"

  # Station Regime subsystem (burs_cli.sh)
  z_mod="burs_cli.sh"
  buz_enroll BUWZ_RS_VALIDATE "buw-rsv" "${z_mod}" "burs_validate"  ""  "Validate BURS regime"
  buz_enroll BUWZ_RS_RENDER   "buw-rsr" "${z_mod}" "burs_render"    ""  "Render BURS regime"

  # Environment Regime subsystem (bure_cli.sh)
  z_mod="bure_cli.sh"
  buz_enroll BUWZ_RE_VALIDATE "buw-rev" "${z_mod}" "bure_validate"  ""  "Validate BURE regime"
  buz_enroll BUWZ_RE_RENDER   "buw-rer" "${z_mod}" "bure_render"    ""  "Render BURE regime"

  # Node Regime subsystem (burn_cli.sh)
  z_mod="burn_cli.sh"
  buz_enroll BUWZ_RN_VALIDATE "buw-rnv" "${z_mod}" "burn_validate" "param1" "Validate BURN profile"
  buz_enroll BUWZ_RN_RENDER   "buw-rnr" "${z_mod}" "burn_render"   "param1" "Render BURN profile"
  buz_enroll BUWZ_RN_LIST     "buw-rnl" "${z_mod}" "burn_list"     ""       "List BURN profiles"

  # Privileged Regime subsystem (burp_cli.sh)
  z_mod="burp_cli.sh"
  buz_enroll BUWZ_RP_VALIDATE "buw-rpv" "${z_mod}" "burp_validate" "param1" "Validate BURP profile"
  buz_enroll BUWZ_RP_RENDER   "buw-rpr" "${z_mod}" "burp_render"   "param1" "Render BURP profile"
  buz_enroll BUWZ_RP_LIST     "buw-rpl" "${z_mod}" "burp_list"     ""       "List BURP profiles"

  # Qualification subsystem (buq_cli.sh)
  z_mod="buq_cli.sh"
  buz_enroll BUWZ_QUALIFY_SHELLCHECK "buw-qsc" "${z_mod}" "buq_shellcheck"  ""  "Run shellcheck on all tools"

  # Test fixtures (bux_cli.sh)
  z_mod="bux_cli.sh"
  buz_enroll BUWZ_DELAY "buw-xd" "${z_mod}" "bux_delay"  ""  "Sleep 20 seconds (timing fixture)"

  # Self-test (butt_testbench.sh)
  z_mod="butt_testbench.sh"
  buz_enroll BUWZ_SELF_TEST "buw-st" "${z_mod}" "buw-st"  ""  "BUK self-test (kick-tires + bure-tweak)"

  # Handbook — jurisdiction (buhj_cli.sh)
  z_mod="buhj_cli.sh"
  buz_enroll BUWZ_HJ0_TOP           "buw-hj0"   "${z_mod}" "buhj_top"                ""        "Jurisdiction handbook landing + tabtarget catalog (top level)"
  buz_enroll BUWZ_HJW_WINDOWS       "buw-hjw"   "${z_mod}" "buhj_windows"            ""        "Windows first-time host setup (Tailscale autonomy + sshd reachability)"
  buz_enroll BUWZ_HJM_MACOS         "buw-hjm"   "${z_mod}" "buhj_macos"              ""        "macOS first-time host setup (Tailscale install + login, ssh-copy-id admin trust)"
  buz_enroll BUWZ_HJL_LINUX         "buw-hjl"   "${z_mod}" "buhj_linux"              ""        "Linux first-time host setup (Tailscale, sshd on minimal distros, ssh-copy-id admin trust)"

  # Jurisdiction operational — workload ceremonies (bujb_cli.sh)
  z_mod="bujb_cli.sh"
  buz_enroll BUWZ_JW_KNOCK          "buw-jwk"   "${z_mod}" "bujb_knock"               "param1"  "Knock — probe workload SSH reachability"
  buz_enroll BUWZ_JW_COMMAND_FILE   "buw-jwc"   "${z_mod}" "bujb_command_file"        "param1"  "Run command file as workload, capture outputs"
  buz_enroll BUWZ_JW_INTERACTIVE    "buw-jws"   "${z_mod}" "bujb_interactive_session" "param1"  "Interactive SSH session as workload"

  # Jurisdiction operational — caparison ceremonies (bujb_cli.sh)
  buz_enroll BUWZ_JP_CAPARISON_WIN    "buw-jpCW"  "${z_mod}" "bujb_caparison_windows_command" "param1"  "Caparison — admin host posture (admin SSH trust, sshd harden, WSL stage, sleep disable, Tailscale auto-start) on a bunne_windows node"
  buz_enroll BUWZ_JP_CAPARISON_MAC    "buw-jpCM"  "${z_mod}" "bujb_caparison_macos_command"   "param1"  "Caparison — admin host posture (Remote Login, pmset, tailscaled) on a bunne_mac node"
  buz_enroll BUWZ_JP_CAPARISON_LIN    "buw-jpCL"  "${z_mod}" "bujb_caparison_linux_command"   "param1"  "Caparison — admin host posture (sshd, sleep mask, tailscaled) on a bunne_linux node"

  # Jurisdiction operational — privileged SSH pass-through (bujb_cli.sh)
  buz_enroll BUWZ_JP_PRIVILEGED_SSH   "buw-jpS"   "${z_mod}" "bujb_privileged_ssh_command" "param1"  "Privileged SSH — run a command on a node as BURP_PRIVILEGED_USER"

  # Jurisdiction operational — garrison ceremonies (bujb_cli.sh)
  buz_enroll BUWZ_JP_GARRISON_BASH    "buw-jpGb"  "${z_mod}" "bujb_garrison_bash"     "param1"  "Garrison workload (shell-letter b: native bash, Linux/Mac)"
  buz_enroll BUWZ_JP_GARRISON_CYGWIN  "buw-jpGc"  "${z_mod}" "bujb_garrison_cygwin"   "param1"  "Garrison workload (shell-letter c: Cygwin bash, Windows)"
  buz_enroll BUWZ_JP_GARRISON_WSL     "buw-jpGw"  "${z_mod}" "bujb_garrison_wsl"      "param1"  "Garrison workload (shell-letter w: WSL bash, Windows)"

  readonly ZBUWZ_KINDLED=1
}

######################################################################
# Healthcheck (validates all enrolled tabtargets exist on disk)

zbuwz_healthcheck() {
  zbuwz_sentinel
  buz_healthcheck
}

######################################################################
# Internal sentinel

zbuwz_sentinel() {
  test "${ZBUWZ_KINDLED:-}" = "1" || buc_die "Module buwz not kindled - call zbuwz_kindle first"
}

# eof
