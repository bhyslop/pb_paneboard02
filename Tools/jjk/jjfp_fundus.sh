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
# JJFP Fundus - Fundus test account provisioning and scenario dispatch
#
# Two-phase provisioning:
#   Phase 1 (root):     sudo tt/jjw-tfP1.ProvisionPhase1.sh <keypath>
#   Phase 2 (operator): tt/jjw-tfP2.ProvisionPhase2.<host>.sh

set -euo pipefail

# Multiple inclusion detection
test -z "${ZJJFP_SOURCED:-}" || buc_die "Module jjfp multiply sourced - check sourcing hierarchy"
ZJJFP_SOURCED=1

# Tinder constants
JJFP_keypath_param="keypath"
JJFP_pubkey_param="pubkey"
JJFP_account_prefix="jjfu_"
JJFP_acct_full="${JJFP_account_prefix}full"
JJFP_acct_nokey="${JJFP_account_prefix}nokey"
JJFP_acct_norepo="${JJFP_account_prefix}norepo"
JJFP_acct_nogit="${JJFP_account_prefix}nogit"
JJFP_ssh_accounts="${JJFP_acct_full} ${JJFP_acct_norepo} ${JJFP_acct_nogit}"

######################################################################
# Internal Functions (zjjfp_*)

zjjfp_kindle() {
  test -z "${ZJJFP_KINDLED:-}" || buc_die "Module jjfp already kindled"

  test -n "${BURD_TEMP_DIR:-}"  || buc_die "BURD_TEMP_DIR is unset"
  test -n "${BURD_TOOLS_DIR:-}" || buc_die "BURD_TOOLS_DIR is unset"

  readonly ZJJFP_SCRIPT_DIR="${BURD_TOOLS_DIR}/jjk"
  readonly ZJJFP_MANIFEST_PATH="${ZJJFP_SCRIPT_DIR}/vov_veiled/Cargo.toml"
  readonly ZJJFP_RELDIR="projects/rbm_alpha_recipemuster"
  readonly ZJJFP_ACCOUNTS="${JJFP_acct_full} ${JJFP_acct_nokey} ${JJFP_acct_norepo} ${JJFP_acct_nogit}"
  readonly ZJJFP_TEMP_PREFIX="${BURD_TEMP_DIR}/jjfp_"

  # Shared temp file paths for helper results (sequential access only)
  readonly ZJJFP_RESOLVE_HOME="${ZJJFP_TEMP_PREFIX}home_dir.txt"
  readonly ZJJFP_RESOLVE_GROUP="${ZJJFP_TEMP_PREFIX}primary_group.txt"
  readonly ZJJFP_RESOLVE_PLATFORM="${ZJJFP_TEMP_PREFIX}platform.txt"
  readonly ZJJFP_RESOLVE_UID="${ZJJFP_TEMP_PREFIX}uid.txt"

  readonly ZJJFP_KINDLED=1
}

zjjfp_sentinel() {
  test "${ZJJFP_KINDLED:-}" = "1" || buc_die "Module jjfp not kindled - call zjjfp_kindle first"
}

######################################################################
# Internal helpers — resolvers (write to temp file, caller reads)

zjjfp_resolve_platform() {
  zjjfp_sentinel

  local -r z_uname_file="${ZJJFP_TEMP_PREFIX}uname.txt"
  uname -s > "${z_uname_file}" || buc_die "Failed to detect platform"
  local -r z_uname=$(<"${z_uname_file}")
  test -n "${z_uname}" || buc_die "Empty uname output"

  case "${z_uname}" in
    Darwin) echo "macos" > "${ZJJFP_RESOLVE_PLATFORM}" ;;
    Linux)  echo "linux" > "${ZJJFP_RESOLVE_PLATFORM}" ;;
    *)      buc_die "Unsupported platform: ${z_uname}" ;;
  esac
}

zjjfp_resolve_home_dir() {
  zjjfp_sentinel
  local -r z_platform="${1:-}"
  local -r z_user="${2:-}"
  case "${z_platform}" in
    macos) echo "/Users/${z_user}" > "${ZJJFP_RESOLVE_HOME}" ;;
    linux) echo "/home/${z_user}" > "${ZJJFP_RESOLVE_HOME}" ;;
  esac
}

zjjfp_resolve_primary_group() {
  zjjfp_sentinel
  local -r z_platform="${1:-}"
  local -r z_user="${2:-}"
  case "${z_platform}" in
    macos) echo "staff" > "${ZJJFP_RESOLVE_GROUP}" ;;
    linux) echo "${z_user}" > "${ZJJFP_RESOLVE_GROUP}" ;;
  esac
}

######################################################################
# Internal helpers — Phase 1: account management (running as root)

zjjfp_delete_account() {
  zjjfp_sentinel
  local -r z_platform="${1:-}"
  local -r z_user="${2:-}"
  test -n "${z_user}" || buc_die "zjjfp_delete_account: user required"

  local -r z_id_stderr="${ZJJFP_TEMP_PREFIX}id_${z_user}_stderr.txt"
  if ! id "${z_user}" >/dev/null 2>"${z_id_stderr}"; then
    buc_log_args "Account ${z_user} does not exist — skip delete"
    return 0
  fi

  buc_step "Deleting account: ${z_user}"
  local -r z_stderr="${ZJJFP_TEMP_PREFIX}delete_${z_user}_stderr.txt"
  case "${z_platform}" in
    macos)
      sysadminctl -deleteUser "${z_user}" 2>"${z_stderr}" \
        || buc_die "Failed to delete macOS account: ${z_user} — see ${z_stderr}"
      if test -d "/Users/${z_user}"; then
        rm -rf "/Users/${z_user}" \
          || buc_die "Failed to remove residual home dir: /Users/${z_user}"
      fi
      ;;
    linux)
      userdel -r "${z_user}" 2>"${z_stderr}" \
        || buc_die "Failed to delete Linux account: ${z_user} — see ${z_stderr}"
      if test -d "/home/${z_user}"; then
        rm -rf "/home/${z_user}" \
          || buc_die "Failed to remove residual home dir: /home/${z_user}"
      fi
      ;;
  esac
  buc_log_args "Account ${z_user} deleted"
}

zjjfp_create_account() {
  zjjfp_sentinel
  local -r z_platform="${1:-}"
  local -r z_user="${2:-}"
  test -n "${z_user}" || buc_die "zjjfp_create_account: user required"

  buc_step "Creating account: ${z_user}"
  local -r z_stderr="${ZJJFP_TEMP_PREFIX}create_${z_user}_stderr.txt"
  case "${z_platform}" in
    macos)
      local -r z_pw_file="${ZJJFP_TEMP_PREFIX}password.txt"
      openssl rand -base64 16 > "${z_pw_file}" \
        || buc_die "Failed to generate random password"
      local -r z_password=$(<"${z_pw_file}")
      test -n "${z_password}" || buc_die "Generated password is empty"

      sysadminctl -addUser "${z_user}" \
        -password "${z_password}" \
        -home "/Users/${z_user}" \
        -shell /bin/bash \
        2>"${z_stderr}" \
        || buc_die "Failed to create macOS account: ${z_user} — see ${z_stderr}"

      # sysadminctl may not create the home dir — ensure it exists with correct ownership
      mkdir -p "/Users/${z_user}" \
        || buc_die "Failed to create home dir for: ${z_user}"
      chown -R "${z_user}:staff" "/Users/${z_user}" \
        || buc_die "Failed to chown home dir for: ${z_user}"
      ;;
    linux)
      useradd -m -s /bin/bash "${z_user}" 2>"${z_stderr}" \
        || buc_die "Failed to create Linux account: ${z_user} — see ${z_stderr}"
      passwd -l "${z_user}" 2>"${z_stderr}" \
        || buc_die "Failed to lock password for: ${z_user} — see ${z_stderr}"
      ;;
  esac
  buc_log_args "Account ${z_user} created"
}

######################################################################
# Internal helpers — Phase 1: SSH login access (running as root)

zjjfp_enable_ssh_access() {
  zjjfp_sentinel
  local -r z_platform="${1:-}"
  local -r z_user="${2:-}"
  test -n "${z_user}" || buc_die "zjjfp_enable_ssh_access: user required"

  case "${z_platform}" in
    macos)
      buc_step "Enabling SSH access for: ${z_user}"
      local -r z_stderr="${ZJJFP_TEMP_PREFIX}sshaccess_${z_user}_stderr.txt"
      dseditgroup -o edit -a "${z_user}" -t user com.apple.access_ssh 2>"${z_stderr}" \
        || buc_die "Failed to add ${z_user} to com.apple.access_ssh — see ${z_stderr}"
      buc_log_args "SSH access enabled for ${z_user}"
      ;;
    linux)
      # Linux sshd allows all local users by default
      ;;
  esac
}

######################################################################
# Internal helpers — Phase 1: SSH keypair installation (running as root)

zjjfp_install_keypair() {
  zjjfp_sentinel
  local -r z_platform="${1:-}"
  local -r z_user="${2:-}"
  local -r z_privkey_path="${3:-}"
  test -n "${z_user}"         || buc_die "zjjfp_install_keypair: user required"
  test -n "${z_privkey_path}" || buc_die "zjjfp_install_keypair: private key path required"

  buc_step "Installing SSH keypair for: ${z_user}"

  local -r z_pubkey_path="${z_privkey_path}.pub"
  local -r z_key_name="${z_privkey_path##*/}"

  zjjfp_resolve_home_dir "${z_platform}" "${z_user}"
  local -r z_home=$(<"${ZJJFP_RESOLVE_HOME}")
  local -r z_ssh_dir="${z_home}/.ssh"

  zjjfp_resolve_primary_group "${z_platform}" "${z_user}"
  local -r z_group=$(<"${ZJJFP_RESOLVE_GROUP}")

  mkdir -p "${z_ssh_dir}" \
    || buc_die "Failed to create .ssh dir for: ${z_user}"

  # Install private key (for GitHub access from the account)
  cp "${z_privkey_path}" "${z_ssh_dir}/${z_key_name}" \
    || buc_die "Failed to copy private key for: ${z_user}"
  chmod 600 "${z_ssh_dir}/${z_key_name}" \
    || buc_die "Failed to chmod private key for: ${z_user}"

  # Install public key (for GitHub access from the account)
  cp "${z_pubkey_path}" "${z_ssh_dir}/${z_key_name}.pub" \
    || buc_die "Failed to copy public key for: ${z_user}"
  chmod 644 "${z_ssh_dir}/${z_key_name}.pub" \
    || buc_die "Failed to chmod public key for: ${z_user}"

  # Authorize operator SSH access to this account
  cp "${z_pubkey_path}" "${z_ssh_dir}/authorized_keys" \
    || buc_die "Failed to write authorized_keys for: ${z_user}"
  chmod 600 "${z_ssh_dir}/authorized_keys" \
    || buc_die "Failed to chmod authorized_keys for: ${z_user}"

  chmod 700 "${z_ssh_dir}" \
    || buc_die "Failed to chmod .ssh for: ${z_user}"
  chown -R "${z_user}:${z_group}" "${z_ssh_dir}" \
    || buc_die "Failed to chown .ssh for: ${z_user}"

  buc_log_args "SSH keypair installed for ${z_user}"
}

######################################################################
# Internal helpers — Phase 2: double-hop SSH (operator → test account via remote operator)

zjjfp_double_hop() {
  zjjfp_sentinel
  local -r z_host="${1:-}"
  local -r z_user="${2:-}"
  local -r z_cmd="${3:-}"
  test -n "${z_host}" || buc_die "zjjfp_double_hop: host required"
  test -n "${z_user}" || buc_die "zjjfp_double_hop: user required"
  test -n "${z_cmd}"  || buc_die "zjjfp_double_hop: cmd required"

  # SSH to operator@host, then SSH to user@localhost to run cmd
  local -r z_stderr="${ZJJFP_TEMP_PREFIX}dhop_${z_user}_stderr.txt"
  ssh -o BatchMode=yes "${z_host}" \
    "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new ${z_user}@localhost '${z_cmd}'" \
    2>"${z_stderr}" \
    || buc_die "Double-hop to ${z_user}@${z_host} failed — see ${z_stderr}"
}

# Pipe stdin to a file on the test account via double-hop
zjjfp_double_hop_pipe() {
  zjjfp_sentinel
  local -r z_host="${1:-}"
  local -r z_user="${2:-}"
  local -r z_remote_path="${3:-}"
  test -n "${z_host}"        || buc_die "zjjfp_double_hop_pipe: host required"
  test -n "${z_user}"        || buc_die "zjjfp_double_hop_pipe: user required"
  test -n "${z_remote_path}" || buc_die "zjjfp_double_hop_pipe: remote_path required"

  local -r z_stderr="${ZJJFP_TEMP_PREFIX}dhop_pipe_${z_user}_stderr.txt"
  ssh -o BatchMode=yes "${z_host}" \
    "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new ${z_user}@localhost 'cat >> ${z_remote_path}'" \
    2>"${z_stderr}" \
    || buc_die "Double-hop pipe to ${z_user}@${z_host}:${z_remote_path} failed — see ${z_stderr}"
}

######################################################################
# Internal helpers — Phase 2: repo setup (running as operator, via SSH)

zjjfp_ssh_setup_repo() {
  zjjfp_sentinel
  local -r z_host="${1:-}"
  local -r z_user="${2:-}"
  local -r z_with_origin="${3:-1}"
  local -r z_curia_origin="${4:-}"
  local -r z_clone_source="${5:-}"
  test -n "${z_host}" || buc_die "zjjfp_ssh_setup_repo: host required"
  test -n "${z_user}" || buc_die "zjjfp_ssh_setup_repo: user required"
  test -n "${z_clone_source}" || buc_die "zjjfp_ssh_setup_repo: clone_source required"

  buc_step "Setting up repo for: ${z_user}@${z_host} (origin=${z_with_origin})"

  local -r z_stderr="${ZJJFP_TEMP_PREFIX}repo_${z_user}_stderr.txt"
  local -r z_ssh_target="${z_user}@${z_host}"
  local -r z_project_dir="${ZJJFP_RELDIR}"

  # Clean slate and clone — .buk/ is tracked, so clone brings BUK with it
  # For localhost: clone from local repo path (fast, needs safe.directory for cross-user access)
  # For remote: clone from GitHub URL (uses account's SSH keypair)
  local z_clone_cmd="rm -rf '${z_project_dir}' && mkdir -p '${z_project_dir%/*}' && git clone '${z_clone_source}' '${z_project_dir}'"
  if test "${z_host}" = "localhost"; then
    z_clone_cmd="git config --global --add safe.directory '${z_clone_source}/.git' && ${z_clone_cmd}"
  fi

  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${z_ssh_target}" \
    "${z_clone_cmd}" \
    2>"${z_stderr}" \
    || buc_die "Failed to clone repo for: ${z_ssh_target} — see ${z_stderr}"

  # Configure origin
  if test "${z_with_origin}" = "1"; then
    test -n "${z_curia_origin}" || buc_die "zjjfp_ssh_setup_repo: curia_origin required when with_origin=1"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${z_ssh_target}" \
      "git -C '${z_project_dir}' remote set-url origin '${z_curia_origin}'" \
      2>"${z_stderr}" \
      || buc_die "Failed to set origin for: ${z_ssh_target} — see ${z_stderr}"
    buc_log_args "Repo cloned with origin: ${z_curia_origin}"
  else
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${z_ssh_target}" \
      "git -C '${z_project_dir}' remote remove origin" \
      2>"${z_stderr}" \
      || buc_die "Failed to remove origin for: ${z_ssh_target} — see ${z_stderr}"
    buc_log_args "Repo cloned with origin removed"
  fi

  # Create station regime — required for BUD dispatch
  local -r z_station_stderr="${ZJJFP_TEMP_PREFIX}station_${z_user}_stderr.txt"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${z_ssh_target}" \
    "cd '${z_project_dir}' && ./tt/buw-SI.StationInit.sh" \
    2>"${z_station_stderr}" \
    || buc_die "Failed to create station regime for: ${z_ssh_target} — see ${z_station_stderr}"
  buc_log_args "Station regime created for ${z_user}@${z_host}"
}

######################################################################
# External Functions (jjfp_*)

jjfp_provision() {
  zjjfp_sentinel

  local -r z_keypath="${1:-}"

  buc_doc_brief "Phase 1: Create OS accounts and install SSH keypairs (requires root)"
  buc_doc_param "${JJFP_keypath_param}" "Path to curia user SSH private key (e.g., /Users/you/.ssh/id_ed25519)"
  buc_doc_shown || return 0

  # Root gate
  id -u > "${ZJJFP_RESOLVE_UID}" || buc_die "Failed to get uid"
  local -r z_uid=$(<"${ZJJFP_RESOLVE_UID}")
  test "${z_uid}" = "0" || buc_die "jjfp_provision: must run as root (use: sudo tt/jjw-tfP1.ProvisionPhase1.sh <keypath>)"

  # Validate keypair
  test -n "${z_keypath}" || buc_die "jjfp_provision: private key path required (pass as argument)"
  test -f "${z_keypath}" || buc_die "jjfp_provision: private key not found: ${z_keypath}"
  test -f "${z_keypath}.pub" || buc_die "jjfp_provision: public key not found: ${z_keypath}.pub"

  buc_step "Phase 1: Provisioning fundus test accounts"

  # Discover platform
  zjjfp_resolve_platform
  local -r z_platform=$(<"${ZJJFP_RESOLVE_PLATFORM}")
  test -n "${z_platform}" || buc_die "Empty platform result"

  # Delete all accounts matching the fundus prefix (catches stale accounts from previous configs)
  buc_step "Deleting existing accounts"
  local -r z_enum_file="${ZJJFP_TEMP_PREFIX}enum_accounts.txt"
  : > "${z_enum_file}"
  case "${z_platform}" in
    macos) dscl . -list /Users | grep "^${JJFP_account_prefix}" > "${z_enum_file}" || true ;;
    linux) getent passwd | grep "^${JJFP_account_prefix}" | cut -d: -f1 > "${z_enum_file}" || true ;;
  esac
  local z_acct=""
  for z_acct in $(<"${z_enum_file}"); do
    zjjfp_delete_account "${z_platform}" "${z_acct}"
  done

  # Create accounts with SSH keypairs per JJSTF
  buc_step "Creating accounts"

  # full: SSH keypair (for operator access + GitHub)
  zjjfp_create_account      "${z_platform}" "${JJFP_acct_full}"
  zjjfp_enable_ssh_access   "${z_platform}" "${JJFP_acct_full}"
  zjjfp_install_keypair     "${z_platform}" "${JJFP_acct_full}" "${z_keypath}"

  # nokey: OS account only, no SSH key access from curia
  zjjfp_create_account      "${z_platform}" "${JJFP_acct_nokey}"

  # norepo: SSH keypair, no project directory at RELDIR
  zjjfp_create_account      "${z_platform}" "${JJFP_acct_norepo}"
  zjjfp_enable_ssh_access   "${z_platform}" "${JJFP_acct_norepo}"
  zjjfp_install_keypair     "${z_platform}" "${JJFP_acct_norepo}" "${z_keypath}"

  # nogit: SSH keypair (repo setup deferred to phase 2)
  zjjfp_create_account      "${z_platform}" "${JJFP_acct_nogit}"
  zjjfp_enable_ssh_access   "${z_platform}" "${JJFP_acct_nogit}"
  zjjfp_install_keypair     "${z_platform}" "${JJFP_acct_nogit}" "${z_keypath}"

  # Restore ownership of dispatch dirs so operator's next dispatch isn't poisoned
  test -n "${SUDO_USER:-}" || buc_die "SUDO_USER not set — cannot restore ownership"
  zjjfp_resolve_primary_group "${z_platform}" "${SUDO_USER}"
  local -r z_sudo_group=$(<"${ZJJFP_RESOLVE_GROUP}")
  chown -R "${SUDO_USER}:${z_sudo_group}" "${BURD_TEMP_DIR}" \
    || buc_die "Failed to restore ownership of temp dir"
  chown -R "${SUDO_USER}:${z_sudo_group}" "${BURD_OUTPUT_DIR}" \
    || buc_die "Failed to restore ownership of output dir"
  chown -R "${SUDO_USER}:${z_sudo_group}" "${BURD_OUTPUT_DIR%/*}" \
    || buc_die "Failed to restore ownership of output root dir"

  buc_success "Phase 1 complete — accounts and keypairs provisioned. Run phase 2 to set up repos."
}

jjfp_repo() {
  zjjfp_sentinel

  local -r z_host="${BUZ_FOLIO:-}"
  local -r z_pubkey_path="${1:-}"
  test -n "${z_host}" || buc_die "jjfp_repo: no host (BUZ_FOLIO empty)"

  buc_doc_brief "Phase 2: Authorize curia access, clone repos, install BUK"
  buc_doc_param "${JJFP_pubkey_param}" "Path to curia SSH public key (required for remote hosts, omit for localhost)"
  buc_doc_shown || return 0

  buc_step "Phase 2: Setting up repos on ${z_host}"

  # Discover git origin URL
  local -r z_origin_file="${ZJJFP_TEMP_PREFIX}origin.txt"
  local -r z_origin_stderr="${ZJJFP_TEMP_PREFIX}origin_stderr.txt"
  git -C "${BURD_TOOLS_DIR}/.." remote get-url origin > "${z_origin_file}" 2>"${z_origin_stderr}" \
    || buc_die "Failed to get git origin URL from curia repo — see ${z_origin_stderr}"
  local -r z_curia_origin=$(<"${z_origin_file}")
  test -n "${z_curia_origin}" || buc_die "Git origin URL is empty"
  buc_log_args "Curia origin: ${z_curia_origin}"

  if test "${z_host}" = "localhost"; then
    # Localhost: clone from local repo, direct SSH to test accounts
    local -r z_curia_root_file="${ZJJFP_TEMP_PREFIX}curia_root.txt"
    (cd "${BURD_TOOLS_DIR}/.." && pwd) > "${z_curia_root_file}" \
      || buc_die "Failed to resolve curia repo root"
    local -r z_clone_source=$(<"${z_curia_root_file}")
    test -n "${z_clone_source}" || buc_die "Empty curia repo root"

    zjjfp_ssh_setup_repo "${z_host}" "${JJFP_acct_full}"  1 "${z_curia_origin}" "${z_clone_source}"
    zjjfp_ssh_setup_repo "${z_host}" "${JJFP_acct_nogit}" 0 ""                  "${z_clone_source}"

    # GitHub host key for full account (needs git fetch origin for plant test)
    local -r z_ghkey_stderr="${ZJJFP_TEMP_PREFIX}ghkey_${JJFP_acct_full}_stderr.txt"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${JJFP_acct_full}@localhost" \
      "ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null" \
      2>"${z_ghkey_stderr}" \
      || buc_die "Failed to add GitHub host key for ${JJFP_acct_full} — see ${z_ghkey_stderr}"
    buc_log_args "GitHub host key added for ${JJFP_acct_full}@localhost"
  else
    # Remote: validate pubkey argument
    test -n "${z_pubkey_path}" || buc_die "jjfp_repo: pubkey path required for remote host (pass as argument)"
    test -f "${z_pubkey_path}" || buc_die "jjfp_repo: pubkey file not found: ${z_pubkey_path}"
    local -r z_pubkey=$(<"${z_pubkey_path}")
    test -n "${z_pubkey}" || buc_die "jjfp_repo: pubkey file is empty: ${z_pubkey_path}"

    # Inject curia pubkey into test accounts via double-hop (operator → test account)
    buc_step "Authorizing curia access to test accounts on ${z_host}"
    local z_auth_user=""
    for z_auth_user in ${JJFP_ssh_accounts}; do
      echo "${z_pubkey}" | zjjfp_double_hop_pipe "${z_host}" "${z_auth_user}" "~/.ssh/authorized_keys"
      buc_log_args "Curia pubkey injected for ${z_auth_user}@${z_host}"
    done

    # Add GitHub host key via double-hop (for clone and plant)
    buc_step "Adding GitHub host keys on ${z_host}"
    local z_ghkey_user=""
    for z_ghkey_user in ${JJFP_acct_full} ${JJFP_acct_nogit}; do
      zjjfp_double_hop "${z_host}" "${z_ghkey_user}" \
        "ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null"
      buc_log_args "GitHub host key added for ${z_ghkey_user}@${z_host}"
    done

    # Clone from GitHub via direct SSH (curia key now authorized)
    zjjfp_ssh_setup_repo "${z_host}" "${JJFP_acct_full}"  1 "${z_curia_origin}" "${z_curia_origin}"
    zjjfp_ssh_setup_repo "${z_host}" "${JJFP_acct_nogit}" 0 ""                  "${z_curia_origin}"
  fi

  buc_success "Phase 2 complete — repos and BUK installed"
}

zjjfp_require_pushed() {
  local -r z_branch="$(git rev-parse --abbrev-ref HEAD)"
  local -r z_local="$(git rev-parse HEAD)"
  local -r z_remote="$(git rev-parse "origin/${z_branch}" 2>/dev/null)" \
    || buc_die "No remote tracking branch origin/${z_branch}"
  test "${z_local}" = "${z_remote}" \
    || buc_die "Unpushed commits on ${z_branch} — push before running fundus scenarios (local=${z_local:0:8} remote=${z_remote:0:8})"
}

jjfp_scenario() {
  zjjfp_sentinel

  local -r z_host="${BUZ_FOLIO:-}"
  test -n "${z_host}" || buc_die "jjfp_scenario: no host (BUZ_FOLIO empty)"

  buc_doc_brief "Run fundus scenario tests for a host (localhost=normal, cerebro=ignored)"
  buc_doc_shown || return 0

  zjjfp_require_pushed

  local z_ignored_flag=""
  test "${z_host}" = "localhost" || z_ignored_flag="--ignored"

  exec cargo test \
    --manifest-path "${ZJJFP_MANIFEST_PATH}" \
    --test jjtlg_fundus_scenario \
    -- --test-threads=1 ${z_ignored_flag}
}

jjfp_single() {
  zjjfp_sentinel

  local -r z_host="${BUZ_FOLIO:-}"
  local -r z_test="${1:-}"
  test -n "${z_host}" || buc_die "jjfp_single: no host (BUZ_FOLIO empty)"
  test -n "${z_test}" || buc_die "jjfp_single: no test function name (pass as argument)"

  buc_doc_brief "Run a single fundus scenario test (e.g., localhost::bind_send)"
  buc_doc_shown || return 0

  zjjfp_require_pushed

  local z_ignored_flag=""
  test "${z_host}" = "localhost" || z_ignored_flag="--ignored"

  exec cargo test \
    --manifest-path "${ZJJFP_MANIFEST_PATH}" \
    --test jjtlg_fundus_scenario \
    -- --test-threads=1 ${z_ignored_flag} "${z_test}"
}

# eof
