## Voce Viva Kit (VVK)

VVK provides core infrastructure for Claude Code kits.

**Key files:**
- `Tools/vvk/bin/vvx` — Core binary
- `.vvk/vvbf_brand.json` — Installation brand file

Installation and uninstallation both run from an extracted parcel, whose root carries
`vvi_install.sh` and `vvu_uninstall.sh` beside the platform binary that executes them;
each takes the target repo's own `burc.env` path as its argument.
`vvu_uninstall.sh` also runs in place from `Tools/vvk/` in a repo whose parcel carried vvk,
resolving the canonical binary beside it.
