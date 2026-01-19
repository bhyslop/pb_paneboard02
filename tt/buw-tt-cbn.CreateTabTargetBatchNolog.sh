#!/bin/bash
export BUD_LAUNCHER=".buk/launcher.buw_workbench.sh"
exec "$(dirname "${BASH_SOURCE[0]}")/../${BUD_LAUNCHER}" "${0##*/}" "${@}"
