#!/bin/bash
# Generated tabtarget - delegates to pbw launcher
exec "$(dirname "${BASH_SOURCE[0]}")/../.buk/launcher.pbw_workbench.sh" "pbw-p" "${@}"
