#!/bin/bash
# TabTarget - delegates to vvw workbench via launcher
exec "$(dirname "${BASH_SOURCE[0]}")/../.buk/launcher.vvw_workbench.sh" \
  "${0##*/}" "${@}"
