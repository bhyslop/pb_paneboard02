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
# BUJB Jurisdiction Module - Implementation seat for caparison + invigilate + garrison
#
# BCG-compliant module housing the BUS0 jurisdiction verbs (caparison,
# invigilate, garrison) and the contracts not expressed in regime data:
# the three shell-letter -> command= directive mappings (b/c/w),
# the workload privkey destination paths on the remote per shell-letter,
# the canonical WSL distribution name, and the Windows OpenSSH sshd_config
# hardening directive set.
#
# Sub-letter b in bujb signals the bash-format implementation.

set -euo pipefail

# Multiple inclusion detection
test -z "${ZBUJB_SOURCED:-}" || buc_die "Module bujb multiply sourced - check sourcing hierarchy"
ZBUJB_SOURCED=1

# Tinder constants (pure string literals or tinder-on-tinder composition —
# available at source time)

# Canonical workload OS user name provisioned on every node by garrison.
# Project-wide convention; consumed by every account-relative path tinder
# below, substituted into BUJB_command_w via bujb_command_for_capture,
# and consumed by garrison/cli display strings.
BUJB_workload_user='bujuw_user'

# Canonical WSL distribution name reached by garrison-w.
BUJB_wsl_distribution='rbtww-main'

# wsl.exe invocation prefix for running a bash body as root inside the
# canonical workload distribution from any non-bash transport (PS heredoc,
# cmd.exe argv). Tinder-on-tinder so a future BUJB_wsl_distribution rename
# is a one-line edit. Bare wsl.exe relies on Windows PATH resolution from
# system32; the absolute-path form ${BUJB_path_wsl_exe} applies only in
# the BUJB_command_w directive where SSH-auth-time resolution requires a
# fully qualified path.
BUJB_wsl_root_bash_c="wsl.exe --distribution ${BUJB_wsl_distribution} --user root bash -c"

# Path segment shared by every account-relative SSH state directory.
BUJB_path_dotssh='.ssh'

# authorized_keys basename — OpenSSH-defined filename. Used tinder-on-tinder
# in the per-coordinate-system authkeys paths and inline in garrison step4's
# authkeys writes.
BUJB_authkeys_basename='authorized_keys'

# Absolute path to bash on Linux/Mac/WSL — pinned to /bin/bash rather than
# the PATH-resolved bare 'bash' for command= directives and user-shell
# declarations where the absolute form is required.
BUJB_shell_bash='/bin/bash'

# POSIX stdin pseudo-device path — used by the install -D pattern in
# garrison step5 to plant the workload privkey atomically without any
# plaintext temp file on either side's disk.
BUJB_path_devstdin='/dev/stdin'

# WSL artifact basenames placed under the workload Windows profile by the
# garrison-w seed/import sequence.
BUJB_seed_basename='rbtww-seed.tar'
BUJB_wsl_root_basename='rbtww-fs'

# Cygwin install root in two slash conventions. Forward-slash form
# survives `command="..."` directives and cmd.exe / PS argv layers
# without escape pain (used in BUJB_command_c and zbujb_admin_exec_cygwin).
# Back-slash form is for PowerShell path arguments where Test-Path /
# Remove-Item expect native Windows separators (used by the obliterate
# Cygwin-home probe/remove). Do not collapse — the divergence is
# load-bearing per the layer that consumes each form.
BUJB_path_cygwin_root_fwd='C:/cygwin64'
BUJB_path_cygwin_root_bs="C:\\cygwin64"

# Windows-OpenSSH path to wsl.exe, embedded in the locked-down command=
# directive for shell-letter w. Forward-slash form per the same argv-layer
# rule as BUJB_path_cygwin_root_fwd.
BUJB_path_wsl_exe='C:/Windows/System32/wsl.exe'

# Workload home directories per coordinate system. Tinder-on-tinder so a
# future BUJB_workload_user rename is a one-line edit.
BUJB_path_win_user_home="C:\\Users\\${BUJB_workload_user}"
BUJB_path_wsl_user_home="/mnt/c/Users/${BUJB_workload_user}"
BUJB_path_cyg_user_home="/cygdrive/c/Users/${BUJB_workload_user}"
BUJB_path_mac_user_home="/Users/${BUJB_workload_user}"
BUJB_path_posix_user_home="/home/${BUJB_workload_user}"
BUJB_path_cygwin_user_home="${BUJB_path_cygwin_root_bs}\\home\\${BUJB_workload_user}"

# .ssh directories under each home (b/c letters; w-letter does not use a
# workload-profile authkeys path — see absolute-path constants below).
BUJB_path_posix_user_ssh="${BUJB_path_posix_user_home}/${BUJB_path_dotssh}"

# Workload authorized_keys under garrison-w lives at an admin-owned absolute
# path outside the workload profile. Caparison-windows installs a sshd_config
# Match User block routing lookup here and provisions the parent directory
# (admins-FullControl + SYSTEM, no workload ACE — sshd reads as SYSTEM).
# Garrison writes the file content.
#
#   __PROGRAMDATA__   sshd's own token; substituted at sshd parse time.
#                     Use this form inside sshd_config text.
#   $env:ProgramData  PowerShell expansion form; use for PS cmdlet arguments.
BUJB_path_sshd_workload_authkeys="__PROGRAMDATA__/ssh/users/${BUJB_workload_user}/authorized_keys"
BUJB_path_ps_workload_authkeys_dir="\$env:ProgramData\\ssh\\users\\${BUJB_workload_user}"
BUJB_path_ps_workload_authkeys="${BUJB_path_ps_workload_authkeys_dir}\\authorized_keys"

# sshd_config Match block content for the workload user. Caparison appends
# this to the end of sshd_config; idempotency strips any prior copy before
# the append. Two-line literal — sshd accepts the indented continuation.
BUJB_sshd_match_block_text="Match User ${BUJB_workload_user}
    AuthorizedKeysFile ${BUJB_path_sshd_workload_authkeys}"

# WSL-install seed distribution: the Microsoft-published distribution that
# zbujb_caparison_windows_stage_wsl fetches via `wsl.exe --install --no-launch -d`, exports
# to .tar, then re-imports under BUJB_wsl_distribution.
BUJB_wsl_seed_distribution='Ubuntu-24.04'

# Windows-side install directory housing both seed and canonical
# distribution VHD trees plus the intermediate .tar export. The
# bujb- prefix names the BUK module that owns this directory, so
# the path is unambiguously project-controlled rather than reading
# as a Microsoft-default location (the prior C:\WSL value did).
BUJB_path_win_wsl_install_root='C:\bujb-wsl'

# WSL artifacts.
# Seed tarball lives under C:\bujb-wsl (caparison-windows-created;
# inherits BUILTIN\Users:ReadAndExecute from C:\ default ACL, which
# is what allows the SSH-as-workload `wsl --import` to read the
# seed without an icacls fix-up step). Writing the seed under the
# workload profile would inherit admin's logon-SID ACL excluding
# the workload user, since admin runs the wsl --export. The
# workload's installed-VHD root stays under the workload profile
# (workload owns it; created by the workload's own wsl --import).
BUJB_path_win_seed_tarball="${BUJB_path_win_wsl_install_root}\\${BUJB_seed_basename}"
BUJB_path_win_wsl_root="${BUJB_path_win_user_home}\\${BUJB_wsl_root_basename}"

# Windows ACL principal names used in icacls /grant arguments. The :F
# permission suffix is appended at use sites alongside ${BUJB_workload_user}:F
# so all three principals follow the same `<principal>:F` shape.
BUJB_acl_principal_system='SYSTEM'
BUJB_acl_principal_admins='BUILTIN\Administrators'

# Shell-letter -> command= directive mappings.
# Forced commands routed through SSH_ORIGINAL_COMMAND keep workload account
# behaviour pinned to the chosen shell regardless of what the SSH client
# requests. Locked spec content; mirrored in BUSJG{B,C,W}.
# Tinder-on-tinder source-time interpolation: cygwin/wsl/distribution/user
# resolve at source time so the value is a fully-baked literal by the time
# bujb_command_for_capture echoes it. \"...\" pairs are literal escaped
# quotes the remote sshd parser expects around the command directive's
# argument; \$SSH_ORIGINAL_COMMAND defers expansion to the remote shell.
BUJB_command_b="command=\"${BUJB_shell_bash} -lc \\\"\$SSH_ORIGINAL_COMMAND\\\"\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding"
BUJB_command_c="command=\"${BUJB_path_cygwin_root_fwd}/bin/bash --login -c \\\"\$SSH_ORIGINAL_COMMAND\\\"\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding"
BUJB_command_w="command=\"${BUJB_path_wsl_exe} --distribution ${BUJB_wsl_distribution} --user ${BUJB_workload_user} --exec ${BUJB_shell_bash} -lc \\\"\$SSH_ORIGINAL_COMMAND\\\"\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding"

# Workload privkey destination path on the remote (relative to the workload
# account home directory). Uniform across shell-letters under the current
# design — if a future shell needs a divergent keypath, fan out per-letter.
BUJB_workload_keypath='.ssh/id_ed25519'

# Windows OpenSSH sshd_config hardening directive set written by
# caparison-windows phase 1. Newline-joined; each directive is asserted by
# bash-side parse after PowerShell Get-Content returns the raw bytes.
BUJB_sshd_hardening='PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no'

# User-provisioning argument sets per platform tooling.
#
# BUJB_useradd_workload_args — Linux/WSL useradd flags declaring the
# workload account policy (home-directory creation + absolute shell).
# Used in step3 b (linux), step3 b (mac via dscl UserShell), and
# w_init wsl-useradd.
# BUJB_netuser_add_args — Windows net.exe user /add flags declaring the
# password-not-required + active workload posture (used in step3 c and
# step3 w).
BUJB_useradd_workload_args="--create-home --shell ${BUJB_shell_bash}"
BUJB_netuser_add_args='/add /passwordreq:no /active:yes'

# ssh-keygen invocation prefix for emitting the public key derived from a
# private key under empty-passphrase dry-load. Idiom used for admin-key
# resolve-investiture validation and for workload/admin pubkey emission in
# garrison step4, w-lockdown, and caparison-windows phase 1.
BUJB_sshkeygen_emit_pubkey="ssh-keygen -y -P '' -f"

# SSH option values used inline at every ssh call alongside
# ZBUJB_SSH_BASE_ARGS. BatchMode=yes / ConnectTimeout=15 is the dominant
# pair; the BatchMode=no + PreferredAuthentications=publickey,password
# variant lives in zbujb_admin_powershell_with_password_fallback for the
# single bounded Add-Content callsite (caparison-windows phase 1 step 3);
# step6_validate's knock uses ConnectTimeout=10 inline.
BUJB_ssh_opt_batchmode_yes='BatchMode=yes'
BUJB_ssh_opt_connecttimeout_15='ConnectTimeout=15'
BUJB_ssh_opt_connecttimeout_5='ConnectTimeout=5'

# Reboot-and-await polling cadence (zbujb_reboot_and_await_ssh). Interval
# is the bash sleep between SSH probes; cap is the total wait ceiling
# tolerating pending Windows-update install on first boot after a patch
# day. max_attempts derives in-helper from cap / interval.
BUJB_reboot_poll_interval_s='7'
BUJB_reboot_poll_cap_s='600'

# PowerShell CLI invocation form for one-shot string bodies. After the
# Phase 1 decomposition into single-cmdlet zbujb_admin_powershell calls
# this is the only form caparison uses; the prior `powershell -NoProfile
# -File -` stdin-fed form retired with the heredoc helpers.
BUJB_ps_invoke_command='powershell -NoProfile -Command'

# PowerShell session discipline prelude shared by admin_powershell and
# powershell_capture:
#   $ErrorActionPreference = 'Stop'  — PS errors terminate the session.
#   $env:WSL_UTF8 = 1                — wsl.exe emits UTF-8 (not UTF-16).
#   $LASTEXITCODE = 0                — initialize so a trailing if-check
#     does not trip on the $null default ($null -ne 0 evaluates True in
#     PowerShell typed comparison, which would fire `exit $null` and
#     discard buffered object-formatter output for cmdlets like
#     Get-LocalUser whose tables have not flushed to stdout yet).
BUJB_ps_prelude="\$ErrorActionPreference = 'Stop'; \$env:WSL_UTF8 = 1; \$LASTEXITCODE = 0;"

# PowerShell-form path to the Windows OpenSSH sshd_config. Bash-side
# substitution at the use site expands this tinder, baking the literal
# $env:ProgramData\ssh\sshd_config into the constructed PS body.
BUJB_ps_sshd_config_path='$env:ProgramData\ssh\sshd_config'

######################################################################
# Internal Functions (zbujb_*)

zbujb_kindle() {
  test -z "${ZBUJB_KINDLED:-}" || buc_die "Module bujb already kindled"

  # Per-call forensic capture is housed inside the five interaction
  # helpers (zbujb_admin_powershell, _with_password_fallback,
  # zbujb_admin_exec_impl, zbujb_workload_ssh). Each call advances the
  # shared z_bujb_emit_index counter and writes stdout/stderr to
  # ${BURD_TEMP_DIR}/bujb_${CHIT}${idx}_{stdout,stderr}.txt; the helper
  # exposes the resulting paths via ZBUJB_LAST_AP_STDOUT /
  # ZBUJB_LAST_AP_STDERR so parse sites can read the latest call's
  # output. CHIT is supplied by each call site as a concatenation of one
  # of the ZBUJB_CHIT_* namespace fragments (below) and a per-step
  # label, e.g. "${ZBUJB_CHIT_caparison}p1-sshd-read-". Fragment
  # orthogonality is grep-auditable: each fragment should appear only
  # inside its owning phase function.
  readonly ZBUJB_CHIT_caparison="caparison-"
  readonly ZBUJB_CHIT_invigilate="invigilate-"
  readonly ZBUJB_CHIT_w_init="w-init-"
  readonly ZBUJB_CHIT_obliterate="obliterate-"
  readonly ZBUJB_CHIT_garrison_step="garrison-step-"
  readonly ZBUJB_CHIT_stage_wsl="stage-wsl-"

  # Latest-call forensic paths set by every interaction helper. Parse
  # sites read `$(<"${ZBUJB_LAST_AP_STDOUT}")` immediately after the
  # call (next call overwrites the variable). Probes that only inspect
  # exit code ignore these.
  ZBUJB_LAST_AP_STDOUT=""
  ZBUJB_LAST_AP_STDERR=""

  # stat captures (per-key-slot for parallel forensics on resolve).
  readonly ZBUJB_STAT_STDOUT_PRIV="${BURD_TEMP_DIR}/bujb_stat_priv_stdout.txt"
  readonly ZBUJB_STAT_STDERR_PRIV="${BURD_TEMP_DIR}/bujb_stat_priv_stderr.txt"
  readonly ZBUJB_STAT_STDOUT_WORK="${BURD_TEMP_DIR}/bujb_stat_work_stdout.txt"
  readonly ZBUJB_STAT_STDERR_WORK="${BURD_TEMP_DIR}/bujb_stat_work_stderr.txt"

  # ssh-keygen dry-load captures (resolve-time, per slot).
  readonly ZBUJB_DRYLOAD_STDOUT_PRIV="${BURD_TEMP_DIR}/bujb_dryload_priv_stdout.txt"
  readonly ZBUJB_DRYLOAD_STDERR_PRIV="${BURD_TEMP_DIR}/bujb_dryload_priv_stderr.txt"
  readonly ZBUJB_DRYLOAD_STDOUT_WORK="${BURD_TEMP_DIR}/bujb_dryload_work_stdout.txt"
  readonly ZBUJB_DRYLOAD_STDERR_WORK="${BURD_TEMP_DIR}/bujb_dryload_work_stderr.txt"

  # ssh-keygen pubkey-emit captures (garrison step4 = workload pubkey,
  # caparison-windows phase1 = admin pubkey).
  readonly ZBUJB_PUBKEY_STDOUT_WORK="${BURD_TEMP_DIR}/bujb_pubkey_work_stdout.txt"
  readonly ZBUJB_PUBKEY_STDERR_WORK="${BURD_TEMP_DIR}/bujb_pubkey_work_stderr.txt"
  readonly ZBUJB_PUBKEY_STDOUT_PRIV="${BURD_TEMP_DIR}/bujb_pubkey_priv_stdout.txt"
  readonly ZBUJB_PUBKEY_STDERR_PRIV="${BURD_TEMP_DIR}/bujb_pubkey_priv_stderr.txt"

  # base64 capture (garrison step4 w-branch = authorized_keys line b64-encoded
  # for transport to remote).
  readonly ZBUJB_AUTHKEYS_B64_STDOUT="${BURD_TEMP_DIR}/bujb_authkeys_b64_stdout.txt"
  readonly ZBUJB_AUTHKEYS_B64_STDERR="${BURD_TEMP_DIR}/bujb_authkeys_b64_stderr.txt"

  # Output capture paths for bujb_command_file (workload stdout/stderr/exit).
  readonly ZBUJB_OUTPUT_STDOUT="${BURD_OUTPUT_DIR}/stdout.log"
  readonly ZBUJB_OUTPUT_STDERR="${BURD_OUTPUT_DIR}/stderr.log"
  readonly ZBUJB_OUTPUT_EXITCODE="${BURD_OUTPUT_DIR}/exitcode"

  # Single shared emission counter across all interaction helpers — file
  # numbers are continuous regardless of which helper ran so chronological
  # order is readable from the embedded number even when CHIT fragments
  # differ. Seeded at 100 so all emitted filenames carry 3-digit indices;
  # %02d in zbujb_emit_index_advance is minimum-width and renders 100+
  # correctly.
  z_bujb_emit_index=100

  # SSH base options shared by every ssh invocation in this module:
  # IdentitiesOnly pins the key to ssh -i; StrictHostKeyChecking=accept-new
  # records first-contact host keys without prompting. The dominant
  # BatchMode=yes / ConnectTimeout=15 pair lives in tinder constants
  # (BUJB_ssh_opt_batchmode_yes, BUJB_ssh_opt_connecttimeout_15) referenced
  # inline at each ssh — security review reads one source-of-truth
  # declaration. PreferredAuthentications and the variant cases
  # (BatchMode=no for password-fallback, ConnectTimeout=10 for knock) stay
  # inline at their lone call sites.
  ZBUJB_SSH_BASE_ARGS=(
    -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=accept-new
  )
  readonly ZBUJB_SSH_BASE_ARGS

  readonly ZBUJB_KINDLED=1
}

zbujb_sentinel() {
  test "${ZBUJB_KINDLED:-}" = "1" || buc_die "Module bujb not kindled - call zbujb_kindle first"
}

# zbujb_check_key_file PATH VARNAME SLOT -- validate SSH private key at PATH:
# exists, mode 0600, parseable + unencrypted (ssh-keygen -y dry-load with
# empty passphrase). Diagnostic uses VARNAME as the field label. SLOT
# (priv|work) selects the kindle temp-file pair used for stat + dry-load
# stdout/stderr capture so failures preserve forensic evidence per BCG.
zbujb_check_key_file() {
  local -r z_path="${1:-}"
  local -r z_varname="${2:-}"
  local -r z_slot="${3:-}"

  test -n "${z_path}"    || buc_die "${z_varname}: empty path"
  test -f "${z_path}"    || buc_die "${z_varname}: file not found: ${z_path}"

  local z_stat_stdout="" z_stat_stderr="" z_dry_stdout="" z_dry_stderr=""
  case "${z_slot}" in
    priv)
      z_stat_stdout="${ZBUJB_STAT_STDOUT_PRIV}"
      z_stat_stderr="${ZBUJB_STAT_STDERR_PRIV}"
      z_dry_stdout="${ZBUJB_DRYLOAD_STDOUT_PRIV}"
      z_dry_stderr="${ZBUJB_DRYLOAD_STDERR_PRIV}"
      ;;
    work)
      z_stat_stdout="${ZBUJB_STAT_STDOUT_WORK}"
      z_stat_stderr="${ZBUJB_STAT_STDERR_WORK}"
      z_dry_stdout="${ZBUJB_DRYLOAD_STDOUT_WORK}"
      z_dry_stderr="${ZBUJB_DRYLOAD_STDERR_WORK}"
      ;;
    *)
      buc_die "zbujb_check_key_file: invalid slot (expected priv|work): '${z_slot}'"
      ;;
  esac

  # BSD stat first (Mac), GNU stat fallback (Linux). The failed flavor's
  # stderr is overwritten by the successful flavor's invocation; on total
  # failure z_stat_stderr holds the GNU-attempt error.
  if stat -f '%A' "${z_path}" > "${z_stat_stdout}" 2> "${z_stat_stderr}"; then
    : # macOS / BSD stat succeeded
  elif stat -c '%a' "${z_path}" > "${z_stat_stdout}" 2> "${z_stat_stderr}"; then
    : # GNU/Linux stat succeeded
  else
    buc_die "${z_varname}: cannot stat ${z_path} — see ${z_stat_stderr}"
  fi

  local z_mode
  z_mode=$(<"${z_stat_stdout}")
  z_mode="${z_mode//$'\n'/}"
  test "${z_mode}" = "600" \
    || buc_die "${z_varname}: mode must be 0600, got ${z_mode}: ${z_path}"

  ${BUJB_sshkeygen_emit_pubkey} "${z_path}" \
      > "${z_dry_stdout}" \
      2> "${z_dry_stderr}" \
    || buc_die "${z_varname}: ssh-keygen -y dry-load failed (passphrase-protected or malformed): ${z_path} — see ${z_dry_stderr}"
}

######################################################################
# Public Functions (bujb_*)

# bujb_resolve_investiture -- sole runtime cross-validation entrypoint.
#
# Preconditions: BURC, BURN, BURP regimes already kindled and enforced
# (the bujb_cli furnish handles this for tabtarget callers; the cli's
# BURP and BURN sourcing also implicitly cross-validates that the
# investiture name (BUZ_FOLIO) equals a registered investiture —
# enforcement is by file presence of the matching BURN profile).
#
# Behaviour: validates BURP_PRIVILEGED_KEY_FILE and BURP_WORKLOAD_KEY_FILE
# (exist, mode 0600, ssh-keygen -y dry-load proves parseable + unencrypted) —
# the validation regime enforce cannot do because it requires running
# ssh-keygen against the private key. After validation, sets ZBUJB_RESOLVED=1
# as the I-have-been-validated sentinel. Callers reference the regime vars
# directly (BURP_*, BURN_*, BURC_*); no separate published namespace.
# Single-call-per-process; subsequent calls die.
#
# BCG deviation: ZBUJB_RESOLVED is a kindle-shaped (SCREAMING + readonly)
# constant set outside zbujb_kindle. The deviation is load-bearing —
# resolve-investiture runs ssh-keygen dry-loads against private keys, which
# kindle cannot do (kindle establishes module state at sourcing time, not
# after BURP regime enforcement). This matches the regime archetype's
# "enforce after kindle, lock after enforce" pattern (BCG line 113); we
# just spell the lock as a discrete sentinel because there's no enrolled-
# variable set to readonly in this module.
bujb_resolve_investiture() {
  zbujb_sentinel
  zburc_sentinel
  zburn_sentinel
  zburp_sentinel

  test -z "${ZBUJB_RESOLVED:-}" \
    || buc_die "bujb_resolve_investiture already called - single-call-per-process"

  zbujb_check_key_file "${BURP_PRIVILEGED_KEY_FILE}" "BURP_PRIVILEGED_KEY_FILE" priv
  zbujb_check_key_file "${BURP_WORKLOAD_KEY_FILE}"   "BURP_WORKLOAD_KEY_FILE"   work

  readonly ZBUJB_RESOLVED=1
}

# bujb_command_for_capture SHELL_LETTER -- emit the workload authorized_keys
# command= directive for shell-letter b, c, or w. _capture form so callers
# may use `$()` per BCG line 502; returns 1 on invalid letter, callers must
# `|| buc_die`. All tinder-on-tinder interpolation already resolved at
# source time — uniform letter-case, no per-letter substitution gymnastics.
bujb_command_for_capture() {
  zbujb_sentinel
  local -r z_letter="${1:-}"
  case "${z_letter}" in
    b) echo "${BUJB_command_b}" ;;
    c) echo "${BUJB_command_c}" ;;
    w) echo "${BUJB_command_w}" ;;
    *) return 1 ;;
  esac
}

######################################################################
# Internal: Garrison helpers

zbujb_assert_shell_letter() {
  local -r z_letter="${1:-}"
  case "${z_letter}" in
    b|c|w) ;;
    *) buc_die "Invalid shell-letter (expected b/c/w): '${z_letter}'" ;;
  esac
}

# zbujb_garrison_assert_platform LETTER -- assert BURN_PLATFORM
# matches the shell-letter's required platform set.
zbujb_garrison_assert_platform() {
  zbujb_sentinel
  local -r z_letter="${1:-}"
  zbujb_assert_shell_letter "${z_letter}"
  case "${z_letter}" in
    b)
      case "${BURN_PLATFORM}" in
        bunne_linux|bunne_mac) ;;
        *) buc_die "garrison-b requires bunne_linux or bunne_mac, got '${BURN_PLATFORM}'" ;;
      esac
      ;;
    c|w)
      test "${BURN_PLATFORM}" = "bunne_windows" \
        || buc_die "garrison-${z_letter} requires bunne_windows, got '${BURN_PLATFORM}'"
      ;;
  esac
}

# zbujb_workload_home_capture LETTER -- emit the absolute workload home path
# on the remote node for the given shell-letter. _capture form per BCG line
# 502; returns 1 on unsupported platform or invalid letter, callers must
# `|| buc_die`.
zbujb_workload_home_capture() {
  zbujb_sentinel
  local -r z_letter="${1:-}"
  case "${z_letter}" in
    b)
      case "${BURN_PLATFORM}" in
        bunne_linux) echo "${BUJB_path_posix_user_home}" ;;
        bunne_mac)   echo "${BUJB_path_mac_user_home}"   ;;
        *)           return 1 ;;
      esac
      ;;
    c|w) echo "${BUJB_path_posix_user_home}" ;;
    *)   return 1 ;;
  esac
}

# zbujb_admin_exec_{native,cygwin,wsl} CHIT STMT -- run a single bash
# statement as the privileged user on the remote node, in the named
# shell environment. Variant functions per platform (no cryptic letter
# parameter): the call site picks the shell by name, and the function
# selects the matching remote invoker (`bash`, cygwin's bash --login,
# or wsl.exe ... bash). Embedded " characters are escaped to \" so the
# outer "..." of `bash -c "..."` survives the cmd.exe / Windows
# argv-parser layer (relevant for cygwin/wsl variants via Windows
# OpenSSH).
#
# Single-statement contract per WSG SH-10: STMT must be exactly one of
# (1) one simple command with arguments and redirections, (2) one pipeline
# optionally preceded by `set -o pipefail`, or (3) one simple command
# whose argument is itself an inner-shell body. Multi-statement work
# decomposes into multiple round-trips per the Capture-Decide-Dispatch
# pattern; bash on the curia owns the state machine.
#
# Caller may pipe stdin into any variant (e.g.
#   `zbujb_admin_exec_native CHIT "install ... /dev/stdin '<target>'" < <file>`)
# — bash redirection attaches the file to FD 0, ssh inherits it, sshd
# forwards it to the remote command's FD 0, the body's single command
# reads from /dev/stdin. Used by garrison step5 to plant the workload
# key without ever materializing the plaintext on either side's disk.
#
# stdout/stderr land at indexed paths exposed via ZBUJB_LAST_AP_STDOUT /
# _STDERR (the same shared CHIT-capture pattern as the PowerShell
# helpers); returns ssh exit code. These functions do NOT transform $.
# Body authors are responsible for per-shell $-escape discipline (see
# WSG SH-6: only the wsl variant's bodies need `\$name` escaping).
zbujb_admin_exec_native() {
  zbujb_admin_exec_impl 'bash' "$@"
}

zbujb_admin_exec_cygwin() {
  zbujb_admin_exec_impl "${BUJB_path_cygwin_root_fwd}/bin/bash --login" "$@"
}

zbujb_admin_exec_wsl() {
  zbujb_admin_exec_impl "wsl.exe --distribution ${BUJB_wsl_distribution} --user root bash" "$@"
}

# zbujb_admin_exec_impl REMOTE_INVOKER CHIT STMT -- shared body for the
# three zbujb_admin_exec_{native,cygwin,wsl} variants. Not called
# directly by step code; callers always go through one of the named
# variants so the call site declares its target shell.
zbujb_admin_exec_impl() {
  zbujb_sentinel
  local -r z_remote_invoker="${1:-}"
  test -n "${z_remote_invoker}" \
    || buc_die "zbujb_admin_exec_impl: REMOTE_INVOKER required (call via zbujb_admin_exec_{native,cygwin,wsl})"
  shift
  test $# -eq 2 \
    || buc_die "zbujb_admin_exec_*: requires CHIT STMT (got $# args); decompose multi-statement work via Capture-Decide-Dispatch per WSG SH-10"
  local -r z_chit="$1"
  local -r z_body="$2"

  # Escape " → \" for the cmd.exe / Windows argv-parser layer.
  local -r z_body_escaped="${z_body//\"/\\\"}"

  zbujb_chit_open "${z_chit}"
  local z_exit=0
  ssh -i "${BURP_PRIVILEGED_KEY_FILE}"        \
      "${ZBUJB_SSH_BASE_ARGS[@]}"             \
      -o "${BUJB_ssh_opt_batchmode_yes}"      \
      -o "${BUJB_ssh_opt_connecttimeout_15}"  \
      "${BURP_PRIVILEGED_USER}@${BURN_HOST}"  \
      "${z_remote_invoker} -c \"${z_body_escaped}\"" \
      > "${ZBUJB_LAST_AP_STDOUT}" \
      2> "${ZBUJB_LAST_AP_STDERR}" \
    || z_exit=$?
  zbujb_diag_dump_pair "${z_chit}" "${ZBUJB_LAST_AP_STDOUT}" "${ZBUJB_LAST_AP_STDERR}"
  return ${z_exit}
}

# zbujb_chit_open CHIT -- advance the shared emit counter and set
# ZBUJB_LAST_AP_STDOUT / ZBUJB_LAST_AP_STDERR to the indexed forensic
# capture paths for this call. Called by every interaction helper
# immediately before ssh. CHIT is a free-form fragment built by the call
# site as `${ZBUJB_CHIT_<group>}<label>-` (e.g.
# "${ZBUJB_CHIT_caparison}p1-sshd-read-").
zbujb_chit_open() {
  local -r z_chit="${1:-}"
  test -n "${z_chit}" \
    || buc_die "zbujb_chit_open: CHIT required"
  local z_idx_str
  zbujb_emit_index_advance z_idx_str
  ZBUJB_LAST_AP_STDOUT="${BURD_TEMP_DIR}/bujb_${z_chit}${z_idx_str}_stdout.txt"
  ZBUJB_LAST_AP_STDERR="${BURD_TEMP_DIR}/bujb_${z_chit}${z_idx_str}_stderr.txt"
}

# zbujb_admin_powershell CHIT BODY -- run a PowerShell statement chain on
# the remote node as the privileged user. Prepends discipline prelude:
# $ErrorActionPreference='Stop' (PS errors terminate), $env:WSL_UTF8=1
# (wsl.exe emits UTF-8), $LASTEXITCODE=0 (initialize so the trailing
# if-check doesn't trip on the $null default — $null -ne 0 evaluates True
# in PowerShell typed comparison, which would fire `exit $null` and
# discard buffered object-formatter output for cmdlets like Get-LocalUser
# whose tables haven't flushed to stdout yet). Trailing if-check
# propagates $LASTEXITCODE on non-zero from native commands in the body.
# stdout/stderr land at indexed paths exposed via ZBUJB_LAST_AP_STDOUT /
# _STDERR; a single-line diag preview is emitted via
# zbujb_diag_dump_pair after the call. Returns ssh's exit code.
zbujb_admin_powershell() {
  zbujb_sentinel
  test $# -ge 2 \
    || buc_die "zbujb_admin_powershell: CHIT BODY required"
  local -r z_chit="$1"; shift
  local -r z_body="$*"
  local -r z_body_escaped="${z_body//\"/\\\"}"   # WSp-109

  zbujb_chit_open "${z_chit}"
  local z_exit=0
  ssh -i "${BURP_PRIVILEGED_KEY_FILE}"        \
      "${ZBUJB_SSH_BASE_ARGS[@]}"             \
      -o "${BUJB_ssh_opt_batchmode_yes}"      \
      -o "${BUJB_ssh_opt_connecttimeout_15}"  \
      "${BURP_PRIVILEGED_USER}@${BURN_HOST}"  \
      "${BUJB_ps_invoke_command} \"${BUJB_ps_prelude} ${z_body_escaped}; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE }\"" \
      > "${ZBUJB_LAST_AP_STDOUT}" \
      2> "${ZBUJB_LAST_AP_STDERR}" \
    || z_exit=$?
  zbujb_diag_dump_pair "${z_chit}" "${ZBUJB_LAST_AP_STDOUT}" "${ZBUJB_LAST_AP_STDERR}"
  return ${z_exit}
}

# zbujb_admin_powershell_with_password_fallback CHIT BODY -- mirror of
# zbujb_admin_powershell but with BatchMode=no and
# PreferredAuthentications=publickey,password so ssh can fall through
# to a /dev/tty password prompt on first-caparison-ever when the admin
# pubkey is not yet authorized. The caparison process never sees the
# password; the prompt is handled by the operator's local ssh client.
# Bounded to a single call site: caparison-windows phase 1 step 3
# (admin pubkey install via single Add-Content) gated by the key-auth
# CDD probe; every other admin-shell op uses the key-only
# zbujb_admin_powershell. Same discipline prelude/postlude, same
# WSp-105 single-cmdlet body discipline, same WSp-109 escape transform,
# same internal forensic capture as zbujb_admin_powershell.
zbujb_admin_powershell_with_password_fallback() {
  zbujb_sentinel
  test $# -ge 2 \
    || buc_die "zbujb_admin_powershell_with_password_fallback: CHIT BODY required"
  local -r z_chit="$1"; shift
  local -r z_body="$*"
  local -r z_body_escaped="${z_body//\"/\\\"}"   # WSp-109

  zbujb_chit_open "${z_chit}"
  local z_exit=0
  ssh -i "${BURP_PRIVILEGED_KEY_FILE}"             \
      "${ZBUJB_SSH_BASE_ARGS[@]}"                  \
      -o BatchMode=no                              \
      -o PreferredAuthentications=publickey,password \
      -o "${BUJB_ssh_opt_connecttimeout_15}"       \
      "${BURP_PRIVILEGED_USER}@${BURN_HOST}"       \
      "${BUJB_ps_invoke_command} \"${BUJB_ps_prelude} ${z_body_escaped}; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE }\"" \
      > "${ZBUJB_LAST_AP_STDOUT}" \
      2> "${ZBUJB_LAST_AP_STDERR}" \
    || z_exit=$?
  zbujb_diag_dump_pair "${z_chit}" "${ZBUJB_LAST_AP_STDOUT}" "${ZBUJB_LAST_AP_STDERR}"
  return ${z_exit}
}

# zbujb_powershell_capture ROLE BODY -- run a single PS expression on the
# remote node as the named role and emit its stdout. Windows CR is stripped
# via bash parameter expansion (no subprocess) so $(...) yields a clean
# value. Single-expression discipline per WSG-PS-5; multi-statement bodies
# do not belong here. Caller || buc_die on capture failure.
# ROLE: zbujb_privileged | zbujb_workload
zbujb_powershell_capture() {
  zbujb_sentinel
  test $# -ge 2 \
    || buc_die "zbujb_powershell_capture: ROLE BODY required"
  local -r z_role="$1"; shift
  local -r z_body="$*"
  local -r z_body_escaped="${z_body//\"/\\\"}"   # WSp-109

  local z_key z_user
  case "${z_role}" in
    zbujb_privileged) z_key="${BURP_PRIVILEGED_KEY_FILE}"; z_user="${BURP_PRIVILEGED_USER}" ;;
    zbujb_workload)   z_key="${BURP_WORKLOAD_KEY_FILE}";   z_user="${BUJB_workload_user}"   ;;
    *)                buc_die "zbujb_powershell_capture: unknown role '${z_role}' (zbujb_privileged|zbujb_workload)" ;;
  esac

  local z_out z_exit=0
  z_out=$(ssh -i "${z_key}"                       \
              "${ZBUJB_SSH_BASE_ARGS[@]}"         \
              -o "${BUJB_ssh_opt_batchmode_yes}"  \
              -o "${BUJB_ssh_opt_connecttimeout_15}" \
              "${z_user}@${BURN_HOST}"            \
              "${BUJB_ps_invoke_command} \"${BUJB_ps_prelude} ${z_body_escaped}\"") \
    || z_exit=$?

  printf '%s' "${z_out//$'\r'/}"
  return "${z_exit}"
}

# zbujb_workload_ssh CHIT REMOTE_CMD -- execute a Windows-native command
# line as the workload user via SSH. The default Windows OpenSSH shell is
# cmd.exe; the command line goes through cmd.exe's argv layer to the named
# binary. Used by garrison-w for `wsl.exe --import` (which writes to the
# workload's HKCU\Lxss because the SSH session is a real workload logon)
# and `wsl.exe --distribution rbtww-main --user root bash -c "..."`
# invocations that follow the import. stdout/stderr land at indexed paths
# exposed via ZBUJB_LAST_AP_STDOUT / _STDERR (shared CHIT-capture pattern
# with the admin helpers); returns ssh's exit code.
zbujb_workload_ssh() {
  zbujb_sentinel
  test $# -ge 2 \
    || buc_die "zbujb_workload_ssh: CHIT REMOTE_CMD required"
  local -r z_chit="$1"; shift
  local -r z_remote_cmd="$*"

  zbujb_chit_open "${z_chit}"
  local z_exit=0
  ssh -i "${BURP_WORKLOAD_KEY_FILE}"       \
      "${ZBUJB_SSH_BASE_ARGS[@]}"          \
      -o "${BUJB_ssh_opt_batchmode_yes}"   \
      -o "${BUJB_ssh_opt_connecttimeout_15}" \
      "${BUJB_workload_user}@${BURN_HOST}" \
      "${z_remote_cmd}" \
      > "${ZBUJB_LAST_AP_STDOUT}" \
      2> "${ZBUJB_LAST_AP_STDERR}" \
    || z_exit=$?
  zbujb_diag_dump_pair "${z_chit}" "${ZBUJB_LAST_AP_STDOUT}" "${ZBUJB_LAST_AP_STDERR}"
  return ${z_exit}
}

######################################################################
# Internal: Garrison steps (6-step ceremony per BUSJG{B,C,W})

# Step 1 -- preflight gate. Subsumed by bujp_preflight (Tools/buk/bujp_preflight.sh).
# Garrison dispatcher calls bujp_preflight directly; no zbujb wrapper.

zbujb_diag_dump_pair() {
  local -r z_label="${1:-}"
  local -r z_stdout="${2:-}"
  local -r z_stderr="${3:-}"
  local z_out_bytes z_err_bytes z_out_preview z_err_preview
  z_out_bytes=$(wc -c < "${z_stdout}" | tr -d ' ')
  z_err_bytes=$(wc -c < "${z_stderr}" | tr -d ' ')
  z_out_preview=$(head -c 240 < "${z_stdout}" | tr -d '\r' | tr '\n' '|')
  z_err_preview=$(head -c 240 < "${z_stderr}" | tr -d '\r' | tr '\n' '|')
  buc_step "      [diag/${z_label}] stdout (${z_out_bytes}B): ${z_out_preview}"
  buc_step "      [diag/${z_label}] stderr (${z_err_bytes}B): ${z_err_preview}"
}

# zbujb_emit_index_advance OUT_REF -- validate the module-level
# z_bujb_emit_index counter is a non-negative integer, format it as %02d
# into OUT_REF via printf -v, then bump the counter. Called by
# zbujb_chit_open inside every interaction helper so format-and-bump is
# single-sourced. Dies on non-numeric counter (corruption guard) or
# missing OUT_REF.
zbujb_emit_index_advance() {
  local -r z_ref="${1:-}"
  test -n "${z_ref}" \
    || buc_die "zbujb_emit_index_advance: OUT_REF (caller var name) required"
  test "${z_bujb_emit_index:-x}" -ge 0 2>/dev/null \
    || buc_die "zbujb_emit_index_advance: z_bujb_emit_index is not a non-negative integer (got '${z_bujb_emit_index:-<unset>}')"
  printf -v "${z_ref}" '%02d' "${z_bujb_emit_index}"
  z_bujb_emit_index=$((z_bujb_emit_index + 1))
}

# zbujb_obliterate_windows_namespaces -- five-phase nuclear cleanup of
# every namespace a prior garrison of any letter could have populated for
# BUJB_workload_user. Each phase is a series of atomic admin SSH calls
# (one cmdlet or one native binary per body) tagged with the
# ${ZBUJB_CHIT_obliterate} fragment for per-call forensic capture.
# Capture-decide-dispatch: probes return state to bash; bash decides;
# destructive calls run unconditionally on the selected branch (no
# error-suppression-as-idempotency per WSp-108).
#
# Phase 1 - Release hives: wsl --shutdown host-wide, then CDD-conditional
#   Stop-Process for any wslhost/wslservice helpers still alive.
# Phase 2 - Win32_UserProfile destruction: WMI Filter matches canonical
#   profile dir AND .NNN numbered fallback dirs from prior demotions;
#   per-row Remove-CimInstance with -Query (single-cmdlet shape).
# Phase 3 - SAM scrub: Remove-LocalUser collapsed dispatch with
#   -ErrorAction SilentlyContinue, per WSG WSp-108 nuclear-cleanup
#   carve-out (narrow failure spectrum at SAM-database callsite;
#   downstream New-LocalUser catches silent partial cleanup).
# Phase 4 - Filesystem sweep: Get-ChildItem under C:\Users filtered by
#   workload prefix, bash-side tightening to exact-or-.NNN, then per-row
#   Remove-Item. Cygwin home: Test-Path + conditional Remove-Item
#   (arbitrary filesystem path; WSp-108 main rule, no carve-out).
# Phase 5 - WSL vestige inside admin's rbtww-main: userdel collapsed
#   dispatch with exit-code-6 tolerance (POSIX false-branches principle
#   from the orchestration-style memo; NOT WSp-108 since userdel is a
#   Linux native binary). Then unconditional rm -rf of /home/<user>
#   (rm -rf is idempotent on absent paths).
zbujb_obliterate_windows_namespaces() {
  zbujb_sentinel

  ##############
  # Phase 1 — Release hives

  buc_step "    [Phase 1] wsl --shutdown (release NTUSER.DAT hive handles)"
  zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p1-wsl-shutdown-" 'wsl.exe --shutdown' \
    || buc_die "obliterate phase 1: wsl --shutdown failed"

  buc_step "    [Phase 1] Probe WSL helper processes (wslhost,wslservice)"
  local z_helpers=""
  z_helpers=$(zbujb_powershell_capture zbujb_privileged \
      "Get-Process -Name wslhost,wslservice -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id") \
    || z_helpers=""
  if test -n "${z_helpers}"; then
    buc_step "    [Phase 1] Stop-Process wslhost,wslservice (PIDs present)"
    zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p1-stop-helpers-" 'Stop-Process -Name wslhost,wslservice -Force' \
      || buc_die "obliterate phase 1: Stop-Process wslhost,wslservice failed"
  fi

  ##############
  # Phase 2 — Win32_UserProfile destruction (canonical + numbered fallbacks)
  #
  # WMI Filter syntax: SQL-style LIKE with % wildcard. Exact-match for the
  # canonical path OR LIKE 'C:\Users\<user>.%' for prior-demotion fallbacks
  # named C:\Users\<user>.<host>.NNN.
  #
  # WQL backslash-escape: in WQL string literals (both LIKE patterns AND
  # equality comparisons), a single backslash is treated as the literal-
  # escape character; the path value must double each backslash or the
  # provider returns WBEM_E_INVALID_QUERY (0x80041017). Bash-side derives
  # z_canonical_wql / z_path_wql by replacing each `\` with `\\` before
  # injection into the filter string. The capture below treats a non-zero
  # ssh/PowerShell exit as fatal (not "no rows") to keep query breakage
  # from masquerading as a clean empty result.
  #
  # Hive-loaded precondition: Win32_UserProfile.Delete() (via Remove-
  # CimInstance) fails with "The process cannot access the file because
  # it is being used by another process" when the profile's NTUSER.DAT
  # is still mounted under HKEY_USERS\<SID>. The garrison-w prelude
  # (zbujb_reboot_and_await_ssh) reboots the host before reaching
  # obliterate, guaranteeing all workload hives are unmounted at this
  # point — no in-process unload remediation needed here.

  buc_step "    [Phase 2] Probe Win32_UserProfile rows"
  local z_canonical_win="C:\\Users\\${BUJB_workload_user}"
  local z_canonical_wql="${z_canonical_win//\\/\\\\}"
  local z_profiles_raw=""
  z_profiles_raw=$(zbujb_powershell_capture zbujb_privileged \
      "Get-CimInstance -ClassName Win32_UserProfile -Filter \"LocalPath = '${z_canonical_wql}' OR LocalPath LIKE '${z_canonical_wql}.%'\" | Select-Object -ExpandProperty LocalPath") \
    || buc_die "obliterate phase 2: Get-CimInstance Win32_UserProfile probe failed"

  local z_profiles_roll=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    test -n "${z_line}" || continue
    z_profiles_roll+=("${z_line}")
  done <<<"${z_profiles_raw}"

  local z_i=0
  local z_path="" z_path_wql=""
  for z_i in "${!z_profiles_roll[@]}"; do
    z_path="${z_profiles_roll[$z_i]}"
    z_path_wql="${z_path//\\/\\\\}"
    buc_step "    [Phase 2] Remove-CimInstance Win32_UserProfile LocalPath='${z_path}'"
    zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p2-remove-${z_i}-" \
        "Remove-CimInstance -Query \"SELECT * FROM Win32_UserProfile WHERE LocalPath = '${z_path_wql}'\"" \
      || buc_die "obliterate phase 2: Remove-CimInstance failed for ${z_path}"
  done

  ##############
  # Phase 3 — SAM scrub (Windows local user)
  #
  # Collapsed dispatch per WSG WSp-108 nuclear-cleanup carve-out: narrow
  # failure spectrum at this callsite (admin context, SAM database, fixed
  # workload user name); subsequent step's New-LocalUser provides the
  # downstream verification by erroring on "account already exists" if a
  # silent partial cleanup left a SID behind.

  buc_step "    [Phase 3] Remove-LocalUser ${BUJB_workload_user} (collapsed, -EAS)"
  zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p3-remove-localuser-" \
      "Remove-LocalUser -Name '${BUJB_workload_user}' -ErrorAction SilentlyContinue" \
    || buc_die "obliterate phase 3: SSH transport failed for Remove-LocalUser ${BUJB_workload_user}"

  ##############
  # Phase 4 — Filesystem sweep
  #
  # Get-ChildItem -Filter uses Windows-glob (only * and ?), which matches
  # any name beginning with the prefix — including unrelated accounts like
  # bujuw_user_alt. Bash-side tightens the result set to exact-canonical
  # OR canonical-dot-prefix (the .NNN demotion shape) before any Remove-Item.

  buc_step "    [Phase 4] Probe C:\\Users\\${BUJB_workload_user}* directories"
  local z_dirs_raw=""
  z_dirs_raw=$(zbujb_powershell_capture zbujb_privileged \
      "Get-ChildItem -Path 'C:\\Users' -Filter '${BUJB_workload_user}*' -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName") \
    || z_dirs_raw=""

  local z_dirs_roll=()
  local z_dot_prefix="${z_canonical_win}."
  while IFS= read -r z_line || test -n "${z_line}"; do
    test -n "${z_line}" || continue
    case "${z_line}" in
      "${z_canonical_win}")    z_dirs_roll+=("${z_line}") ;;
      "${z_dot_prefix}"*)      z_dirs_roll+=("${z_line}") ;;
    esac
  done <<<"${z_dirs_raw}"

  local z_dir=""
  for z_i in "${!z_dirs_roll[@]}"; do
    z_dir="${z_dirs_roll[$z_i]}"
    buc_step "    [Phase 4] Remove-Item -Recurse -Force ${z_dir}"
    zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p4-fsremove-${z_i}-" \
        "Remove-Item -Recurse -Force -LiteralPath '${z_dir}'" \
      || buc_die "obliterate phase 4: Remove-Item failed for ${z_dir}"
  done

  buc_step "    [Phase 4] Probe Cygwin home ${BUJB_path_cygwin_user_home}"
  local z_cyg=""
  z_cyg=$(zbujb_powershell_capture zbujb_privileged \
      "Test-Path '${BUJB_path_cygwin_user_home}'") \
    || buc_die "obliterate phase 4: Test-Path failed for ${BUJB_path_cygwin_user_home}"
  z_cyg="${z_cyg//[$'\r\n']/}"
  case "${z_cyg}" in
    True)
      buc_step "    [Phase 4] Remove Cygwin home ${BUJB_path_cygwin_user_home}"
      zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p4-cygwin-remove-" \
          "Remove-Item -Recurse -Force '${BUJB_path_cygwin_user_home}'" \
        || buc_die "obliterate phase 4: Remove-Item failed for ${BUJB_path_cygwin_user_home}"
      ;;
    False)
      ;;
    *)
      buc_die "obliterate phase 4: Test-Path returned unexpected '${z_cyg}' for ${BUJB_path_cygwin_user_home}"
      ;;
  esac

  ##############
  # Phase 5 — WSL vestige inside admin's rbtww-main
  #
  # Admin's rbtww-main was staged by caparison-windows phase 3 and is the
  # only WSL distribution where a prior garrison shape could have minted
  # a workload Linux user. Workload's own distribution lives in workload's
  # HKCU\Lxss (created later by zbujb_garrison_w_session_import) and is
  # not visible from admin's wsl.exe.
  #
  # Collapsed dispatch per the orchestration-style memo's POSIX
  # false-branches principle (NOT WSp-108 — userdel is a Linux native
  # binary, not a PowerShell destructive cmdlet). userdel returns exit
  # code 6 when the target user is absent; we accept 6 as no-op. Any
  # other non-zero exit is fatal. rm -rf is idempotent on absent paths
  # and runs unconditionally.

  buc_step "    [Phase 5] wsl userdel ${BUJB_workload_user} (exit 6 = absent, treated as no-op)"
  local z_userdel_exit=0
  zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p5-wsl-userdel-" \
      "wsl.exe --distribution ${BUJB_wsl_distribution} --user root userdel ${BUJB_workload_user}" \
    || z_userdel_exit=$?
  if test "${z_userdel_exit}" -ne 0 && test "${z_userdel_exit}" -ne 6; then
    buc_die "obliterate phase 5: wsl userdel returned exit ${z_userdel_exit} (acceptable: 0 or 6) for ${BUJB_workload_user}"
  fi

  buc_step "    [Phase 5] wsl rm -rf ${BUJB_path_posix_user_home} (idempotent on absent)"
  zbujb_admin_powershell "${ZBUJB_CHIT_obliterate}p5-wsl-rm-home-" \
      "wsl.exe --distribution ${BUJB_wsl_distribution} --user root rm -rf ${BUJB_path_posix_user_home}" \
    || buc_die "obliterate phase 5: wsl rm -rf failed for ${BUJB_path_posix_user_home}"
}

# zbujb_reboot_and_await_ssh -- force a Windows host reboot via privileged
# SSH, then poll for SSH reachability until the host returns. Guarantees a
# clean HKEY_USERS / hive-mount baseline for subsequent destructive admin
# operations (specifically obliterate Phase 2 Win32_UserProfile delete,
# which fails with "file in use by another process" when a workload hive
# is sticky-loaded from a prior SSH-as-workload session). Reboot is the
# canonical Windows state-reset primitive — preferred over handle-hunt /
# UserProfileSvc-cycle remediation because it is undocumented-internals-
# free and 100% reliable as long as the host boots.
#
# Preconditions (all guaranteed by caparison-windows on this BURN node):
#   - sshd is a Windows service starting at boot.
#   - Tailscale service StartType=Automatic (BURN_HOST resolves on Tailnet
#     after reboot without operator action).
#   - administrators_authorized_keys + sshd_config Match block survive
#     reboot (they live in C:\ProgramData\ssh).
#
# Mechanism: capture LastBootUpTime, issue Restart-Computer -Force (SSH
# session drops; non-zero exit absorbed), poll SSH with ConnectTimeout=5
# every 7 seconds up to a 10-minute cap (generous to tolerate pending
# Windows updates), then verify LastBootUpTime advanced (catches the
# "reboot did not fire" case — Group Policy block, pending operations,
# etc.).
zbujb_reboot_and_await_ssh() {
  zbujb_sentinel

  buc_step "  Reboot host ${BURN_HOST} (unconditional clean-baseline precondition)"

  local z_pre_boot=""
  z_pre_boot=$(zbujb_powershell_capture zbujb_privileged \
      "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('o')") \
    || buc_die "reboot: pre-reboot LastBootUpTime probe failed on ${BURN_HOST}"
  buc_step "    Pre-reboot LastBootUpTime: ${z_pre_boot}"

  # Explicit cold restart via shutdown.exe /full /r /f /t 0:
  #   /full — bypass Fast Startup (documented hatch; redundant on /r
  #           today but robust to future Windows default changes).
  #   /r    — restart (not shutdown-and-power-off).
  #   /f    — force-close apps with no prompt.
  #   /t 0  — zero-second countdown.
  # WSp-108 exception: successful shutdown.exe manifests as a connection
  # drop (ssh returns 255 mid-command), so the dispatch's non-zero exit
  # is not load-bearing. The downstream LastBootUpTime advance check is
  # the concrete end-state verification — a host that silently failed to
  # reboot will be caught there, not here.
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}reboot-shutdown-" "shutdown.exe /full /r /f /t 0" || true

  buc_step "    Polling for SSH return (cap: ${BUJB_reboot_poll_cap_s}s, interval: ${BUJB_reboot_poll_interval_s}s)"
  local z_attempt=0
  local -r z_max_attempts=$(( BUJB_reboot_poll_cap_s / BUJB_reboot_poll_interval_s ))
  while [[ "${z_attempt}" -lt "${z_max_attempts}" ]]; do
    z_attempt=$((z_attempt + 1))
    if ssh -i "${BURP_PRIVILEGED_KEY_FILE}"             \
           "${ZBUJB_SSH_BASE_ARGS[@]}"                  \
           -o "${BUJB_ssh_opt_batchmode_yes}"           \
           -o "${BUJB_ssh_opt_connecttimeout_5}"        \
           "${BURP_PRIVILEGED_USER}@${BURN_HOST}"       \
           "exit 0" > /dev/null 2>&1; then
      break
    fi
    sleep "${BUJB_reboot_poll_interval_s}"
  done
  test "${z_attempt}" -lt "${z_max_attempts}" \
    || buc_die "reboot: SSH did not return within ${BUJB_reboot_poll_cap_s}s on ${BURN_HOST} (host stuck on updates? boot failed? check console)"

  buc_step "    SSH back at attempt ${z_attempt} (~$(( z_attempt * BUJB_reboot_poll_interval_s ))s)"

  local z_post_boot=""
  z_post_boot=$(zbujb_powershell_capture zbujb_privileged \
      "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('o')") \
    || buc_die "reboot: post-reboot LastBootUpTime probe failed on ${BURN_HOST}"

  test "${z_pre_boot}" != "${z_post_boot}" \
    || buc_die "reboot: LastBootUpTime unchanged (${z_pre_boot}) on ${BURN_HOST} — Restart-Computer did not fire (Group Policy / pending operations?)"

  buc_step "    Post-reboot LastBootUpTime: ${z_post_boot}"
}

# zbujb_obliterate_workload -- letter-agnostic, platform-dispatched destroy
# helper. Single greppable verb covering every namespace a prior garrison
# of any letter could have populated. Idempotent on absent state at every
# step; (letter, platform) compatibility is asserted by garrison entry, so
# the helper dispatches on BURN_PLATFORM alone.
#
# Windows scope (one PowerShell session per atomic operation):
#   - Windows SAM entry (Remove-LocalUser if Get-LocalUser found it)
#   - C:\Users\<user>\ Windows profile directory (Remove-Item if Test-Path)
#   - C:\cygwin64\home\<user>\ Cygwin home (Remove-Item if Test-Path)
#   - WSL-side /home/<user> via wsl.exe userdel -r (gated on rbtww-main
#     present and getent passwd hit). Decisions live bash-side; PS is
#     atomic. See zbujb_obliterate_windows_namespaces.
# Linux scope: native userdel -r and home purge.
# Mac scope: sysadminctl -deleteUser and home purge.
zbujb_obliterate_workload() {
  zbujb_sentinel
  buc_step "  [2/6] Obliterate workload (${BUJB_workload_user}) on ${BURN_PLATFORM}"

  case "${BURN_PLATFORM}" in
    bunne_linux)
      # CDD via per-call CHIT capture inside zbujb_admin_exec_native: each
      # call lands at ${BURD_TEMP_DIR}/bujb_obliterate-<label>-<idx>_*.txt;
      # no inline redirection, no `|| true` (BCG-forbidden silent
      # absorption), no body-side `2>/dev/null`.
      local z_present=0
      zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}user-probe-" \
          "id '${BUJB_workload_user}'" || z_present=$?
      if test "${z_present}" -eq 0; then
        zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}userdel-" \
            "sudo -n userdel -r '${BUJB_workload_user}'" \
          || buc_die "obliterate (b/linux): userdel failed for ${BUJB_workload_user} — see ${ZBUJB_LAST_AP_STDERR}"
      fi
      z_present=0
      zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}home-probe-" \
          "test -d '${BUJB_path_posix_user_home}'" || z_present=$?
      if test "${z_present}" -eq 0; then
        zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}rm-home-" \
            "sudo -n rm -rf '${BUJB_path_posix_user_home}'" \
          || buc_die "obliterate (b/linux): rm -rf of ${BUJB_path_posix_user_home} failed — see ${ZBUJB_LAST_AP_STDERR}"
      fi
      ;;
    bunne_mac)
      local z_present=0
      zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}user-probe-" \
          "id '${BUJB_workload_user}'" || z_present=$?
      if test "${z_present}" -eq 0; then
        zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}userdel-" \
            "sudo -n sysadminctl -deleteUser '${BUJB_workload_user}'" \
          || buc_die "obliterate (b/mac): sysadminctl -deleteUser failed for ${BUJB_workload_user} — see ${ZBUJB_LAST_AP_STDERR}"
      fi
      z_present=0
      zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}home-probe-" \
          "test -d '${BUJB_path_mac_user_home}'" || z_present=$?
      if test "${z_present}" -eq 0; then
        zbujb_admin_exec_native "${ZBUJB_CHIT_obliterate}rm-home-" \
            "sudo -n rm -rf '${BUJB_path_mac_user_home}'" \
          || buc_die "obliterate (b/mac): rm -rf of ${BUJB_path_mac_user_home} failed — see ${ZBUJB_LAST_AP_STDERR}"
      fi
      ;;
    bunne_windows)
      zbujb_obliterate_windows_namespaces
      ;;
    *)
      buc_die "obliterate: unsupported BURN_PLATFORM '${BURN_PLATFORM}'"
      ;;
  esac
}

# Step 3 -- create the workload account fresh, ssh-only, no privilege.
zbujb_garrison_step3_create() {
  local -r z_letter="${1:-}"
  buc_step "  [3/6] Create workload (${BUJB_workload_user})"

  case "${z_letter}" in
    b)
      case "${BURN_PLATFORM}" in
        bunne_linux)
          zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}3-linux-useradd-" \
              "sudo -n useradd ${BUJB_useradd_workload_args} '${BUJB_workload_user}'" \
            || buc_die "step3 (b/linux): useradd failed for ${BUJB_workload_user}"
          zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}3-linux-passwd-lock-" \
              "sudo -n passwd --lock '${BUJB_workload_user}'" \
            || buc_die "step3 (b/linux): passwd --lock failed for ${BUJB_workload_user}"
          ;;
        bunne_mac)
          # Mac uses dscl/sysadminctl; left for in-environment refinement.
          # Operator may need to seat a more idiomatic primary group ID.
          zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}3-mac-adduser-" \
              "sudo -n sysadminctl -addUser '${BUJB_workload_user}' -roleAccount" \
            || buc_die "step3 (b/mac): sysadminctl -addUser failed for ${BUJB_workload_user}"
          zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}3-mac-dscl-shell-" \
              "sudo -n dscl . -create '${BUJB_path_mac_user_home}' UserShell ${BUJB_shell_bash}" \
            || buc_die "step3 (b/mac): dscl UserShell create failed for ${BUJB_path_mac_user_home}"
          ;;
      esac
      ;;
    c)
      # Cygwin reflects Windows user accounts; mint via net.exe with a
      # disabled-password posture (we want ssh-key-only).
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}3-c-netuser-add-" \
          "net.exe user '${BUJB_workload_user}' ${BUJB_netuser_add_args} > /dev/null" \
        || buc_die "step3 (c): net.exe user /add failed for ${BUJB_workload_user}"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}3-c-mkpasswd-" \
          "mkpasswd -l -u '${BUJB_workload_user}' >> /etc/passwd" \
        || buc_die "step3 (c): mkpasswd append to /etc/passwd failed for ${BUJB_workload_user}"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}3-c-mkdir-home-" \
          "mkdir -p '${BUJB_path_posix_user_home}'" \
        || buc_die "step3 (c): mkdir of ${BUJB_path_posix_user_home} failed"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}3-c-chown-home-" \
          "chown -R '${BUJB_workload_user}' '${BUJB_path_posix_user_home}'" \
        || buc_die "step3 (c): chown of ${BUJB_path_posix_user_home} failed"
      ;;
    w)
      # Windows-side workload account only. The WSL-side Linux user is
      # provisioned later inside the workload's own imported rbtww-main
      # distribution by zbujb_garrison_w_session_useradd.
      #
      # No ProfileList registry write: absolute-path AuthorizedKeysFile
      # (caparison-installed Match User block) decouples auth from
      # workload-profile state. The workload's first SSH session
      # (zbujb_garrison_w_session_import) creates the profile naturally
      # via User Profile Service.
      zbujb_admin_exec_wsl "${ZBUJB_CHIT_garrison_step}3-w-netuser-add-" \
          "net.exe user '${BUJB_workload_user}' ${BUJB_netuser_add_args} > /dev/null" \
        || buc_die "step3 (w): net.exe user /add failed for ${BUJB_workload_user}"
      ;;
  esac
}

# Step 4 -- write workload authorized_keys with the shell-letter command=
# directive and the workload pubkey (derived locally from the privkey).
zbujb_garrison_step4_place_trust() {
  local -r z_letter="${1:-}"
  case "${z_letter}" in
    b|c) ;;
    *)   buc_die "step4_place_trust: letter must be b or c (got '${z_letter}'); w letter uses zbujb_garrison_w_place_bare_trust" ;;
  esac

  local z_wlhome
  z_wlhome=$(zbujb_workload_home_capture "${z_letter}") \
    || buc_die "step4: workload home unresolvable for letter='${z_letter}' platform='${BURN_PLATFORM}'"

  local -r z_authkeys_dir="${z_wlhome}/${BUJB_path_dotssh}"
  buc_step "  [4/6] Place workload trust (${z_authkeys_dir}/${BUJB_authkeys_basename})"

  local z_command_directive
  z_command_directive=$(bujb_command_for_capture "${z_letter}") \
    || buc_die "step4: bujb_command_for_capture failed for letter='${z_letter}'"

  ${BUJB_sshkeygen_emit_pubkey} "${BURP_WORKLOAD_KEY_FILE}" \
      > "${ZBUJB_PUBKEY_STDOUT_WORK}" \
      2> "${ZBUJB_PUBKEY_STDERR_WORK}" \
    || buc_die "ssh-keygen -y failed for workload key: ${BURP_WORKLOAD_KEY_FILE} — see ${ZBUJB_PUBKEY_STDERR_WORK}"
  local z_pubkey
  z_pubkey=$(<"${ZBUJB_PUBKEY_STDOUT_WORK}")
  z_pubkey="${z_pubkey//$'\n'/}"

  local -r z_authkeys_line="${z_command_directive} ${z_pubkey}"$'\n'

  local z_sudo_prefix=""
  test "${z_letter}" != "b" || z_sudo_prefix="sudo -n "

  case "${z_letter}" in
    b)
      zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}4-b-mkdir-" \
          "${z_sudo_prefix}mkdir -p '${z_authkeys_dir}'" \
        || buc_die "step4 (b): mkdir of ${z_authkeys_dir} failed"
      zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}4-b-chmod-dir-" \
          "${z_sudo_prefix}chmod 700 '${z_authkeys_dir}'" \
        || buc_die "step4 (b): chmod 700 of ${z_authkeys_dir} failed"
      zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}4-b-write-authkeys-" \
          "echo '${z_authkeys_line}' | ${z_sudo_prefix}tee '${z_authkeys_dir}/${BUJB_authkeys_basename}' > /dev/null" \
        || buc_die "step4 (b): write to ${z_authkeys_dir}/${BUJB_authkeys_basename} failed"
      zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}4-b-chmod-file-" \
          "${z_sudo_prefix}chmod 600 '${z_authkeys_dir}/${BUJB_authkeys_basename}'" \
        || buc_die "step4 (b): chmod 600 of ${BUJB_authkeys_basename} failed"
      zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}4-b-chown-" \
          "${z_sudo_prefix}chown -R '${BUJB_workload_user}:${BUJB_workload_user}' '${z_authkeys_dir}'" \
        || buc_die "step4 (b): chown of ${z_authkeys_dir} failed"
      ;;
    c)
      # In Cygwin, file ownership/permissions interplay with NTFS ACLs.
      # mkdir/chmod/chown are Cygwin-mediated; run as the admin user
      # without sudo (Windows admins already have privilege).
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}4-c-mkdir-" \
          "mkdir -p '${z_authkeys_dir}'" \
        || buc_die "step4 (c): mkdir of ${z_authkeys_dir} failed"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}4-c-chmod-dir-" \
          "chmod 700 '${z_authkeys_dir}'" \
        || buc_die "step4 (c): chmod 700 of ${z_authkeys_dir} failed"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}4-c-write-authkeys-" \
          "echo '${z_authkeys_line}' > '${z_authkeys_dir}/${BUJB_authkeys_basename}'" \
        || buc_die "step4 (c): write to ${z_authkeys_dir}/${BUJB_authkeys_basename} failed"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}4-c-chmod-file-" \
          "chmod 600 '${z_authkeys_dir}/${BUJB_authkeys_basename}'" \
        || buc_die "step4 (c): chmod 600 of ${BUJB_authkeys_basename} failed"
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}4-c-chown-" \
          "chown -R '${BUJB_workload_user}' '${z_authkeys_dir}'" \
        || buc_die "step4 (c): chown of ${z_authkeys_dir} failed"
      ;;
  esac
}

# Step 5 -- copy workload privkey to the remote at the shell-letter's
# hardcoded destination path, with workload ownership and 0600 mode.
zbujb_garrison_step5_plant_key() {
  local -r z_letter="${1:-}"
  local z_wlhome
  z_wlhome=$(zbujb_workload_home_capture "${z_letter}") \
    || buc_die "step5: workload home unresolvable for letter='${z_letter}' platform='${BURN_PLATFORM}'"
  local -r z_target="${z_wlhome}/${BUJB_workload_keypath}"
  buc_step "  [5/6] Plant workload privkey (${z_target})"

  # Single ssh-stdin pipeline per shell (pace ₢A-AA9): the workload key
  # file flows from BURP_WORKLOAD_KEY_FILE on the curia, over ssh stdin
  # (FD 0), into the remote shell, into install's /dev/stdin, and lands
  # at z_target with mode + owner atomically set by install -D. No
  # plaintext on either side's disk; no remote temp file, trap, or
  # mktemp; no curia-side base64 encode; no key material in argv.
  # See WSG SH-10 for the single-statement-body contract.
  case "${z_letter}" in
    b)
      # Linux/Mac: privileged user needs sudo to write into workload's
      # home; both -o and -g supplied because useradd auto-mints a
      # self-named primary group on Linux/Mac.
      zbujb_admin_exec_native "${ZBUJB_CHIT_garrison_step}5-b-install-" \
          "sudo -n install -D -m 600 -o '${BUJB_workload_user}' -g '${BUJB_workload_user}' ${BUJB_path_devstdin} '${z_target}'" \
          < "${BURP_WORKLOAD_KEY_FILE}" \
        || buc_die "step5 (b): failed to plant workload key at ${z_target}"
      ;;
    w)
      # WSL: wsl.exe --user root provides root inside the distribution,
      # no sudo needed. -o and -g supplied (WSL distro is Linux-flavoured;
      # useradd inside it mints a self-named group).
      zbujb_admin_exec_wsl "${ZBUJB_CHIT_garrison_step}5-w-install-" \
          "install -D -m 600 -o '${BUJB_workload_user}' -g '${BUJB_workload_user}' ${BUJB_path_devstdin} '${z_target}'" \
          < "${BURP_WORKLOAD_KEY_FILE}" \
        || buc_die "step5 (w): failed to plant workload key at ${z_target}"
      ;;
    c)
      # Cygwin: privileged user is a Windows admin; chown works via NTFS
      # ACL without sudo. -g omitted because Windows accounts (minted via
      # net.exe user /add) do not get an auto-self-named group; passing
      # -g '${BUJB_workload_user}' would fail.
      zbujb_admin_exec_cygwin "${ZBUJB_CHIT_garrison_step}5-c-install-" \
          "install -D -m 600 -o '${BUJB_workload_user}' ${BUJB_path_devstdin} '${z_target}'" \
          < "${BURP_WORKLOAD_KEY_FILE}" \
        || buc_die "step5 (c): failed to plant workload key at ${z_target}"
      ;;
  esac
}

# zbujb_garrison_w_preflight -- migrated to bujp_preflight.sh as
# zbujp_probe_wsl_distribution. Garrison dispatcher invokes bujp_preflight
# at step 1; the WSL distribution presence check is the w-letter branch.

# zbujb_garrison_w_place_bare_trust -- write a bare workload pubkey entry
# (no command= directive) to the admin-owned absolute-path workload
# authorized_keys file. The path lives outside the workload profile;
# caparison-windows provisioned the parent directory with admins+SYSTEM
# FullControl ACL and installed the sshd_config Match User block that
# routes lookup here. This file is admin-owned throughout its lifetime;
# zbujb_garrison_w_lockdown_rewrite later replaces this bare content with
# the locked-down command= form, also from admin context.
#
# The bare form (no command= directive) is required because the four
# workload SSH sessions (import / useradd / privkey / shutdown) run
# arbitrary wsl.exe invocations, not the wsl-exec command= wrapper.
zbujb_garrison_w_place_bare_trust() {
  zbujb_sentinel
  buc_step "  [w-place-bare-trust] Write bare workload pubkey to absolute-path authorized_keys"

  ${BUJB_sshkeygen_emit_pubkey} "${BURP_WORKLOAD_KEY_FILE}" \
      > "${ZBUJB_PUBKEY_STDOUT_WORK}" \
      2> "${ZBUJB_PUBKEY_STDERR_WORK}" \
    || buc_die "w-place-bare-trust: ssh-keygen -y failed — see ${ZBUJB_PUBKEY_STDERR_WORK}"
  local z_pubkey=""
  z_pubkey=$(<"${ZBUJB_PUBKEY_STDOUT_WORK}")
  z_pubkey="${z_pubkey//$'\n'/}"

  # Base64-transport the pubkey bytes for argv-layer safety, then a single
  # PS WriteAllBytes call decodes and writes atomically. The path is built
  # at PS evaluation time via $env:ProgramData + suffix; caparison-windows
  # provisioned the parent directory.
  printf '%s\n' "${z_pubkey}"                                \
      | openssl enc -base64 -A                               \
          > "${ZBUJB_AUTHKEYS_B64_STDOUT}"                   \
          2> "${ZBUJB_AUTHKEYS_B64_STDERR}"                  \
    || buc_die "w-place-bare-trust: base64 encode failed — see ${ZBUJB_AUTHKEYS_B64_STDERR}"
  local z_b64=""
  z_b64=$(<"${ZBUJB_AUTHKEYS_B64_STDOUT}")
  z_b64="${z_b64//$'\n'/}"

  zbujb_admin_powershell "${ZBUJB_CHIT_w_init}place-bare-trust-" \
      "[System.IO.File]::WriteAllBytes((\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}\\authorized_keys'), [System.Convert]::FromBase64String('${z_b64}'))" \
    || buc_die "w-place-bare-trust: failed to write bare authorized_keys"
}

# zbujb_garrison_w_export_seed -- export admin's BUJB_wsl_distribution to
# the workload-readable seed path. Runs from admin context. The tarball
# is consumed by the workload's wsl --import in
# zbujb_garrison_w_session_import; zbujb_garrison_w_seed_cleanup removes
# it after.
zbujb_garrison_w_export_seed() {
  zbujb_sentinel
  buc_step "  [w-export-seed] Export admin's ${BUJB_wsl_distribution} to ${BUJB_path_win_seed_tarball}"

  zbujb_admin_powershell "${ZBUJB_CHIT_w_init}wsl-export-" \
      "wsl.exe --export ${BUJB_wsl_distribution} '${BUJB_path_win_seed_tarball}'" \
    || buc_die "w-export-seed: wsl --export failed (admin's ${BUJB_wsl_distribution} not exportable?) — see ${ZBUJB_LAST_AP_STDERR}"
}

# zbujb_garrison_w_session_import -- workload SSH session 1 of 4. Imports
# rbtww-main into workload's HKCU\Lxss from the seed tarball.
#
# WSG-strict (single cmdlet / native binary per body) requires this and
# the next three operations to be separate SSH sessions; each session is
# one wsl.exe call. The BUSJGW "single workload SSH session" objective is
# degraded to "minimum session count + final wsl --shutdown" — auth
# survival under demotion rests on caparison's absolute-path Match block
# (Layer 1) rather than on Layer 2 single-session.
zbujb_garrison_w_session_import() {
  zbujb_sentinel
  buc_step "  [w-session-1/4] wsl --import (registers rbtww-main in workload's HKCU\\Lxss)"

  zbujb_workload_ssh "${ZBUJB_CHIT_w_init}session-import-" \
      "wsl.exe --import ${BUJB_wsl_distribution} \"${BUJB_path_win_wsl_root}\" \"${BUJB_path_win_seed_tarball}\" --version 2" \
    || buc_die "w-session-import: wsl --import failed — see ${ZBUJB_LAST_AP_STDERR}"
}

# zbujb_garrison_w_session_useradd -- workload SSH session 2 of 4. Mints
# the inner Linux workload user. useradd creates a locked-by-default
# account (shadow entry '!') so no separate passwd --lock call is needed.
zbujb_garrison_w_session_useradd() {
  zbujb_sentinel
  buc_step "  [w-session-2/4] wsl useradd (locked by default per /etc/shadow convention)"

  zbujb_workload_ssh "${ZBUJB_CHIT_w_init}session-useradd-" \
      "wsl.exe --distribution ${BUJB_wsl_distribution} --user root useradd ${BUJB_useradd_workload_args} ${BUJB_workload_user}" \
    || buc_die "w-session-useradd: useradd failed inside workload's ${BUJB_wsl_distribution}"
}

# zbujb_garrison_w_session_privkey -- workload SSH session 3 of 4. Plants
# the workload privkey at /home/<user>/.ssh/id_ed25519 inside the
# workload's WSL distribution. Privkey flows: BURP_WORKLOAD_KEY_FILE on
# curia → ssh stdin (FD 0) → cmd.exe → wsl.exe → install -D /dev/stdin →
# target file with mode/owner set atomically. No plaintext on disk on
# either side; no key material in argv.
#
# install -D creates parent directories (the .ssh dir), so no separate
# mkdir step is required.
zbujb_garrison_w_session_privkey() {
  zbujb_sentinel
  buc_step "  [w-session-3/4] wsl install -D /dev/stdin (workload privkey)"

  zbujb_workload_ssh "${ZBUJB_CHIT_w_init}session-privkey-" \
      "wsl.exe --distribution ${BUJB_wsl_distribution} --user root install -D -m 600 -o ${BUJB_workload_user} -g ${BUJB_workload_user} ${BUJB_path_devstdin} ${BUJB_path_posix_user_home}/${BUJB_workload_keypath}" \
      < "${BURP_WORKLOAD_KEY_FILE}" \
    || buc_die "w-session-privkey: failed to plant workload privkey inside workload's ${BUJB_wsl_distribution}"
}

# zbujb_garrison_w_session_shutdown -- workload SSH session 4 of 4.
# Releases the WSL VM and its helper-process hive handles before the
# logon session terminates. Best-effort layer-2 defense against the
# bd0cf9ac demotion accumulation pattern.
zbujb_garrison_w_session_shutdown() {
  zbujb_sentinel
  buc_step "  [w-session-4/4] wsl --shutdown (release NTUSER.DAT hive handles before logon exit)"

  zbujb_workload_ssh "${ZBUJB_CHIT_w_init}session-shutdown-" \
      "wsl.exe --shutdown" \
    || buc_die "w-session-shutdown: wsl --shutdown failed — see ${ZBUJB_LAST_AP_STDERR}"
}

# zbujb_garrison_w_lockdown_rewrite -- admin overwrites the absolute-path
# workload authorized_keys with the locked-down command= form. Runs after
# the four workload sessions complete; subsequent operational workload
# SSH connections will be routed through the wsl.exe --user --exec wrapper.
zbujb_garrison_w_lockdown_rewrite() {
  zbujb_sentinel
  buc_step "  [w-lockdown-rewrite] Replace bare ${BUJB_authkeys_basename} with command= directive"

  local z_command_directive=""
  z_command_directive=$(bujb_command_for_capture w) \
    || buc_die "w-lockdown-rewrite: bujb_command_for_capture failed for letter='w'"

  ${BUJB_sshkeygen_emit_pubkey} "${BURP_WORKLOAD_KEY_FILE}" \
      > "${ZBUJB_PUBKEY_STDOUT_WORK}" \
      2> "${ZBUJB_PUBKEY_STDERR_WORK}" \
    || buc_die "w-lockdown-rewrite: ssh-keygen -y failed — see ${ZBUJB_PUBKEY_STDERR_WORK}"
  local z_pubkey=""
  z_pubkey=$(<"${ZBUJB_PUBKEY_STDOUT_WORK}")
  z_pubkey="${z_pubkey//$'\n'/}"

  printf '%s\n' "${z_command_directive} ${z_pubkey}"           \
      | openssl enc -base64 -A                                 \
          > "${ZBUJB_AUTHKEYS_B64_STDOUT}"                     \
          2> "${ZBUJB_AUTHKEYS_B64_STDERR}"                    \
    || buc_die "w-lockdown-rewrite: base64 encode failed — see ${ZBUJB_AUTHKEYS_B64_STDERR}"
  local z_b64=""
  z_b64=$(<"${ZBUJB_AUTHKEYS_B64_STDOUT}")
  z_b64="${z_b64//$'\n'/}"

  zbujb_admin_powershell "${ZBUJB_CHIT_w_init}lockdown-rewrite-" \
      "[System.IO.File]::WriteAllBytes((\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}\\authorized_keys'), [System.Convert]::FromBase64String('${z_b64}'))" \
    || buc_die "w-lockdown-rewrite: failed to overwrite ${BUJB_authkeys_basename} with command= form"
}

# zbujb_garrison_w_seed_cleanup -- admin removes the seed tarball. Runs
# after all four workload sessions complete; admin holds Administrators
# FullControl on C:\WSL.
zbujb_garrison_w_seed_cleanup() {
  zbujb_sentinel
  buc_step "  [w-seed-cleanup] Remove ${BUJB_path_win_seed_tarball}"

  # CDD: probe Test-Path then conditional Remove-Item. WSp-108 forbids
  # -ErrorAction SilentlyContinue on destructive ops.
  local z_present=""
  z_present=$(zbujb_powershell_capture zbujb_privileged \
      "Test-Path '${BUJB_path_win_seed_tarball}'") \
    || buc_die "w-seed-cleanup: Test-Path failed"
  z_present="${z_present//[$'\r\n']/}"
  case "${z_present}" in
    True)
      zbujb_admin_powershell "${ZBUJB_CHIT_w_init}seed-cleanup-" \
          "Remove-Item -Path '${BUJB_path_win_seed_tarball}' -Force" \
        || buc_die "w-seed-cleanup: Remove-Item failed for ${BUJB_path_win_seed_tarball}"
      ;;
    False)
      ;;
    *)
      buc_die "w-seed-cleanup: Test-Path returned unexpected '${z_present}'"
      ;;
  esac
}

######################################################################
# Public: Garrison ceremony

# bujb_garrison LETTER -- run the garrison ceremony for shell-letter b, c,
# or w. Caller must have invoked bujb_resolve_investiture beforehand.
# Round-trip validation is deferred to bujb_invigilate_windows for w (the
# workload round-trip exercises the caparison-installed Match block plus
# the lockdown_rewrite-installed command= directive — invigilate's full
# audit covers it as a post-completion fact).
bujb_garrison() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_garrison: call bujb_resolve_investiture first"

  local -r z_letter="${1:-}"
  zbujb_garrison_assert_platform "${z_letter}"

  buc_step "Garrison-${z_letter}: ${BUZ_FOLIO} (${BURN_HOST})"

  bujp_preflight                     "${z_letter}"

  # Reboot precondition (Windows only): guarantees a clean HKEY_USERS
  # baseline so obliterate Phase 2 Win32_UserProfile delete is not
  # blocked by a sticky-loaded workload hive from a prior SSH-as-
  # workload session. Reboot is the canonical Windows state-reset
  # primitive; see zbujb_reboot_and_await_ssh for the rationale.
  case "${BURN_PLATFORM}" in
    bunne_windows) zbujb_reboot_and_await_ssh ;;
  esac

  zbujb_obliterate_workload
  zbujb_garrison_step3_create        "${z_letter}"

  case "${z_letter}" in
    w)
      # Order is load-bearing:
      #   1. place_bare_trust BEFORE the workload sessions (each session
      #      authenticates against this file via caparison's Match block).
      #   2. export_seed BEFORE session_import (import consumes the seed).
      #   3. Four workload sessions in order (import → useradd → privkey →
      #      shutdown). Each one wsl.exe call; final shutdown releases
      #      hive handles before workload's Windows logon terminates.
      #   4. lockdown_rewrite AFTER the four sessions (subsequent workload
      #      SSH gets the command= form). Admin context, single Set/Write.
      #   5. seed_cleanup last (admin removes the tarball).
      zbujb_garrison_w_place_bare_trust
      zbujb_garrison_w_export_seed
      zbujb_garrison_w_session_import
      zbujb_garrison_w_session_useradd
      zbujb_garrison_w_session_privkey
      zbujb_garrison_w_session_shutdown
      zbujb_garrison_w_lockdown_rewrite
      zbujb_garrison_w_seed_cleanup
      ;;
    b|c)
      zbujb_garrison_step4_place_trust "${z_letter}"
      zbujb_garrison_step5_plant_key   "${z_letter}"
      ;;
  esac

  buc_step "Garrison-${z_letter} succeeded"
}

######################################################################
# Internal: Caparison-windows helpers (BUSJCW — Windows OpenSSH only)
#
# Phase 1 decomposes into 13 single-cmdlet steps per WSG WSp-105 bounded
# by a key-auth CDD probe: zbujb_admin_powershell 'exit 0' decides
# whether the bounded password-fallback Add-Content (step 3) runs via
# zbujb_admin_powershell_with_password_fallback or no-ops. Every other
# step is key-only via zbujb_admin_powershell. Phase 2 reconnects under
# key-only auth and re-verifies the served sshd_config. No
# ControlMaster, no traps, no 2>/dev/null.

# zbujb_caparison_windows_verify_directives REMOTE_FILE -- load REMOTE_FILE (raw
# sshd_config bytes from PowerShell Get-Content), strip CR, then assert
# each directive in BUJB_sshd_hardening appears with the expected value.
# Load-then-iterate (no nested while-read on stdin); pure parameter
# expansion + case (no awk/grep/tr).
zbujb_caparison_windows_verify_directives() {
  zbujb_sentinel
  local -r z_remote_file="${1:-}"
  test -n "${z_remote_file}" || buc_die "zbujb_caparison_windows_verify_directives: remote_file required"
  test -f "${z_remote_file}" || buc_die "zbujb_caparison_windows_verify_directives: remote_file not found: ${z_remote_file}"

  local -r z_raw_bytes=$(<"${z_remote_file}")
  test -n "${z_raw_bytes}" || buc_die "zbujb_caparison_windows_verify_directives: empty remote sshd_config bytes: ${z_remote_file}"
  local -r z_clean_bytes="${z_raw_bytes//$'\r'/}"

  local z_directives_roll=()
  local z_pair=""
  while IFS= read -r z_pair || test -n "${z_pair}"; do
    test -n "${z_pair}" || continue
    z_directives_roll+=("${z_pair}")
  done <<<"${BUJB_sshd_hardening}"

  local z_remote_lines_roll=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_remote_lines_roll+=("${z_line}")
  done <<<"${z_clean_bytes}"

  local z_directive=""
  local z_expected=""
  local z_actual=""
  local z_after_directive=""
  local z_i=0
  local z_j=0
  for z_i in "${!z_directives_roll[@]}"; do
    z_directive="${z_directives_roll[$z_i]%% *}"
    z_expected="${z_directives_roll[$z_i]#* }"
    z_actual=""

    for z_j in "${!z_remote_lines_roll[@]}"; do
      case "${z_remote_lines_roll[$z_j]}" in
        "${z_directive} "*)
          z_after_directive="${z_remote_lines_roll[$z_j]#"${z_directive} "}"
          z_actual="${z_after_directive%% *}"
          break
          ;;
      esac
    done

    test -n "${z_actual}" \
      || buc_die "Hardening verify: directive '${z_directive}' missing or commented in remote sshd_config"
    test "${z_actual}" = "${z_expected}" \
      || buc_die "Hardening verify: ${z_directive}: expected '${z_expected}', got '${z_actual}'"
  done
}

# zbujb_caparison_windows_verify_match_block REMOTE_FILE -- load raw sshd_config
# bytes from REMOTE_FILE and assert the canonical Match User block is present:
# the header line exactly matches "Match User ${BUJB_workload_user}", and the
# next non-blank line is the AuthorizedKeysFile directive resolving to
# ${BUJB_path_sshd_workload_authkeys}. Indentation on the AuthorizedKeysFile
# line is stripped before comparison (sshd accepts indented continuations).
# Failure pointer is BUSJCW (Match block is caparison-windows's deliverable);
# invigilate reuses this helper for its sshd-config-shape fact.
zbujb_caparison_windows_verify_match_block() {
  zbujb_sentinel
  local -r z_remote_file="${1:-}"
  test -n "${z_remote_file}" || buc_die "zbujb_caparison_windows_verify_match_block: remote_file required"
  test -f "${z_remote_file}" || buc_die "zbujb_caparison_windows_verify_match_block: remote_file not found: ${z_remote_file}"

  local -r z_raw_bytes=$(<"${z_remote_file}")
  test -n "${z_raw_bytes}" || buc_die "Match block verify: empty remote sshd_config bytes (see ${z_remote_file}) — caparison-windows (BUSJCW)"
  local -r z_clean_bytes="${z_raw_bytes//$'\r'/}"

  local z_lines_roll=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_lines_roll+=("${z_line}")
  done <<<"${z_clean_bytes}"

  local -r z_expected_header="Match User ${BUJB_workload_user}"
  local -r z_expected_akf="AuthorizedKeysFile ${BUJB_path_sshd_workload_authkeys}"

  local z_header_idx=-1
  local z_i=0
  for z_i in "${!z_lines_roll[@]}"; do
    test "${z_lines_roll[$z_i]}" = "${z_expected_header}" || continue
    z_header_idx="${z_i}"
    break
  done

  test "${z_header_idx}" -ge 0 \
    || buc_die "Match block verify: header '${z_expected_header}' missing from sshd_config (see ${z_remote_file}) — caparison-windows (BUSJCW)"

  # Find the next non-blank line after the header; strip leading whitespace
  # before comparing to z_expected_akf.
  local z_next_idx=$((z_header_idx + 1))
  local z_max="${#z_lines_roll[@]}"
  local z_candidate=""
  local z_stripped=""
  while test "${z_next_idx}" -lt "${z_max}"; do
    z_candidate="${z_lines_roll[$z_next_idx]}"
    z_stripped="${z_candidate#"${z_candidate%%[![:space:]]*}"}"
    test -z "${z_stripped}" || break
    z_next_idx=$((z_next_idx + 1))
  done

  test "${z_next_idx}" -lt "${z_max}" \
    || buc_die "Match block verify: header '${z_expected_header}' present but no AuthorizedKeysFile directive follows (see ${z_remote_file}) — caparison-windows (BUSJCW)"
  test "${z_stripped}" = "${z_expected_akf}" \
    || buc_die "Match block verify: AuthorizedKeysFile: expected '${z_expected_akf}', got '${z_stripped}' (see ${z_remote_file}) — caparison-windows (BUSJCW)"
}

######################################################################
# Internal: Caparison-windows phases

# zbujb_caparison_windows_phase1 -- 13 single-cmdlet steps per WSG WSp-105,
# bounded by a key-auth CDD probe so steady-state re-runs are key-only
# end-to-end and only first-caparison-ever issues a single TTY password
# prompt for the admin pubkey install (step 3). See BUSJCW for the
# axhos_step list and the per-step contract.
zbujb_caparison_windows_phase1() {
  zbujb_sentinel

  buc_step "  [Phase 1] [Step 1/13] Derive admin pubkey"
  ${BUJB_sshkeygen_emit_pubkey} "${BURP_PRIVILEGED_KEY_FILE}" \
      > "${ZBUJB_PUBKEY_STDOUT_PRIV}" \
      2> "${ZBUJB_PUBKEY_STDERR_PRIV}" \
    || buc_die "Phase 1 step 1: ssh-keygen -y failed for admin key: ${BURP_PRIVILEGED_KEY_FILE} — see ${ZBUJB_PUBKEY_STDERR_PRIV}"
  local z_pubkey
  z_pubkey=$(<"${ZBUJB_PUBKEY_STDOUT_PRIV}")
  z_pubkey="${z_pubkey//$'\n'/}"

  buc_step "  [Phase 1] [Step 2/13] Probe key-auth availability (non-fatal — both outcomes valid)"
  local z_key_auth_available="False"
  if zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-keyauth-probe-" 'exit 0'; then
    z_key_auth_available="True"
  fi
  buc_step "    Key auth available: ${z_key_auth_available}"

  if [[ "${z_key_auth_available}" == "False" ]]; then
    buc_step "  [Phase 1] [Step 3/13] Install admin pubkey via password-fallback Add-Content (operator may be prompted once for admin password)"
    zbujb_admin_powershell_with_password_fallback "${ZBUJB_CHIT_caparison}p1-install-admin-pubkey-" \
        "Add-Content -Path (\$env:ProgramData + '\\ssh\\administrators_authorized_keys') -Value '${z_pubkey}' -Encoding ASCII" \
      || buc_die "Phase 1 step 3: Add-Content for admin pubkey install failed (operator password rejected, write denied, or file locked)"
  else
    buc_step "  [Phase 1] [Step 3/13] Install admin pubkey: SKIP (key auth already works; pubkey by construction already authorized)"
  fi

  buc_step "  [Phase 1] [Step 4/13] icacls lockdown on administrators_authorized_keys"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-icacls-admin-authkeys-" \
      "icacls (\$env:ProgramData + '\\ssh\\administrators_authorized_keys') /inheritance:r /grant '${BUJB_acl_principal_system}:F' /grant '${BUJB_acl_principal_admins}:F'" \
    || buc_die "Phase 1 step 4: icacls on administrators_authorized_keys failed — subsequent key-auth ops would not authenticate"

  buc_step "  [Phase 1] [Step 5/13] Read current sshd_config"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-sshd-read-" \
      "Get-Content (\$env:ProgramData + '\\ssh\\sshd_config') -Raw" \
    || buc_die "Phase 1 step 5: Get-Content on sshd_config failed — see ${ZBUJB_LAST_AP_STDERR}"
  local -r z_sshd_current_stdout="${ZBUJB_LAST_AP_STDOUT}"

  buc_step "  [Phase 1] [Step 6/13] Build new sshd_config content (curia-side: replace hardening directives + strip prior Match block + append canonical Match block)"
  local z_current_raw=""
  z_current_raw=$(<"${z_sshd_current_stdout}")
  local z_current_clean="${z_current_raw//$'\r'/}"

  local z_directives_roll=()
  local z_pair=""
  while IFS= read -r z_pair || test -n "${z_pair}"; do
    test -n "${z_pair}" || continue
    z_directives_roll+=("${z_pair}")
  done <<<"${BUJB_sshd_hardening}"

  local z_current_lines_roll=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_current_lines_roll+=("${z_line}")
  done <<<"${z_current_clean}"

  local z_out_lines_roll=()
  local z_seen_roll=()
  local z_skip_block=0
  local z_i=0 z_j=0 z_k=0
  local z_directive="" z_value="" z_check="" z_first_word=""
  local z_is_directive=0 z_already_seen=0
  for z_i in "${!z_current_lines_roll[@]}"; do
    z_line="${z_current_lines_roll[$z_i]}"

    case "${z_line}" in
      "Match User ${BUJB_workload_user}")
        z_skip_block=1
        continue
        ;;
      "Match "*)
        z_skip_block=0
        ;;
    esac
    test "${z_skip_block}" -eq 1 && continue

    z_check="${z_line#"${z_line%%[![:space:]]*}"}"
    z_check="${z_check#\#}"
    z_check="${z_check#"${z_check%%[![:space:]]*}"}"
    z_first_word="${z_check%% *}"

    z_is_directive=0
    for z_j in "${!z_directives_roll[@]}"; do
      z_directive="${z_directives_roll[$z_j]%% *}"
      z_value="${z_directives_roll[$z_j]#* }"
      if [[ "${z_first_word}" == "${z_directive}" ]]; then
        z_already_seen=0
        for z_k in "${!z_seen_roll[@]}"; do
          test "${z_seen_roll[$z_k]}" = "${z_directive}" && { z_already_seen=1; break; }
        done
        if [[ "${z_already_seen}" -eq 0 ]]; then
          z_out_lines_roll+=("${z_directive} ${z_value}")
          z_seen_roll+=("${z_directive}")
        fi
        z_is_directive=1
        break
      fi
    done
    test "${z_is_directive}" -eq 1 && continue

    z_out_lines_roll+=("${z_line}")
  done

  for z_j in "${!z_directives_roll[@]}"; do
    z_directive="${z_directives_roll[$z_j]%% *}"
    z_value="${z_directives_roll[$z_j]#* }"
    local z_was_seen=0
    for z_k in "${!z_seen_roll[@]}"; do
      test "${z_seen_roll[$z_k]}" = "${z_directive}" && { z_was_seen=1; break; }
    done
    test "${z_was_seen}" -eq 0 && z_out_lines_roll+=("${z_directive} ${z_value}")
  done

  local z_new_sshd=""
  for z_line in "${z_out_lines_roll[@]}"; do
    z_new_sshd+="${z_line}"$'\n'
  done
  z_new_sshd+="${BUJB_sshd_match_block_text}"$'\n'

  buc_step "  [Phase 1] [Step 7/13] Write new sshd_config (base64 transport via WriteAllBytes)"
  printf '%s' "${z_new_sshd}" \
      | openssl enc -base64 -A \
        > "${ZBUJB_AUTHKEYS_B64_STDOUT}" \
        2> "${ZBUJB_AUTHKEYS_B64_STDERR}" \
    || buc_die "Phase 1 step 7: base64 encode of sshd_config failed — see ${ZBUJB_AUTHKEYS_B64_STDERR}"
  local z_sshd_b64=""
  z_sshd_b64=$(<"${ZBUJB_AUTHKEYS_B64_STDOUT}")
  z_sshd_b64="${z_sshd_b64//$'\n'/}"

  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-sshd-write-" \
      "[System.IO.File]::WriteAllBytes((\$env:ProgramData + '\\ssh\\sshd_config'), [System.Convert]::FromBase64String('${z_sshd_b64}'))" \
    || buc_die "Phase 1 step 7: WriteAllBytes on sshd_config failed — restart would still serve unhardened auth"

  buc_step "  [Phase 1] [Step 8/13] Provision workload authkeys parent directory (CDD)"
  local z_dir_present=""
  z_dir_present=$(zbujb_powershell_capture zbujb_privileged \
      "Test-Path (\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}')") \
    || buc_die "Phase 1 step 8: Test-Path on workload authkeys directory failed"
  z_dir_present="${z_dir_present//[$'\r\n']/}"
  case "${z_dir_present}" in
    True)
      buc_step "    Workload authkeys directory already present"
      ;;
    False)
      buc_step "    Creating workload authkeys directory"
      zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-mkdir-authkeys-dir-" \
          "New-Item -ItemType Directory -Path (\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}') -Force | Out-Null" \
        || buc_die "Phase 1 step 8: New-Item on workload authkeys directory failed — workload auth path would not resolve"
      ;;
    *)
      buc_die "Phase 1 step 8: Test-Path returned unexpected '${z_dir_present}' for workload authkeys directory"
      ;;
  esac

  buc_step "  [Phase 1] [Step 9/13] icacls lockdown on workload authkeys directory"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-icacls-authkeys-dir-" \
      "icacls (\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}') /inheritance:r /grant '${BUJB_acl_principal_system}:F' /grant '${BUJB_acl_principal_admins}:F'" \
    || buc_die "Phase 1 step 9: icacls on workload authkeys directory failed — sshd would refuse the workload trust file"

  buc_step "  [Phase 1] [Step 10/13] Validate sshd_config (sshd -t)"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-sshd-t-" \
      "& 'C:\\Windows\\System32\\OpenSSH\\sshd.exe' -t" \
    || buc_die "Phase 1 step 10: sshd -t failed — config malformed; aborting preserves running sshd"

  buc_step "  [Phase 1] [Step 11/13] Re-read sshd_config (post-write)"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-sshd-verify-" \
      "Get-Content (\$env:ProgramData + '\\ssh\\sshd_config') -Raw" \
    || buc_die "Phase 1 step 11: Get-Content on sshd_config (verify pass) failed — see ${ZBUJB_LAST_AP_STDERR}"
  local -r z_sshd_verify_stdout="${ZBUJB_LAST_AP_STDOUT}"

  buc_step "  [Phase 1] [Step 12/13] Verify hardened directives and Match block (curia-side)"
  zbujb_caparison_windows_verify_directives "${z_sshd_verify_stdout}"
  zbujb_caparison_windows_verify_match_block "${z_sshd_verify_stdout}"

  buc_step "  [Phase 1] [Step 13/13] Restart-Service sshd (disconnect expected — exit code absorbed; Phase 2 reconnect validates)"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}p1-restart-sshd-" \
      "Restart-Service sshd" \
    || true
}

# zbujb_caparison_windows_phase2 -- reconnect under key-only auth and
# re-verify the served sshd_config. The successful reconnect IS the
# proof of key-auth restoration after Phase 1's Restart-Service; the
# Get-Content body satisfies WSG WSp-105 with a single cmdlet and lets
# the bash-side verifiers fast-fail on directive or Match-block drift
# before Phase 3's multi-minute WSL stage burns.
zbujb_caparison_windows_phase2() {
  zbujb_sentinel

  buc_step "  [Phase 2] Reconnect under key-only auth + re-verify served sshd_config"

  # Allow sshd a moment to come back from Restart-Service.
  sleep 3

  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}phase2-sshd-read-" \
      "Get-Content (\$env:ProgramData + '\\ssh\\sshd_config') -Raw" \
    || buc_die "Phase 2 reconnect failed — possible brick: admin pubkey not honored after restart or sshd did not come back up; see ${ZBUJB_LAST_AP_STDERR}"
  local -r z_phase2_stdout="${ZBUJB_LAST_AP_STDOUT}"

  zbujb_caparison_windows_verify_directives "${z_phase2_stdout}"
  zbujb_caparison_windows_verify_match_block "${z_phase2_stdout}"
}

# zbujb_caparison_windows_phase3 -- post-trust admin posture: stage the
# canonical WSL distribution, disable powercfg sleep/hibernate, and set
# the Tailscale service to Automatic + running. WSL stage delegates to
# zbujb_caparison_windows_stage_wsl. Each remaining op is one
# zbujb_admin_powershell call tagged with the ${ZBUJB_CHIT_caparison}
# fragment so per-call evidence lands at an autonumbered file. On failure
# the helper's diag preview already names the file; buc_die just adds
# the BUSJHW pointer.
zbujb_caparison_windows_phase3() {
  zbujb_sentinel

  buc_step "  [Phase 3] Stage ${BUJB_wsl_distribution} WSL distribution"
  zbujb_caparison_windows_stage_wsl

  buc_step "  [Phase 3] Disable standby (AC)"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}powercfg-standby-ac-" \
      'powercfg /change standby-timeout-ac 0' \
    || buc_die "Phase 3: powercfg /change standby-timeout-ac 0 failed — BUSJHW (Modern Standby AoAc override may demote to no-op)"

  buc_step "  [Phase 3] Disable standby (DC)"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}powercfg-standby-dc-" \
      'powercfg /change standby-timeout-dc 0' \
    || buc_die "Phase 3: powercfg /change standby-timeout-dc 0 failed — BUSJHW (Modern Standby AoAc override may demote to no-op)"

  buc_step "  [Phase 3] Disable hibernate"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}powercfg-hibernate-off-" \
      'powercfg /hibernate off' \
    || buc_die "Phase 3: powercfg /hibernate off failed — BUSJHW (Modern Standby AoAc override may demote to no-op)"

  buc_step "  [Phase 3] Set Tailscale service StartupType Automatic"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}tailscale-set-service-" \
      'Set-Service -Name Tailscale -StartupType Automatic' \
    || buc_die "Phase 3: Set-Service -Name Tailscale -StartupType Automatic failed — BUSJHW (Tailscale install + Run-Unattended + first auth)"

  buc_step "  [Phase 3] Start Tailscale service"
  zbujb_admin_powershell "${ZBUJB_CHIT_caparison}tailscale-start-service-" \
      'Start-Service -Name Tailscale' \
    || buc_die "Phase 3: Start-Service -Name Tailscale failed — BUSJHW (Tailscale install + Run-Unattended + first auth)"
}

######################################################################
# Public: Caparison-windows ceremony

# bujb_caparison_windows -- run the three-phase caparison-windows ceremony
# for a Windows OpenSSH node. Phase 1: 13 single-cmdlet steps (admin
# pubkey install gated by key-auth CDD probe + ACL lockdown + sshd_config
# rewrite with Match block + sshd -t + Restart-Service sshd). Phase 2:
# reconnect under key-only auth + re-verify served sshd_config (directives
# + Match block). Phase 3: WSL distribution stage + powercfg sleep/
# hibernate disable + Tailscale service auto-start. Closes with
# post-completion invigilate-windows. Caller must have invoked
# bujb_resolve_investiture beforehand.
bujb_caparison_windows() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_caparison_windows: call bujb_resolve_investiture first"
  test "${BURN_PLATFORM}" = "bunne_windows" \
    || buc_die "bujb_caparison_windows: requires bunne_windows, got '${BURN_PLATFORM}'"

  buc_step "Caparison-windows: ${BUZ_FOLIO} (${BURN_HOST})"

  zbujb_caparison_windows_phase1
  zbujb_caparison_windows_phase2

  buc_step "  [Preflight] Operator-handbook preconditions (gate before phase 3 WSL stage)"
  zbujb_invigilate_windows_op_facts

  zbujb_caparison_windows_phase3

  buc_step "  Post-completion: verify caparison deliverables"
  zbujb_invigilate_windows_caparison_facts

  buc_step "Caparison-windows succeeded"
}

######################################################################
# Internal: WSL stage helper (invoked by bujb_caparison_windows phase 3)

# zbujb_caparison_windows_stage_wsl -- idempotently provision
# BUJB_wsl_distribution by purging any prior state, installing an
# Ubuntu-24.04 seed, exporting it to a .tar, importing under the
# canonical name, then unregistering the seed and removing the .tar.
# Caller is bujb_caparison_windows phase 3, which has already asserted
# resolve + bunne_windows. Each step propagates failure via
# zbujb_admin_powershell + || buc_die.
zbujb_caparison_windows_stage_wsl() {
  zbujb_sentinel

  local -r z_distro_dir="${BUJB_path_win_wsl_install_root}\\${BUJB_wsl_distribution}"
  # DEV CACHE: skip seed download/export; import directly from a pre-staged tar at C:\rbtww-seed.tar.
  # Operator pre-staged once via: wsl --install -d Ubuntu-24.04 --no-launch; wsl --export Ubuntu-24.04 C:\rbtww-seed.tar; wsl --unregister Ubuntu-24.04.
  # Restore the commented-out [3/6]/[4/6]/[6/6] blocks below to return to the from-scratch path.
  local -r z_tar_path='C:\rbtww-seed.tar'

  buc_step "  Stage WSL: ${BUJB_wsl_distribution} on ${BURN_HOST} (seed: ${BUJB_wsl_seed_distribution}) [DEV CACHE: ${z_tar_path}]"

  buc_step "  [1/6] Purge prior state (idempotent: unregister both, remove dir; cache tar preserved)"
  local z_wsl_list=""
  z_wsl_list=$(zbujb_powershell_capture zbujb_privileged "wsl.exe --list --quiet") \
    || z_wsl_list=""
  if grep -qFx "${BUJB_wsl_distribution}" <<<"${z_wsl_list}"; then
    zbujb_admin_powershell "${ZBUJB_CHIT_stage_wsl}unregister-dist-" \
        "wsl.exe --unregister ${BUJB_wsl_distribution}" \
      || buc_die "Failed to unregister prior ${BUJB_wsl_distribution}"
  fi
  if grep -qFx "${BUJB_wsl_seed_distribution}" <<<"${z_wsl_list}"; then
    zbujb_admin_powershell "${ZBUJB_CHIT_stage_wsl}unregister-seed-" \
        "wsl.exe --unregister ${BUJB_wsl_seed_distribution}" \
      || buc_die "Failed to unregister prior ${BUJB_wsl_seed_distribution}"
  fi
  local z_dir_present
  z_dir_present=$(zbujb_powershell_capture zbujb_privileged "Test-Path '${z_distro_dir}'") \
    || buc_die "Failed to probe ${z_distro_dir}"
  if [[ "${z_dir_present}" == "True" ]]; then
    zbujb_admin_powershell "${ZBUJB_CHIT_stage_wsl}remove-distro-dir-" \
        "Remove-Item -Recurse -Force '${z_distro_dir}'" \
      || buc_die "Failed to remove prior ${z_distro_dir}"
  fi
  # DEV CACHE: the from-scratch path also removed a stale ${BUJB_wsl_distribution}.tar
  # under BUJB_path_win_wsl_install_root; with the cache active we no longer write
  # to that path, so the corresponding purge has been dropped. Restore alongside
  # [3/6]/[4/6]/[6/6] uncommenting if reverting.

  buc_step "  [2/6] Ensure ${BUJB_path_win_wsl_install_root} directory"
  zbujb_admin_powershell "${ZBUJB_CHIT_stage_wsl}mkdir-install-root-" \
      "New-Item -ItemType Directory -Path '${BUJB_path_win_wsl_install_root}' -Force | Out-Null" \
    || buc_die "Failed to create ${BUJB_path_win_wsl_install_root}"

  # DEV CACHE: [3/6] Install seed — skipped; cache tar at ${z_tar_path} pre-staged once.
  # buc_step "  [3/6] Install ${BUJB_wsl_seed_distribution} seed distribution"
  # zbujb_admin_powershell "wsl.exe --install --no-launch -d ${BUJB_wsl_seed_distribution}" \
  #   || buc_die "Failed to install ${BUJB_wsl_seed_distribution} seed"

  # DEV CACHE: [4/6] Export seed — skipped; cache tar at ${z_tar_path} pre-staged once.
  # buc_step "  [4/6] Export ${BUJB_wsl_seed_distribution} to ${z_tar_path}"
  # zbujb_admin_powershell "wsl.exe --export ${BUJB_wsl_seed_distribution} '${z_tar_path}'" \
  #   || buc_die "Failed to export ${BUJB_wsl_seed_distribution}"

  buc_step "  [5/6] Import ${BUJB_wsl_distribution} from ${z_tar_path}"
  zbujb_admin_powershell "${ZBUJB_CHIT_stage_wsl}wsl-import-" \
      "wsl.exe --import ${BUJB_wsl_distribution} '${z_distro_dir}' '${z_tar_path}'" \
    || buc_die "Failed to import ${BUJB_wsl_distribution}"

  # DEV CACHE: [6/6] Cleanup seed + remove tar — skipped; preserve the cache tar across runs.
  # buc_step "  [6/6] Cleanup: unregister ${BUJB_wsl_seed_distribution} and remove .tar"
  # zbujb_admin_powershell "wsl.exe --unregister ${BUJB_wsl_seed_distribution}" \
  #   || buc_die "Failed to unregister ${BUJB_wsl_seed_distribution}"
  # local z_tar_present
  # z_tar_present=$(zbujb_powershell_capture zbujb_privileged "Test-Path '${z_tar_path}'") \
  #   || buc_die "Failed to probe ${z_tar_path}"
  # if [[ "${z_tar_present}" == "True" ]]; then
  #   zbujb_admin_powershell "Remove-Item -Force '${z_tar_path}'" \
  #     || buc_die "Failed to remove ${z_tar_path}"
  # fi

  buc_step "  Stage WSL succeeded"
}

######################################################################
# Public: Privileged SSH (thin admin-side pass-through)

# bujb_privileged_ssh COMMAND... -- run an arbitrary command on the BURN
# node as BURP_PRIVILEGED_USER under key-only auth. Pass-through: argv is
# handed to ssh as the remote command without shell wrapping (operator
# prepends `powershell -Command`, `bash -c`, etc. as the platform requires).
# Caller must have invoked bujb_resolve_investiture beforehand. Returns
# ssh's exit code.
bujb_privileged_ssh() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_privileged_ssh: call bujb_resolve_investiture first"
  test $# -ge 1 \
    || buc_die "bujb_privileged_ssh: command required"

  buc_step "Privileged SSH: ${BURP_PRIVILEGED_USER}@${BURN_HOST} (${BUZ_FOLIO})"

  local z_exit=0
  ssh -i "${BURP_PRIVILEGED_KEY_FILE}"           \
      "${ZBUJB_SSH_BASE_ARGS[@]}"                \
      -o "${BUJB_ssh_opt_batchmode_yes}"         \
      -o "${BUJB_ssh_opt_connecttimeout_15}"     \
      "${BURP_PRIVILEGED_USER}@${BURN_HOST}"     \
      "$@"                                       \
    || z_exit=$?
  return "${z_exit}"
}

######################################################################
# Public: Invigilate verbs (BUSJI{W,M,L} — read-only host posture)
#
# Invigilate covers host-posture facts: registry/service/sleep/distribution
# state established by caparison or operator handbook. Workload-precondition
# probes (sudo NOPASSWD, admin-group) are a separate category and live in
# bujp_preflight — the locked BUSJI specs do not list them.

zbujb_invigilate_assert_platform() {
  zbujb_sentinel
  local -r z_required="${1:-}"
  test "${BURN_PLATFORM}" = "${z_required}" \
    || buc_die "invigilate requires ${z_required}, got '${BURN_PLATFORM}'"
}

# zbujb_invigilate_windows_op_facts -- the three operator-handbook
# preconditions that gate caparison-windows phase 3 (the WSL stage's
# multi-minute download). Shared between bujb_caparison_windows preflight
# (early-fail before WSL) and bujb_invigilate_windows (post-completion
# audit + standalone runs). Requires admin SSH already established under
# key-only auth.
zbujb_invigilate_windows_op_facts() {
  zbujb_sentinel

  buc_step "  Fact: registry ${BUBC_windows_passwordless_value} = 0"
  local z_reg=""
  z_reg=$(zbujb_powershell_capture zbujb_privileged \
      "Get-ItemPropertyValue -Path '${BUBC_windows_passwordless_path}' -Name '${BUBC_windows_passwordless_value}'") \
    || z_reg="<unreadable>"
  test "${z_reg}" = "0" \
    || buc_die "registry ${BUBC_windows_passwordless_value}: expected 0, got '${z_reg:-<empty>}' — operator handbook BUSJHW (Windows registry step)"

  buc_step "  Fact: registry ${BUBC_windows_aoac_value} = 0"
  z_reg=""
  z_reg=$(zbujb_powershell_capture zbujb_privileged \
      "Get-ItemPropertyValue -Path '${BUBC_windows_aoac_path}' -Name '${BUBC_windows_aoac_value}'") \
    || z_reg="<unreadable>"
  test "${z_reg}" = "0" \
    || buc_die "registry ${BUBC_windows_aoac_value}: expected 0, got '${z_reg:-<empty>}' — operator handbook BUSJHW (Modern Standby override)"

  buc_step "  Fact: Tailscale service registered"
  local z_svc=""
  z_svc=$(zbujb_powershell_capture zbujb_privileged \
      "Get-Service Tailscale -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name") \
    || z_svc=""
  test -n "${z_svc}" \
    || buc_die "Tailscale service: expected non-empty Get-Service Tailscale, got <absent> — operator handbook BUSJHW (install + Run-Unattended + first auth)"
}

# zbujb_invigilate_windows_caparison_facts -- caparison-windows deliverables:
# Phase 1 SSH-trust posture (sshd_config Match block resolves, workload
# authkeys directory present with admins+SYSTEM-only ACL) and Phase 3
# post-trust admin posture (Tailscale auto-start, sleep policy = never
# auto-sleep, hibernate disabled, WSL distribution registered). Shared
# between bujb_caparison_windows post-completion (verify our work landed
# without re-running the operator-precondition facts already checked at
# preflight) and bujb_invigilate_windows (full audit). Requires admin
# SSH established under key-only auth.
#
# The standby check intentionally verifies POLICY (standby-timeout 0)
# rather than CAPABILITY (powercfg /a "available" list). On legacy-S3
# hardware, S3 stays in the available list regardless of timeout policy
# because the firmware supports it; only AoAc-override on Modern Standby
# (S0) hardware coincidentally removes a state from "available". What
# caparison actually sets is the timeout, so that's what we verify.
zbujb_invigilate_windows_caparison_facts() {
  zbujb_sentinel

  buc_step "  Fact: sshd_config Match User ${BUJB_workload_user} routes AuthorizedKeysFile to absolute path"
  zbujb_admin_powershell "${ZBUJB_CHIT_invigilate}sshd-config-read-" \
      "Get-Content (\$env:ProgramData + '\\ssh\\sshd_config') -Raw" \
    || buc_die "Get-Content sshd_config failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR}) — caparison-windows (BUSJCW)"
  zbujb_caparison_windows_verify_match_block "${ZBUJB_LAST_AP_STDOUT}"

  buc_step "  Fact: workload authkeys directory present at \$env:ProgramData\\ssh\\users\\${BUJB_workload_user}"
  local z_dir_present=""
  z_dir_present=$(zbujb_powershell_capture zbujb_privileged \
      "Test-Path (\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}')") \
    || buc_die "Test-Path workload authkeys directory failed on ${BURN_HOST} — caparison-windows (BUSJCW)"
  z_dir_present="${z_dir_present//[$'\r\n']/}"
  test "${z_dir_present}" = "True" \
    || buc_die "workload authkeys directory: expected present at \$env:ProgramData\\ssh\\users\\${BUJB_workload_user}, got Test-Path '${z_dir_present:-<empty>}' — caparison-windows (BUSJCW)"

  buc_step "  Fact: workload authkeys directory ACL = admins+SYSTEM Full Control only"
  zbujb_admin_powershell "${ZBUJB_CHIT_invigilate}authkeys-dir-icacls-" \
      "icacls (\$env:ProgramData + '\\ssh\\users\\${BUJB_workload_user}')" \
    || buc_die "icacls workload authkeys directory failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR}) — caparison-windows (BUSJCW)"
  local -r z_icacls_stdout="${ZBUJB_LAST_AP_STDOUT}"
  local z_acl
  z_acl=$(<"${z_icacls_stdout}")
  z_acl="${z_acl//$'\r'/}"
  z_acl="${z_acl%%Successfully processed*}"
  z_acl="${z_acl#* }"
  case "${z_acl}" in
    *"${BUJB_acl_principal_admins}"*) ;;
    *) buc_die "workload authkeys ACL: missing '${BUJB_acl_principal_admins}' (see ${z_icacls_stdout}) — caparison-windows (BUSJCW)" ;;
  esac
  case "${z_acl}" in
    *"NT AUTHORITY\\SYSTEM"*|*"${BUJB_acl_principal_system}:"*) ;;
    *) buc_die "workload authkeys ACL: missing NT AUTHORITY\\SYSTEM (see ${z_icacls_stdout}) — caparison-windows (BUSJCW)" ;;
  esac
  case "${z_acl}" in
    *"BUILTIN\\Users"*)
      buc_die "workload authkeys ACL: BUILTIN\\Users present — directory must be admins+SYSTEM only (see ${z_icacls_stdout}) — caparison-windows (BUSJCW)" ;;
    *"Authenticated Users"*)
      buc_die "workload authkeys ACL: Authenticated Users present — directory must be admins+SYSTEM only (see ${z_icacls_stdout}) — caparison-windows (BUSJCW)" ;;
    *"${BUJB_workload_user}"*)
      buc_die "workload authkeys ACL: workload user ${BUJB_workload_user} present — directory must be admins+SYSTEM only; sshd reads as NT AUTHORITY\\SYSTEM (see ${z_icacls_stdout}) — caparison-windows (BUSJCW)" ;;
  esac

  buc_step "  Fact: Tailscale service StartType = Automatic"
  local z_start=""
  z_start=$(zbujb_powershell_capture zbujb_privileged \
      "(Get-Service Tailscale).StartType") \
    || z_start="<unreadable>"
  test "${z_start}" = "Automatic" \
    || buc_die "Tailscale StartType: expected Automatic, got '${z_start:-<empty>}' — caparison-windows (BUSJCW)"

  buc_step "  Fact: standby-timeout = 0 (AC and DC)"
  zbujb_admin_powershell "${ZBUJB_CHIT_invigilate}powercfg-standby-" \
      'powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE' \
    || buc_die "powercfg /query failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR})"
  local z_pcfg_stdout="${ZBUJB_LAST_AP_STDOUT}"
  local z_pcfg
  z_pcfg=$(<"${z_pcfg_stdout}")
  z_pcfg="${z_pcfg//$'\r'/}"
  case "${z_pcfg}" in
    *"Current AC Power Setting Index: 0x00000000"*) ;;
    *) buc_die "powercfg standby-timeout AC: expected 0x00000000 (see ${z_pcfg_stdout}) — caparison-windows (BUSJCW)" ;;
  esac
  case "${z_pcfg}" in
    *"Current DC Power Setting Index: 0x00000000"*) ;;
    *) buc_die "powercfg standby-timeout DC: expected 0x00000000 (see ${z_pcfg_stdout}) — caparison-windows (BUSJCW)" ;;
  esac

  buc_step "  Fact: hibernate disabled"
  zbujb_admin_powershell "${ZBUJB_CHIT_invigilate}powercfg-hibernate-" \
      'powercfg /a' \
    || buc_die "powercfg /a failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR})"
  z_pcfg_stdout="${ZBUJB_LAST_AP_STDOUT}"
  z_pcfg=$(<"${z_pcfg_stdout}")
  z_pcfg="${z_pcfg//$'\r'/}"
  local z_available_section="${z_pcfg%%not available on this system*}"
  case "${z_available_section}" in
    *Hibernate*)
      buc_die "hibernate: expected absent from powercfg /a available section, got Hibernate listed as available (see ${z_pcfg_stdout}) — caparison-windows (BUSJCW)"
      ;;
  esac

  buc_step "  Fact: WSL distribution ${BUJB_wsl_distribution} registered"
  zbujb_admin_powershell "${ZBUJB_CHIT_invigilate}wsl-list-" \
      'wsl.exe --list --quiet' \
    || buc_die "wsl.exe --list --quiet failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR})"
  local z_wsl
  z_wsl=$(<"${ZBUJB_LAST_AP_STDOUT}")
  z_wsl="${z_wsl//$'\r'/}"
  case $'\n'"${z_wsl}"$'\n' in
    *$'\n'"${BUJB_wsl_distribution}"$'\n'*) ;;
    *)
      buc_die "WSL distribution ${BUJB_wsl_distribution}: expected present in wsl.exe --list --quiet, got '${z_wsl:-<none reported>}' — caparison-windows (BUSJCW)"
      ;;
  esac
}

# bujb_invigilate_windows -- BUSJIW read-only host posture verification.
# Two fact groups: operator-handbook preconditions (op_facts) and caparison
# deliverables (caparison_facts). Round-trip validation under the locked-
# down command= directive is NOT an invigilate fact; the operator's first
# workload-SSH invocation post-garrison (buw-jwk / buw-jwc / buw-jws) IS
# the round-trip. An explicit invigilate fact for this assertion was
# retired as overdesign once those operational tabtargets existed.
bujb_invigilate_windows() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_invigilate_windows: call bujb_resolve_investiture first"
  zbujb_invigilate_assert_platform bunne_windows

  buc_step "Invigilate-windows: ${BUZ_FOLIO} (${BURN_HOST})"

  buc_step "  Fact: admin SSH reachable (key-only)"
  zbujb_admin_powershell "${ZBUJB_CHIT_invigilate}admin-ssh-probe-" 'exit 0' \
    || buc_die "admin SSH session unreachable under key-only auth (see ${ZBUJB_LAST_AP_STDERR}) — caparison-windows (BUSJCW)"

  zbujb_invigilate_windows_op_facts

  zbujb_invigilate_windows_caparison_facts

  buc_step "Invigilate-windows succeeded"
}

# bujb_invigilate_macos -- BUSJIM read-only host posture verification.
bujb_invigilate_macos() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_invigilate_macos: call bujb_resolve_investiture first"
  zbujb_invigilate_assert_platform bunne_mac

  buc_step "Invigilate-macos: ${BUZ_FOLIO} (${BURN_HOST})"

  buc_step "  Fact: admin SSH reachable (key-only)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}admin-ssh-probe-" 'exit 0' \
    || buc_die "admin SSH session unreachable under key-only auth (see ${ZBUJB_LAST_AP_STDERR}) — caparison-macos (BUSJCM); admin pubkey not placed (rerun ssh-copy-id)"

  buc_step "  Fact: systemsetup -getremotelogin reports On"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}remotelogin-" 'systemsetup -getremotelogin' \
    || buc_die "systemsetup -getremotelogin failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR})"
  local z_rl
  z_rl=$(<"${ZBUJB_LAST_AP_STDOUT}")
  case "${z_rl}" in
    *"Remote Login: On"*) ;;
    *)
      buc_die "Remote Login state: expected On, got '${z_rl}' — caparison-macos (BUSJCM) — systemsetup -setremotelogin on"
      ;;
  esac

  buc_step "  Fact: pmset sleep=0, displaysleep=0, hibernatemode=0"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}pmset-" 'pmset -g' \
    || buc_die "pmset -g failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR})"
  local z_pmset z_pm_field z_pm_val
  z_pmset=$(<"${ZBUJB_LAST_AP_STDOUT}")
  for z_pm_field in sleep displaysleep hibernatemode; do
    z_pm_val=$(printf '%s\n' "${z_pmset}" | awk -v f="${z_pm_field}" '$1==f { print $2; exit }')
    test "${z_pm_val}" = "0" \
      || buc_die "pmset ${z_pm_field}: expected 0, got '${z_pm_val:-<not reported>}' — caparison-macos (BUSJCM) — pmset -a ${z_pm_field} 0"
  done

  buc_step "  Fact: tailscaled launchd label present"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}launchctl-list-" 'launchctl list' \
    || buc_die "launchctl list failed on ${BURN_HOST} (see ${ZBUJB_LAST_AP_STDERR})"
  local -r z_launchctl_stdout="${ZBUJB_LAST_AP_STDOUT}"
  local z_ts_line
  z_ts_line=$(grep -i 'tailscale' "${z_launchctl_stdout}" || true)
  test -n "${z_ts_line}" \
    || buc_die "tailscaled launchd label: expected non-empty match for 'tailscale' in launchctl list, got <absent> — operator handbook BUSJHM (install + first auth)"

  buc_step "  Fact: tailscaled PID live (not '-')"
  local z_pid
  z_pid=$(printf '%s\n' "${z_ts_line}" | awk 'NR==1 { print $1 }')
  test -n "${z_pid}" -a "${z_pid}" != "-" \
    || buc_die "tailscaled PID: expected live PID (not '-'), got '${z_pid:-<empty>}' — caparison-macos (BUSJCM) — Tailscale launchd auto-start"

  buc_step "  Fact: admin-group membership for ${BURP_PRIVILEGED_USER}"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}admin-group-" \
      "dseditgroup -o checkmember -m '${BURP_PRIVILEGED_USER}' admin" \
    || buc_die "admin-group membership: ${BURP_PRIVILEGED_USER} is not a member of admin (see ${ZBUJB_LAST_AP_STDOUT}) — operator handbook BUSJHM (admin-group membership prerequisite)"

  buc_step "  Fact: sudo NOPASSWD available (sudo -n true)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sudo-n-true-" 'sudo -n true' \
    || buc_die "sudo NOPASSWD availability: sudo -n true failed (see ${ZBUJB_LAST_AP_STDERR}) — operator handbook BUSJHM (sudoers NOPASSWD entry)"

  buc_step "  Fact: sudo scope covers garrison commands (sudo -ln sysadminctl)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sudo-ln-sysadminctl-" 'sudo -ln sysadminctl' \
    || buc_die "sudo scope for sysadminctl: sudo -ln sysadminctl failed (see ${ZBUJB_LAST_AP_STDERR}) — operator handbook BUSJHM (sudoers entry too narrow for garrison's command set)"

  buc_step "Invigilate-macos succeeded"
}

# bujb_invigilate_linux -- BUSJIL read-only host posture verification.
bujb_invigilate_linux() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_invigilate_linux: call bujb_resolve_investiture first"
  zbujb_invigilate_assert_platform bunne_linux

  buc_step "Invigilate-linux: ${BUZ_FOLIO} (${BURN_HOST})"

  buc_step "  Fact: admin SSH reachable (key-only)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}admin-ssh-probe-" 'exit 0' \
    || buc_die "admin SSH session unreachable under key-only auth (see ${ZBUJB_LAST_AP_STDERR}) — caparison-linux (BUSJCL); admin pubkey not placed (rerun ssh-copy-id)"

  local z_val z_stdout z_stderr

  buc_step "  Fact: systemctl is-enabled sshd = enabled"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sshd-is-enabled-" 'systemctl is-enabled sshd' \
    || true
  z_stdout="${ZBUJB_LAST_AP_STDOUT}"
  z_stderr="${ZBUJB_LAST_AP_STDERR}"
  z_val=$(<"${z_stdout}")
  z_val="${z_val//$'\n'/}"
  if grep -qiE 'no such|not found|not-found' "${z_stderr}"; then
    buc_die "sshd unit enablement: <unit not found> — operator handbook BUSJHL (apt install openssh-server)"
  fi
  test "${z_val}" = "enabled" \
    || buc_die "sshd unit enablement: expected enabled, got '${z_val:-<unreported>}' — caparison-linux (BUSJCL)"

  buc_step "  Fact: systemctl is-active sshd = active"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sshd-is-active-" 'systemctl is-active sshd' \
    || true
  z_val=$(<"${ZBUJB_LAST_AP_STDOUT}")
  z_val="${z_val//$'\n'/}"
  test "${z_val}" = "active" \
    || buc_die "sshd unit activeness: expected active, got '${z_val:-<unreported>}' — caparison-linux (BUSJCL)"

  buc_step "  Fact: sleep/suspend/hibernate/hybrid-sleep targets masked"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sleep-targets-" \
      'systemctl is-enabled sleep.target suspend.target hibernate.target hybrid-sleep.target' \
    || true
  local z_targets z_target z_i=1
  z_targets=$(<"${ZBUJB_LAST_AP_STDOUT}")
  for z_target in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
    z_val=$(printf '%s\n' "${z_targets}" | sed -n "${z_i}p")
    test "${z_val}" = "masked" \
      || buc_die "${z_target} mask state: expected masked, got '${z_val:-<unreported>}' — caparison-linux (BUSJCL)"
    z_i=$((z_i + 1))
  done

  buc_step "  Fact: systemctl is-enabled tailscaled = enabled"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}tailscaled-is-enabled-" 'systemctl is-enabled tailscaled' \
    || true
  z_stdout="${ZBUJB_LAST_AP_STDOUT}"
  z_stderr="${ZBUJB_LAST_AP_STDERR}"
  z_val=$(<"${z_stdout}")
  z_val="${z_val//$'\n'/}"
  if grep -qiE 'no such|not found|not-found' "${z_stderr}"; then
    buc_die "tailscaled unit enablement: <unit not found> — operator handbook BUSJHL (install + first auth)"
  fi
  test "${z_val}" = "enabled" \
    || buc_die "tailscaled unit enablement: expected enabled, got '${z_val:-<unreported>}' — caparison-linux (BUSJCL)"

  buc_step "  Fact: systemctl is-active tailscaled = active"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}tailscaled-is-active-" 'systemctl is-active tailscaled' \
    || true
  z_val=$(<"${ZBUJB_LAST_AP_STDOUT}")
  z_val="${z_val//$'\n'/}"
  test "${z_val}" = "active" \
    || buc_die "tailscaled unit activeness: expected active, got '${z_val:-<unreported>}' — caparison-linux (BUSJCL)"

  buc_step "  Fact: sudo NOPASSWD available (sudo -n true)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sudo-n-true-" 'sudo -n true' \
    || buc_die "sudo NOPASSWD availability: sudo -n true failed (see ${ZBUJB_LAST_AP_STDERR}) — operator handbook BUSJHL (sudoers NOPASSWD entry)"

  buc_step "  Fact: sudo scope covers garrison commands (sudo -ln userdel)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_invigilate}sudo-ln-userdel-" 'sudo -ln userdel' \
    || buc_die "sudo scope for userdel: sudo -ln userdel failed (see ${ZBUJB_LAST_AP_STDERR}) — operator handbook BUSJHL (sudoers entry too narrow for garrison's command set)"

  buc_step "Invigilate-linux succeeded"
}

######################################################################
# Public: Caparison verbs (BUSJC{M,L} — admin host posture establishment)
#
# Caparison covers the idempotent admin-shell remainder of host posture
# (Remote Login / sshd enable, sleep/hibernate disable, Tailscale service
# auto-start). Operator handbook (BUSJH{M,L}) owns ssh-copy-id and the
# Tailscale install + first-run auth. Each verb closes with a
# post-completion invigilate-{platform} check that surfaces drift.

# bujb_caparison_macos -- BUSJCM admin host-posture ceremony.
bujb_caparison_macos() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_caparison_macos: call bujb_resolve_investiture first"
  test "${BURN_PLATFORM}" = "bunne_mac" \
    || buc_die "bujb_caparison_macos: requires bunne_mac, got '${BURN_PLATFORM}'"

  buc_step "Caparison-macos: ${BUZ_FOLIO} (${BURN_HOST})"

  buc_step "  Open admin SSH (key-only)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}mac-ssh-probe-" 'exit 0' \
    || buc_die "Caparison-macos: admin SSH (key-only) failed — operator handbook BUSJHM (ssh-copy-id; admin pubkey placement)"

  buc_step "  Enable Remote Login"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}mac-remotelogin-on-" \
      'sudo -n systemsetup -setremotelogin on' \
    || buc_die "Caparison-macos: systemsetup -setremotelogin on failed — operator handbook BUSJHM (sudo NOPASSWD)"

  buc_step "  Disable sleep, displaysleep, hibernate via pmset"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}mac-pmset-disable-" \
      'sudo -n pmset -a sleep 0 displaysleep 0 hibernatemode 0' \
    || buc_die "Caparison-macos: pmset -a sleep 0 displaysleep 0 hibernatemode 0 failed — operator handbook BUSJHM"

  buc_step "  Enable tailscaled launchd service"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}mac-tailscale-enable-" \
      'sudo -n launchctl enable system/com.tailscale.tailscaled' \
    || buc_die "Caparison-macos: launchctl enable system/com.tailscale.tailscaled failed — operator handbook BUSJHM (Tailscale install + first-run auth)"

  buc_step "  Start tailscaled launchd service"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}mac-tailscale-kickstart-" \
      'sudo -n launchctl kickstart -k system/com.tailscale.tailscaled' \
    || buc_die "Caparison-macos: launchctl kickstart -k system/com.tailscale.tailscaled failed — operator handbook BUSJHM (Tailscale install + first-run auth)"

  buc_step "  Post-completion check: invigilate-macos"
  bujb_invigilate_macos

  buc_step "Caparison-macos succeeded"
}

# bujb_caparison_linux -- BUSJCL admin host-posture ceremony.
bujb_caparison_linux() {
  zbujb_sentinel
  test "${ZBUJB_RESOLVED:-}" = "1" \
    || buc_die "bujb_caparison_linux: call bujb_resolve_investiture first"
  test "${BURN_PLATFORM}" = "bunne_linux" \
    || buc_die "bujb_caparison_linux: requires bunne_linux, got '${BURN_PLATFORM}'"

  buc_step "Caparison-linux: ${BUZ_FOLIO} (${BURN_HOST})"

  buc_step "  Open admin SSH (key-only)"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}linux-ssh-probe-" 'exit 0' \
    || buc_die "Caparison-linux: admin SSH (key-only) failed — operator handbook BUSJHL (ssh-copy-id; admin pubkey placement)"

  buc_step "  Enable and start sshd"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}linux-sshd-enable-" \
      'sudo -n systemctl enable --now sshd' \
    || buc_die "Caparison-linux: systemctl enable --now sshd failed — operator handbook BUSJHL (apt install openssh-server on minimal distros)"

  buc_step "  Mask sleep/suspend/hibernate/hybrid-sleep targets"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}linux-sleep-mask-" \
      'sudo -n systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target' \
    || buc_die "Caparison-linux: systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target failed — operator handbook BUSJHL"

  buc_step "  Enable and start tailscaled"
  zbujb_admin_exec_native "${ZBUJB_CHIT_caparison}linux-tailscaled-enable-" \
      'sudo -n systemctl enable --now tailscaled' \
    || buc_die "Caparison-linux: systemctl enable --now tailscaled failed — operator handbook BUSJHL (Tailscale install + first-run 'tailscale up')"

  buc_step "  Post-completion check: invigilate-linux"
  bujb_invigilate_linux

  buc_step "Caparison-linux succeeded"
}

# eof
