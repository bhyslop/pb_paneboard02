#!/bin/bash
# z-launcher.sh — paneboard's project-intimate tabtarget trampoline.
#
# This is the SOLE file that knows where paneboard keeps its config + launcher
# stubs (the .buk dir). The shared BUK kit (bul_launcher.sh) is config-dir-name
# neutral: it consumes BURD_CONFIG_DIR exported here rather than hardcoding a
# name, so the same distributed kit serves every consumer.
#
# Tabtargets dispatch through here:
#   exec "${BASH_SOURCE[0]%/*}/z-launcher.sh" <workbench-id> "${0##*/}" "${@}"
# e.g. <workbench-id> = vvw, jjw, pbw, buw.

set -u

# Resolve own directory to an absolute path before any chdir.
z_dir="${BASH_SOURCE[0]%/*}"
case "${z_dir}" in
  /*) ;;
  *)  z_dir="${PWD}/${z_dir}" ;;
esac

z_id="${1:-}"
test -n "${z_id}" || { echo "z-launcher: no workbench id given" >&2; exit 1; }

# Project-intimate config-dir anchor — paneboard keeps moorings/launchers in .buk
z_moorings_dir=".buk"
z_launcher="${z_dir}/../${z_moorings_dir}/launcher.${z_id}_workbench.sh"

test -f "${z_launcher}" || {
  echo "z-launcher: no launcher for '${z_id}' (looked for ${z_launcher})" >&2
  exit 1
}

# Normalize cwd to repo root for the dispatched workbench.
cd -P "${z_dir}/.." || { echo "z-launcher: cannot cd to repo root" >&2; exit 1; }

# Hand the config-dir location to the shared launcher (absolute, cd-proof).
export BURD_CONFIG_DIR="${PWD}/${z_moorings_dir}"
export BURD_LAUNCHER="${z_moorings_dir}/launcher.${z_id}_workbench.sh"

# Forward everything after the id: tabtarget basename + user args.
exec "${z_launcher}" "${@:2}"
