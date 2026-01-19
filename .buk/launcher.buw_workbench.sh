#!/bin/bash
# Launcher stub - delegates to buw workbench
source "${BASH_SOURCE[0]%/*}/launcher_common.sh"
bud_launch "${BURC_TOOLS_DIR}/buk/buw_workbench.sh" "$@"
