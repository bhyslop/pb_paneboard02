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
# z-launcher.sh — universal tabtarget trampoline.
#
# Every tt/*.sh dispatches through here, saying its configuration on one line
# ahead of its exec:
#   set -- 'launcher.<id>_workbench.sh[ buuc_…]' "$@"
#   exec "${BASH_SOURCE[0]%/*}/z-launcher.sh" "${0##*/}" "${@}"
#
# so this file receives the tabtarget basename, then the configuration, then
# the user's arguments, and exports nothing. Three responsibilities:
#   1. Find the launcher stub the configuration's first word names, refusing a
#      missing configuration or an absent stub.
#   2. Normalize cwd to the repository root, so every workbench starts from a
#      deterministic directory whatever directory the user invoked from.
#   3. Exec the launcher stub, handing it the configuration, the seat (the
#      directory whose tt/ this file was reached through) and the moorings
#      directory, then the tabtarget basename and the user's arguments.
#
# This file is the SOLE place that knows where your repository keeps its
# moorings directory. The kit consumes the absolute path handed below rather
# than hardcoding a directory name, which is what lets one kit serve every
# repository — so this trampoline is yours to write, and no door generates it.

set -u

zbpt_trampoline_die() {
  echo "z-launcher: ${1}" >&2 || exit 1
  exit 1
}

# Resolve own directory to an absolute path before any chdir.
z_dir="${BASH_SOURCE[0]%/*}"
case "${z_dir}" in
  /*) ;;
  *)  z_dir="${PWD}/${z_dir}" ;;
esac

# Your repository's moorings directory, a child of the repository root. It holds
# burc.env and the launcher subdirectory.
z_moorings_dir=".buk"

z_canonical="set -- 'launcher.<id>_workbench.sh[ buuc_…]' \"\$@\""

# The configuration's first word names the launcher stub. A stub carrying no
# configuration line hands the user's first argument here, or nothing.
z_configuration=""
test "$#" -lt 2 || z_configuration="${2:-}"
z_launcher_name="${z_configuration%% *}"
case "${z_launcher_name}" in
  launcher.*.sh) ;;
  *) zbpt_trampoline_die "no configuration was handed; it is said on one line ahead of the exec: ${z_canonical}" ;;
esac

# Resolve the launcher basename under the moorings launcher subdirectory. The
# subdirectory name `buml_launchers` is read by the kit as a literal, so it is
# not yours to choose.
z_launcher="${z_dir}/../${z_moorings_dir}/buml_launchers/${z_launcher_name}"

# Fail loud on a mistyped launcher rather than dispatching silently to nothing.
test -f "${z_launcher}" \
  || zbpt_trampoline_die "no stub '${z_launcher_name}' (looked for ${z_launcher}), named by the configuration line: ${z_canonical}"

# Normalize cwd to the repository root for the dispatched workbench; the seat is
# the directory reached, absolute and symlink-resolved.
cd -P "${z_dir}/.." || zbpt_trampoline_die "cannot cd to repo root"

# Hand the launcher stub the configuration, the seat and the moorings directory
# (absolute, cd-proof), then the tabtarget basename and the user's arguments.
exec "${z_launcher}" "${z_configuration}" "${PWD}" "${PWD}/${z_moorings_dir}" "${1:-}" "${@:3}" \
  || zbpt_trampoline_die "cannot exec ${z_launcher}"
