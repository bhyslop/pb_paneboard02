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
# BUBC — BUK Bootstrap Constants
# Source-time literal constants for BUK kit layout.
# No kindle dependency — available immediately upon sourcing.

# Guard against multiple inclusion
test -z "${ZBUBC_SOURCED:-}" || return 0
ZBUBC_SOURCED=1

# Source-time literal constants.
#
# BUBC_moorings_dir mirrors the irreducible bootstrap anchor in bul_launcher.sh
# (which cannot derive it — it must locate the config dir before sourcing
# anything). Non-bootstrap consumers derive their moorings paths from here
# rather than re-literaling the directory name.
BUBC_moorings_dir="rbmm_moorings"
BUBC_launchers_subdir="rbml_launchers"
BUBC_rbmn_nodes_subdir="rbmn_nodes"
BUBC_rbmu_users_subdir="rbmu_users"

# Platform identifiers (bunne_* — BURN node-regime enum sprue family).
# These values are the canonical OS-family identifiers used in BURN_PLATFORM
# enrollment and in per-tabtarget platform invariant assertions.
# BUBC_platforms_<family> tinder constants provide single source of truth so
# code refers to the identifier by family name rather than hardcoding the
# literal token at every comparison site.
BUBC_platforms_linux="bunne_linux"
BUBC_platforms_mac="bunne_mac"
BUBC_platforms_windows="bunne_windows"

# Windows OpenSSH layout — forward slashes throughout so identical strings
# work in PowerShell, terminal display, and icacls invocations.
BUBC_windows_sshd_config='C:/ProgramData/ssh/sshd_config'
BUBC_windows_admin_auth_keys='C:/ProgramData/ssh/administrators_authorized_keys'
BUBC_windows_ssh_port="22"
BUBC_windows_fw_rule_name="sshd"
BUBC_windows_fw_display_name="OpenSSH Server"

# Windows registry preconditions for unattended power-on posture.
# Operator-handbook step (BUSJHW Windows: Host Availability) sets these;
# bujb_invigilate_windows reads them. Single source of truth so the path
# the handbook tells the operator to set is the path invigilate queries.
# PowerShell-canonical form (HKLM:\ prefix, mixed case — registry is
# case-insensitive at the OS level so display case is purely cosmetic).
BUBC_windows_passwordless_path='HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
BUBC_windows_passwordless_value='DevicePasswordLessBuildVersion'
BUBC_windows_aoac_path='HKLM:\System\CurrentControlSet\Control\Power'
BUBC_windows_aoac_value='PlatformAoAcOverride'

# eof
