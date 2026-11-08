## Voce Viva Kit (VVK)

VVK provides core infrastructure for Claude Code kits.

**Key files:**
- `Tools/vvk/bin/vvx` — Core binary
- `.vvm/vvmt_tamga.json` — Installation record

Installation and uninstallation both run from an extracted parcel, whose root carries
the parcel kit's `bpi_install.sh` and `bpu_uninstall.sh` beside the platform binary that executes them;
each takes the target repo's own `burc.env` path as its argument.

## Acronym Notes

- **VVS0** → `specs/vvk/VVS0-VoceVivaSpec.adoc` (Voce Viva Specification — the codex: the kit's interior, contract and lading surfaces; a shell holding no premise, sheaf or operation.)
