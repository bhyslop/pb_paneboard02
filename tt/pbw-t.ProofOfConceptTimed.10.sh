#!/bin/bash
export BURD_LAUNCHER=launcher.pbw_workbench.sh
export BURD_NO_LOG=1
exec "${BASH_SOURCE[0]%/*}/z-launcher.sh" "${0##*/}" "${@}"
