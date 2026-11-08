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
# BUBC — BUK Bootstrap Constants
# Source-time literal constants for BUK kit layout.
# No kindle dependency — available immediately upon sourcing.

# Guard against multiple inclusion
test -z "${ZBUBC_SOURCED:-}" || buc_die_now "Module bubc multiply sourced - check sourcing hierarchy"
ZBUBC_SOURCED=1

# Source-time literal constants.
readonly BUBC_launchers_subdir="buml_launchers"
readonly BUBC_rbmn_nodes_subdir="rbmn_nodes"
readonly BUBC_rbmu_users_subdir="rbmu_users"

# Platform identifiers (bunne_* — BURN node-regime enum sprue family).
# These values are the canonical OS-family identifiers used in BURN_PLATFORM
# enrollment and in per-tabtarget platform invariant assertions.
# BUBC_platforms_<family> tinder constants provide single source of truth so
# code refers to the identifier by family name rather than hardcoding the
# literal token at every comparison site.
readonly BUBC_platforms_linux="bunne_linux"
readonly BUBC_platforms_mac="bunne_mac"
readonly BUBC_platforms_windows="bunne_windows"

# Windows OpenSSH layout — forward slashes throughout so identical strings
# work in PowerShell, terminal display, and icacls invocations.
readonly BUBC_windows_sshd_config='C:/ProgramData/ssh/sshd_config'
readonly BUBC_windows_admin_auth_keys='C:/ProgramData/ssh/administrators_authorized_keys'
readonly BUBC_windows_ssh_port="22"
readonly BUBC_windows_fw_rule_name="sshd"
readonly BUBC_windows_fw_display_name="OpenSSH Server"

# Regime-poison tweak (buost_ is BUK's reserved buo
# segment). The seam is one membrane in buv_regime_enroll — the single buv
# entry every regime kindle crosses, post-source pre-validate. Under this
# tweak name, BURE_TWEAK_VALUE names one variable to corrupt: "VAR=value"
# sets, bare "VAR" unsets. The seam applies only when VAR carries the
# enrolling scope's prefix, so a poison rides inert through the host
# regimes of a dispatch and lands exactly once, on its target.
readonly BUBC_tweak_regime_poison="buost_regime_poison"

# The configuration words a tabtarget's configuration line carries after its
# launcher basename (buuc_ is the kit's sprue for them). The create doors write
# them and the dispatch and the structure check answer to them through these
# constants; the launcher, which tests a configuration before any module loads,
# spells them in its own case. The spellings stand in every receiving
# repository's tabtargets, so they are conserved.
readonly BUBC_word_interactive="buuc_interactive"
readonly BUBC_word_nolog="buuc_nolog"
readonly BUBC_word_ownlog="buuc_ownlog"

# Windows registry preconditions for unattended power-on posture.
# An operator-handbook step sets these; the jurisdiction's invigilate step
# reads them. Single source of truth so the path the handbook tells the
# operator to set is the path invigilate queries.
# PowerShell-canonical form (HKLM:\ prefix, mixed case — registry is
# case-insensitive at the OS level so display case is purely cosmetic).
readonly BUBC_windows_passwordless_path='HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
readonly BUBC_windows_passwordless_value='DevicePasswordLessBuildVersion'
readonly BUBC_windows_aoac_path='HKLM:\System\CurrentControlSet\Control\Power'
readonly BUBC_windows_aoac_value='PlatformAoAcOverride'

# eof
