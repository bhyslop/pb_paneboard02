#!/bin/bash
export BUD_LAUNCHER=".buk/launcher.pbw_workbench.sh"
export BUD_NO_LOG=1
exec "$(dirname "${BASH_SOURCE[0]}")/../${BUD_LAUNCHER}" "${0##*/}" "${@}"
