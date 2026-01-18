#!/bin/bash
# Launcher stub - delegates to vvw workbench
source "${BASH_SOURCE[0]%/*}/../Tools/buk/bul_launcher.sh"
bul_launch "${BURC_TOOLS_DIR}/vvk/vvw_workbench.sh" "$@"
