#!/bin/bash
export BURD_LAUNCHER=launcher.jjw_workbench.sh
exec "${BASH_SOURCE[0]%/*}/z-launcher.sh" "${0##*/}" "${@}"
