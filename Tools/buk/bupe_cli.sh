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
# BUPE CLI - Parcel emplacement, the maintenance door for a lit station
#
# The procedure this door wraps is the parcel install procedure the
# distribution specification lays out; the dispatch vocabulary it speaks
# is the kit's own.
#
# There are two doors onto that one procedure, and they are not
# alternatives. A DARK station cannot run a tabtarget at all, so the
# parcel's own vvi_install.sh stays the rescue door and is reached from
# outside the target tree. A LIT station has dispatch, logging and its
# own regime already standing, and deserves the procedure in its own
# idiom: that is this door. The target is therefore never an argument —
# it is the station the door is running in, named by BURD_REGIME_FILE.
#
# The engine is the parcel's own bundled binary and never a binary
# standing in the consumer tree. A consumer-tree binary is precisely
# what an emplace REPLACES, so running the procedure through one asks a
# file to survive its own overwrite; and the parcel is a self-contained
# unit whose bash bootstrap already resolves its engine this way.
#
# The parcel arrives as an explicit path and is never searched for. A
# door that picked the newest tarball in some drop directory would
# choose the operator's parcel for them, and the choice would go
# unstated in the log at exactly the moment it mattered.
#
# Past the emplace this door only READS. Its own file sits in the
# directory the emplace just replaced, so a post-emplace write would be
# a write from a script that no longer stands where it thinks it does.
# That is structural here rather than merely avoided: nothing after the
# engine call writes anything, and the reporting is a git status and a
# console line.
#
# The clean-tree gate is deliberately absent. The install procedure
# carries its own — the engine refuses a dirty target and says so — and
# that gate is what makes the delta this door leaves legible. A second
# implementation of it in bash would be a second place for the rule to
# drift from its home.
#
# Sealing that delta is the caller's act (BUr_k7d). This door commits
# nothing and stages nothing in the target tree.

set -euo pipefail

source "${BURD_BUK_DIR}/buc_command.sh"
source "${BURD_BUK_DIR}/buym_yelp.sh"

######################################################################
# Tinder constants

# Where a parcel keeps its brand file and its bundled engine, relative
# to the parcel root. Both are the parcel's own layout, minted by the
# release procedure and read by the parcel's bash bootstrap.
readonly BUPE_brand_relpath="vvbf_brand.json"
readonly BUPE_engine_dir_relpath="kits/vvk/bin"
readonly BUPE_engine_stem="vvx-"

# The engine subcommand that performs the install procedure.
readonly BUPE_emplace_verb="vvx_emplace"

######################################################################
# Command Functions

bupe_emplace() {
  buc_doc_brief "Emplace an extracted parcel into this station (the lit-station maintenance door)"
  buc_doc_param "parcel-dir" "Extracted parcel directory, carrying ${BUPE_brand_relpath} and kits/"
  buc_doc_shown || return 0

  # The folio arrives on the param1 channel: the parcel directory, named
  # by the operator. There is no fallback and no search — a door with
  # nothing named has nothing to install.
  local -r z_parcel="${BUZ_FOLIO:-}"
  test -n "${z_parcel}" || buc_die_now "Emplacement needs the extracted parcel directory as its argument"
  test -d "${z_parcel}" || buc_die_now "Parcel directory not found: ${z_parcel}"

  local -r z_brand="${z_parcel}/${BUPE_brand_relpath}"
  test -f "${z_brand}" || buc_die_now "Not an extracted parcel (no ${BUPE_brand_relpath}): ${z_parcel}"

  # Platform from bash's own knowledge rather than a spawned uname: the
  # dispatch regime carries the OS it saw, and bash carries the machine
  # type it was built for. Neither costs a process or a new dependency.
  local z_platform=""
  case "${BURD_OSTYPE}-${HOSTTYPE}" in
    darwin*-arm64)    z_platform="darwin-arm64"   ;;
    darwin*-x86_64)   z_platform="darwin-x86_64"  ;;
    linux*-x86_64)    z_platform="linux-x86_64"   ;;
    linux*-aarch64)   z_platform="linux-aarch64"  ;;
    cygwin*-x86_64)   z_platform="windows-x86_64" ;;
    msys*-x86_64)     z_platform="windows-x86_64" ;;
    mingw*-x86_64)    z_platform="windows-x86_64" ;;
    *) buc_die_now "Unsupported platform: ${BURD_OSTYPE}-${HOSTTYPE}" ;;
  esac

  local -r z_engine="${z_parcel}/${BUPE_engine_dir_relpath}/${BUPE_engine_stem}${z_platform}"
  test -f "${z_engine}" || buc_die_now "Parcel carries no engine for this platform: ${z_engine}"
  test -x "${z_engine}" || chmod +x "${z_engine}" || buc_die_now "Cannot make parcel engine executable: ${z_engine}"

  # The target is the station this door is running in, never an
  # argument. BURD_REGIME_FILE is that station's own burc.env, resolved
  # by the dispatch that reached us.
  local -r z_burc="${BURD_REGIME_FILE}"
  test -f "${z_burc}" || buc_die_now "This station's regime file not found: ${z_burc}"

  buc_step "Emplacing parcel through its own bundled engine"
  buc_log_args "Parcel:   ${z_parcel}"
  buc_log_args "Engine:   ${z_engine}"
  buc_log_args "Platform: ${z_platform}"
  buc_log_args "Target:   ${z_burc}"

  "${z_engine}" "${BUPE_emplace_verb}" --parcel "${z_parcel}" --burc "${z_burc}" \
    || buc_die_now "Emplacement failed: ${z_engine} ${BUPE_emplace_verb}"

  # Everything below this line reads and reports. The kit directory this
  # door lives in has just been replaced.
  buc_step "Reporting the uncommitted delta (reads only from here)"

  # The working directory is the target repo root: every tabtarget
  # dispatches through the trampoline, which normalizes it there before
  # any workbench runs.
  git status --short || buc_die_now "Failed to read the target tree's status"

  buc_success "Emplaced — the delta stands whole and uncommitted; sealing it is yours"
}

######################################################################
# Furnish and Main

zbupe_furnish() {
  buc_doc_env_row "BURD_BUK_DIR          " "BUK module directory (dispatch-provided)"
  buc_doc_env_row "BURD_REGIME_FILE      " "This station's own burc.env (dispatch-provided)"
  buc_doc_env_row "BURD_OSTYPE           " "Operating-system type at dispatch time (dispatch-provided)"
  buc_doc_env_done || return 0
}

buc_execute bupe_ "BUK Parcel Emplacement" zbupe_furnish "$@"

# eof
