#!/bin/bash
# TabTarget - delegates to pbw workbench via the project-intimate z-launcher
export BURD_NO_LOG=1
exec "$(dirname "${BASH_SOURCE[0]}")/z-launcher.sh" pbw \
  "${0##*/}" "${@}"
