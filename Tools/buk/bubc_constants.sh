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

# Precision exit-code band — deliberate-rejection gate codes.
# Design position, allocation rule, and the rejected stderr-sentinel
# alternative: BCG "Precision Exit-Code Band". This block is the sole mint —
# no band code is defined anywhere else.
# An in-band exit status means a named rejection gate fired on purpose;
# exit 1 stays "imprecise death" (buc_die default). buc_die propagates
# in-band $? values unchanged (the band membrane), so existing
# `cmd || buc_die` chains carry these codes to the dispatch boundary where
# the test orchestrator asserts them in negative cases.
# Placement: clear of shell-reserved codes (2, 126, 127, 128+n signals),
# the sysexits.h range (64-78), curl's exit codes (1-92), and
# timeout(1)/container-runtime reserved codes (124-125).
# Allocation rule: one code per rejection GATE, never per validation rule.
# Gates may share a code only if they never co-occur in one test case's
# spawn path — share across alternatives, never along a pipeline.
# No band code is minted outside this block.
BUBC_band_base=100
BUBC_band_width=16
# Gate codes, allocated upward from base. The regime-load pipeline crosses
# two gates in one spawn path — the buv layer (vet value checks + scope
# sentinel) and the regime module's own custom enforce rules — so per the
# allocation rule they carry distinct codes:
BUBC_band_regime=100    # regime-module custom enforce rejection (cross-field, format regex, existence)
BUBC_band_enroll=101    # buv enrollment-validation rejection (buv_vet, buv_scope_sentinel)
BUBC_band_recipe=102    # recipe validation rejection
BUBC_band_hygiene=103   # Dockerfile FROM-line hygiene rejection (rbfh)
BUBC_band_credless=104  # credless guard at token mint (reveille-tier suite invariant)
BUBC_band_chain=105     # chaining-fact resolution rejection (broken express-or-chain, or wrong-kind touchmark) — one gate, alternative firings never co-occur in a spawn path
# Foedus test-bed cardinality verbs (descry/instate). Distinct codes per the
# allocation rule: descry (pool-health probe) and instate (active-foedus
# selector rewrite) co-occur in the reuse-or-establish fixture's spawn path,
# so they may not share a code. Neither is the chaining band (105) — neither
# resolves an express-or-chain fact.
BUBC_band_descry=106    # foedus descry rejection (unresolvable foedus name, broken pool read)
BUBC_band_instate=107   # foedus instate rejection (missing/unresolvable foedus identity)
# Self-test probe pins the band top, proving full-width propagation:
BUBC_band_selftest=115  # BUK self-test deliberate rejection (buw-xb fixture)

# Regime-poison tweak (BUS0 Tweak Mechanism; buost_ is BUK's reserved buo
# segment). The seam is one membrane in buv_regime_enroll — the single buv
# entry every regime kindle crosses, post-source pre-validate. Under this
# tweak name, BURE_TWEAK_VALUE names one variable to corrupt: "VAR=value"
# sets, bare "VAR" unsets. The seam applies only when VAR carries the
# enrolling scope's prefix, so a poison rides inert through the host
# regimes of a dispatch and lands exactly once, on its target.
BUBC_tweak_regime_poison="buost_regime_poison"

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
