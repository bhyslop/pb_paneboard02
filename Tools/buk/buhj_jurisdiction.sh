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
# Bash Utility Handbook - Jurisdiction Procedures
#
# Handbook content for BUK's remote-node feature area (BUS0 §Remote
# Node Access). On Windows, caparison-windows handles first-run admin
# trust establishment and sshd_config hardening (password-fallback on
# /dev/tty during its phase-1 admin session, then key-only
# thereafter); garrison handles workload account provisioning. The
# operator's manual scope is just making sshd reachable on the
# network with a known admin password. Linux/Mac admin trust is
# operator-manual (e.g., ssh-copy-id); caparison-{linux,macos}
# orchestrates per-platform host posture after the operator's
# ssh-copy-id step.

set -euo pipefail

test -z "${ZBUHJ_SOURCED:-}" || buc_die "Module buhj multiply sourced - check sourcing hierarchy"
ZBUHJ_SOURCED=1

######################################################################
# Internal: Kindle and Sentinel

zbuhj_kindle() {
  test -z "${ZBUHJ_KINDLED:-}" || buc_die "Module buhj already kindled"

  test -n "${BUBC_windows_ssh_port:-}" || buc_die "buhj requires bubc_constants.sh sourced before kindle"

  readonly ZBUHJ_KINDLED=1
}

zbuhj_sentinel() {
  test "${ZBUHJ_KINDLED:-}" = "1" || buc_die "Module buhj not kindled - call zbuhj_kindle first"
}

######################################################################
# Internal: Section renderers

zbuhj_render_landing() {
  buh_section  "Jurisdiction Handbook"
  buh_line     "BUK reaches remote nodes through two operator-facing ceremonies."
  buh_line     "Caparison establishes admin host posture per platform"
  buh_line     "(Windows/macOS/Linux); Garrison provisions the workload account."
  buh_line     "BUK never generates or modifies SSH key material; the operator"
  buh_line     "owns all key administration."
  buh_e
  buh_line     "On Windows, caparison-windows handles first-run admin trust"
  buh_line     "itself: its phase-1 admin SSH session uses"
  buh_line     "PreferredAuthentications=publickey,password, falls through to a"
  buh_line     "/dev/tty password prompt on a fresh node, the operator types the"
  buh_line     "admin password once, caparison-windows installs the admin pubkey"
  buh_line     "+ sshd hardening + restarts sshd, and phase 2 reconnects by key"
  buh_line     "alone. Subsequent caparison-windows and garrison runs use key"
  buh_line     "auth automatically. The operator's manual scope on Windows"
  buh_line     "reduces to: make sshd reachable on the network with a known"
  buh_line     "admin password."
  buh_e
  buh_line     "On Linux/Mac, admin trust is operator-manual (ssh-copy-id or"
  buh_line     "equivalent); caparison-{linux,macos} runs after that to apply"
  buh_line     "per-platform host posture. Garrison then provisions the workload"
  buh_line     "account against the key-trusted admin foothold."
}

zbuhj_render_macos() {
  buh_section  "macOS: First-Time Host Setup"
  buh_line     "Operator-manual scope for macOS: install Tailscale (handling"
  buh_line     "Privacy & Security consent prompts), log in to your tailnet,"
  buh_line     "and place the admin pubkey via ssh-copy-id so caparison-macos's"
  buh_line     "first admin SSH succeeds by key alone. Caparison-macos enables"
  buh_line     "Remote Login (sshd) and applies pmset/tailscaled posture."
  buh_e

  buh_step1    "Install Tailscale:"
  buh_link     "" "Tailscale for macOS" "https://tailscale.com/download/mac"
  buh_line     "Approve each Privacy & Security prompt (System Extension,"
  buh_line     "network extension, login-at-startup); Tailscale cannot"
  buh_line     "establish a tunnel without them."
  buh_e

  buh_step1    "Log in to Tailscale:"
  buh_line     "Click the Tailscale menu bar icon and complete the sign-in"
  buh_line     "flow for your tailnet. Verify reachability from another node."
  buh_e

  buh_step1    "Place the admin pubkey via ssh-copy-id:"
  buh_code     "ssh-copy-id -i ~/.ssh/<admin-pubkey>.pub <admin-user>@<host>"
}

zbuhj_render_linux() {
  buh_section  "Linux: First-Time Host Setup"
  buh_line     "Operator-manual scope for Linux: install Tailscale, log in,"
  buh_line     "install/enable sshd on minimal distributions, and place the"
  buh_line     "admin pubkey via ssh-copy-id so caparison-linux's first admin"
  buh_line     "SSH succeeds by key alone. Caparison-linux applies sshd,"
  buh_line     "sleep-mask, and tailscaled posture."
  buh_e

  buh_step1    "Install Tailscale:"
  buh_link     "" "Tailscale for Linux" "https://tailscale.com/download/linux"
  buh_line     "Distribution-specific install commands are at the link above"
  buh_line     "(apt/dnf/pacman variants). The installer enables and starts"
  buh_line     "tailscaled by default."
  buh_e

  buh_step1    "Authenticate to Tailscale:"
  buh_code     "sudo tailscale up"
  buh_line     "Complete the auth URL in a browser; verify reachability from"
  buh_line     "another node."
  buh_e

  buh_step1    "Install and enable sshd (skip if openssh-server is already present):"
  buh_line     "Debian/Ubuntu:"
  buh_code     "sudo apt-get install -y openssh-server && sudo systemctl enable --now ssh"
  buh_line     "RHEL/Fedora:"
  buh_code     "sudo dnf install -y openssh-server && sudo systemctl enable --now sshd"
  buh_e

  buh_step1    "Place the admin pubkey via ssh-copy-id:"
  buh_code     "ssh-copy-id -i ~/.ssh/<admin-pubkey>.pub <admin-user>@<host>"
}

zbuhj_render_windows_availability() {
  buh_section  "Windows: Host Availability (optional)"
  buh_line     "Skip this section if an operator logs the host in after every restart."
  buh_line     "If the host lives in a physically-secured single-occupant room and"
  buh_line     "must come back from power loss or OS-update reboots without a console"
  buh_line     "operator, configure Tailscale unattended mode and Windows auto-login"
  buh_line     "before the sshd-reachability ceremony below."
  buh_e
  buh_section  "Precondition:"
  buh_line     "- Host lives in a physically-secured, single-occupant room."
  buh_line     "  Auto-login removes the keyboard barrier; physical access becomes"
  buh_line     "  total access."
  buh_e

  buh_step1    "Install Tailscale:"
  buh_link     "" "Tailscale for Windows" "https://tailscale.com/download/windows"
  buh_line     "The installer registers a per-user auto-start; default behavior is fine."
  buh_e

  buyy_ui_yawp "Preferences"; local -r z_prefs="${z_buym_yelp}"
  buyy_ui_yawp "Run unattended"; local -r z_unatt="${z_buym_yelp}"
  buh_step1    "Enable Run Unattended (tunnel survives without an interactive session):"
  buh_line     "Right-click the Tailscale tray icon, hover ${z_prefs}, select ${z_unatt}."
  buh_warn     "First boot quirk: the tunnel may require one interactive login before"
  buh_warn     "unattended mode settles (Tailscale issue #3186). Log in once, reboot,"
  buh_warn     "then verify from another node before walking away."
  buh_e

  buyy_cmd_yawp "netplwiz"; local -r z_netplwiz="${z_buym_yelp}"
  buyy_ui_yawp "Users must enter a user name and password to use this computer"; local -r z_checkbox="${z_buym_yelp}"
  buh_step1    "Configure Windows Auto-Login via netplwiz:"
  buh_line     "Press Win+R, enter ${z_netplwiz}, press Enter."
  buh_line     "Select the target user. Uncheck ${z_checkbox}."
  buh_line     "Click Apply. Enter the user's password twice when prompted."
  buh_e

  buyy_cmd_yawp "regedit"; local -r z_regedit="${z_buym_yelp}"
  buh_step2    "If the checkbox is absent (Microsoft account on Windows 11):"
  buh_line     "Open ${z_regedit} and set:"
  buh_code     "${BUBC_windows_passwordless_path}"
  buh_code     "    ${BUBC_windows_passwordless_value} = 0   (DWORD)"
  buh_line     "Reopen netplwiz; the checkbox now appears."
  buh_e

  buh_step1    "Disable Modern Standby (so powercfg sleep-disable actually takes effect):"
  buh_line     "On Modern Standby (S0 low-power idle) systems, powercfg's standby/"
  buh_line     "hibernate disable that caparison-windows applies is silently ignored"
  buh_line     "unless this override is set first. Open ${z_regedit} and set:"
  buh_code     "${BUBC_windows_aoac_path}"
  buh_code     "    ${BUBC_windows_aoac_value} = 0   (DWORD)"
  buh_line     "Reboot for the override to take effect."
}

zbuhj_render_windows_bootstrap() {
  buh_step1    "Set or Confirm Admin Password:"
  buh_line     "Caparison-Windows's phase-1 admin SSH session authenticates via"
  buh_line     "password (once) before installing the pubkey. If you already know"
  buh_line     "your local admin password, skip. Otherwise set it to a known value:"
  buh_code     "net user <admin-user> <temp-password>"
  buh_line     "After caparison-windows runs, sshd is hardened to key-only and"
  buh_line     "this value stops affecting SSH (it remains your Windows logon"
  buh_line     "password — leave it or reset to taste)."
  buh_e

  buh_step1    "Install OpenSSH Server:"
  buh_line     "Downloads from Windows Update; may take 10+ minutes."
  buh_code     "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"
  buh_e

  buh_step1    "Start and Enable the Service:"
  buh_line     "First start also generates the default sshd_config."
  buh_code     "Start-Service sshd"
  buh_code     "Set-Service -Name sshd -StartupType Automatic"
  buh_e

  buyy_cmd_yawp "${BUBC_windows_sshd_config}"; local -r z_sshd_config_yelp="${z_buym_yelp}"
  buh_step1    "Enable Password Authentication in sshd_config:"
  buh_line     "Windows OpenSSH ships with sshd_config in a state that blocks"
  buh_line     "caparison-windows's phase-1 password fallback (the wire protocol"
  buh_line     "advertises keyboard-interactive but the server refuses to"
  buh_line     "actually prompt). Open sshd_config in an editor; notepad"
  buh_line     "inherits your elevated context so SYSTEM-owned writes succeed."
  buh_line     "File: ${z_sshd_config_yelp}"
  buh_e
  buh_code     "notepad ${BUBC_windows_sshd_config}"
  buh_e
  buh_line     "Find the PasswordAuthentication directive (commented or"
  buh_line     "otherwise) and set it to exactly:"
  buh_e
  buh_code     "PasswordAuthentication yes"
  buh_e
  buh_line     "If no PasswordAuthentication line exists, add one. Save."
  buh_line     "Caparison-Windows flips this back to 'no' as part of its"
  buh_line     "hardening step, so this is a temporary state. Restart sshd to"
  buh_line     "pick up the change:"
  buh_e
  buh_code     "Restart-Service sshd"
  buh_e

  buh_step1    "Allow Port ${BUBC_windows_ssh_port} Through Firewall:"
  buh_code     "New-NetFirewallRule -Name ${BUBC_windows_fw_rule_name} -DisplayName \"${BUBC_windows_fw_display_name}\" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort ${BUBC_windows_ssh_port}"
  buh_e

  buh_section  "Verify Reachability"
  buh_line     "From the operator's station, confirm sshd answers (a password"
  buh_line     "prompt is expected and correct — caparison-windows's phase-1"
  buh_line     "admin session will type it through to ssh on /dev/tty):"
  buh_e
  buh_code     "ssh <admin-user>@<windows-host>"
}

zbuhj_render_top_windows_section() {
  buyy_tt_yawp "${BUWZ_JP_CAPARISON_WIN}"   ; local -r z_capw="${z_buym_yelp}"
  buyy_tt_yawp "${BUWZ_JP_GARRISON_CYGWIN}" ; local -r z_garc="${z_buym_yelp}"
  buyy_tt_yawp "${BUWZ_JP_GARRISON_WSL}"    ; local -r z_garw="${z_buym_yelp}"

  buh_section  "Windows: first-time host setup"
  buh_line     "Complete the first-time host preparation (optional Tailscale"
  buh_line     "autonomy, OpenSSH install, sshd reachability):"
  buh_tt       "  " "${BUWZ_HJW_WINDOWS}"
  buh_e
  buh_line     "Then establish admin host posture (admin SSH trust, sshd"
  buh_line     "harden, WSL distribution stage, sleep disable, Tailscale"
  buh_line     "auto-start):"
  buh_line     "  ${z_capw} <investiture>"
  buh_e
  buh_line     "Then run garrison for the workload shell of choice:"
  buh_line     "  ${z_garc} <investiture>"
  buh_line     "    Cygwin bash workload"
  buh_line     "  ${z_garw} <investiture>"
  buh_line     "    WSL bash workload"
  buh_e
  buh_line     "Choose c or w by which workload runtime you need. Both share"
  buh_line     "caparison-windows's admin SSH harden; the shell-letter on"
  buh_line     "garrison only routes the workload account ceremony. garrison-w"
  buh_line     "inherits the admin's rbtww-main WSL distribution that"
  buh_line     "caparison-windows staged — admin's distribution stays pristine"
  buh_line     "and its customizations propagate to the workload via a seed"
  buh_line     "tarball (Microsoft's per-user WSL design forces the workload"
  buh_line     "to own its own distribution registration)."
}

zbuhj_render_top_macos_section() {
  buyy_tt_yawp "${BUWZ_JP_CAPARISON_MAC}"  ; local -r z_capm="${z_buym_yelp}"
  buyy_tt_yawp "${BUWZ_JP_GARRISON_BASH}"  ; local -r z_garb="${z_buym_yelp}"

  buh_section  "macOS: first-time host setup"
  buh_line     "Complete the operator-manual prerequisites (Tailscale install"
  buh_line     "+ login, ssh-copy-id admin trust):"
  buh_tt       "  " "${BUWZ_HJM_MACOS}"
  buh_e
  buh_line     "Then establish admin host posture (Remote Login, pmset,"
  buh_line     "tailscaled):"
  buh_line     "  ${z_capm} <investiture>"
  buh_e
  buh_line     "Then run garrison for the native bash workload:"
  buh_line     "  ${z_garb} <investiture>"
}

zbuhj_render_top_linux_section() {
  buyy_tt_yawp "${BUWZ_JP_CAPARISON_LIN}"  ; local -r z_capl="${z_buym_yelp}"
  buyy_tt_yawp "${BUWZ_JP_GARRISON_BASH}"  ; local -r z_garb="${z_buym_yelp}"

  buh_section  "Linux: first-time host setup"
  buh_line     "Complete the operator-manual prerequisites (Tailscale install"
  buh_line     "+ login, sshd install/enable on minimal distros, ssh-copy-id"
  buh_line     "admin trust):"
  buh_tt       "  " "${BUWZ_HJL_LINUX}"
  buh_e
  buh_line     "Then establish admin host posture (sshd, sleep mask,"
  buh_line     "tailscaled):"
  buh_line     "  ${z_capl} <investiture>"
  buh_e
  buh_line     "Then run garrison for the native bash workload:"
  buh_line     "  ${z_garb} <investiture>"
}

zbuhj_render_workload_dispatch() {
  buyy_tt_yawp "${BUWZ_JW_KNOCK}"         ; local -r z_jwk="${z_buym_yelp}"
  buyy_tt_yawp "${BUWZ_JW_COMMAND_FILE}"  ; local -r z_jwc="${z_buym_yelp}"
  buyy_tt_yawp "${BUWZ_JW_INTERACTIVE}"   ; local -r z_jws="${z_buym_yelp}"

  buh_section  "After garrison: workload dispatch"
  buh_line     "Once garrison succeeds, dispatch work via the workload"
  buh_line     "tabtargets (platform-agnostic):"
  buh_line     "  ${z_jwk} <investiture>"
  buh_line     "    Probe workload reachability"
  buh_line     "  ${z_jwc} <investiture> <file>"
  buh_line     "    Run a command file"
  buh_line     "  ${z_jws} <investiture>"
  buh_line     "    Interactive workload session"
}

######################################################################
# External Functions (buhj_*)

buhj_top() {
  zbuhj_sentinel

  buc_doc_brief "Display jurisdiction handbook landing + tabtarget catalog (top level)"
  buc_doc_shown || return 0

  zbuhj_render_landing
  buh_e
  zbuhj_render_top_windows_section
  buh_e
  zbuhj_render_top_macos_section
  buh_e
  zbuhj_render_top_linux_section
  buh_e
  zbuhj_render_workload_dispatch
}

buhj_windows() {
  zbuhj_sentinel

  buc_doc_brief "Display Windows first-time host setup (Tailscale autonomy + sshd reachability)"
  buc_doc_shown || return 0

  zbuhj_render_windows_availability
  buh_e
  zbuhj_render_windows_bootstrap
}

buhj_macos() {
  zbuhj_sentinel

  buc_doc_brief "Display macOS first-time host setup (Tailscale install + login, ssh-copy-id admin trust)"
  buc_doc_shown || return 0

  zbuhj_render_macos
}

buhj_linux() {
  zbuhj_sentinel

  buc_doc_brief "Display Linux first-time host setup (Tailscale, sshd on minimal distros, ssh-copy-id admin trust)"
  buc_doc_shown || return 0

  zbuhj_render_linux
}

# eof
