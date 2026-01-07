#!/bin/bash
# Launcher stub - delegates to BUK tabtarget CLI
source "${BASH_SOURCE[0]%/*}/launcher_common.sh"
bud_launch "${BURC_TOOLS_DIR}/buk/buut_cli.sh" "$@"
