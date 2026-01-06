#!/bin/bash
# TabTarget - delegates to jjw workbench via launcher
exec "$(dirname "${BASH_SOURCE[0]}")/../.buk/launcher.jjw_workbench.sh" \
  "${0##*/}" "${@}"
