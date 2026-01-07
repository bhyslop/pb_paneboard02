#!/bin/bash
# Launcher stub - delegates to PBK workbench
source "${BASH_SOURCE[0]%/*}/launcher_common.sh"
bud_launch "${BURC_TOOLS_DIR}/pbk/pbw_workbench.sh" "$@"
