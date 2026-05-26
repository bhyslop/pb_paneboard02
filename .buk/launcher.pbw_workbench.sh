#!/bin/bash
# Launcher stub - delegates to pbw workbench
source "${BASH_SOURCE[0]%/*}/../Tools/buk/bul_launcher.sh"
bul_launch "${BURC_TOOLS_DIR}/pbk/pbw_workbench.sh" "$@"
