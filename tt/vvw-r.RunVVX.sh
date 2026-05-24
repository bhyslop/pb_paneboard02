#!/bin/bash
# TabTarget - delegates to vvw workbench via the project-intimate z-launcher
exec "$(dirname "${BASH_SOURCE[0]}")/z-launcher.sh" vvw \
  "${0##*/}" "${@}"
