# VVK - Voce Viva Kit

The living voice. User-facing tooling produced by VOK.

VVK is the **distributable artifact** that travels from source repo to target repos. It contains platform binaries and bash utilities that scripts and slash commands invoke.

## Directory Structure

```
Tools/vvk/
  bin/
    vvx                   # Platform-selecting wrapper
    vvr-darwin-arm64      # Platform binaries (populated by release)
    vvr-darwin-x86_64
    vvr-linux-x86_64
    vvr-linux-aarch64
    vvr-windows-x86_64.exe
  README.md               # This file
```

## Platform Wrapper (vvx)

The `vvx` script detects the current platform and executes the appropriate `vvr-{platform}` binary.

```bash
# Usage
Tools/vvk/bin/vvx --version
Tools/vvk/bin/vvx guard --limit 500000
```

**Supported platforms:**
- `darwin-arm64` — macOS Apple Silicon
- `darwin-x86_64` — macOS Intel
- `linux-x86_64` — Linux Intel/AMD, WSL, CI
- `linux-aarch64` — AWS Graviton, ARM servers
- `windows-x86_64` — Windows (MINGW/MSYS)

## vvr Subcommands

The `vvr` binary (invoked via `vvx`) provides:

### guard

Pre-commit size validation. Measures staged blob sizes to prevent accidental large commits.

```
vvx guard [--limit <bytes>] [--warn <bytes>]
```

**Exit codes:**
- 0 — Under limit
- 1 — Over limit (blocks commit)
- 2 — Over warn threshold (proceed with caution)

## Installation

VVK reaches a consumer by parcel. The forge mints one per target with the
`tt/vow-R.ParcelRelease.sh` tabtarget, naming the target's own `burc.env` —
the argument `vvi_install.sh` takes — and cutting exactly the kits it declares;
the parcel carries `Tools/vvk/` and one
platform binary (`bin/vvx-<platform>`) built from VOK at release time. The install
writes it at the canonical `Tools/vvk/bin/vvx`, an ordinary delivered file the
consumer commits with the rest of its install delta; only the forge ignores its
own build output. `vvi_install.sh` at the parcel root emplaces it (the
rescue door for a dark station); `tt/buw-pe.ParcelEmplace.sh` is the maintenance
door on a lit station.

**Do not install VVK by hand.** Emplace a parcel.

## Relationship to VOK

```
VOK (Vox Obscura Kit)     - Source repo only, never distributed
       ↓ (release process)
VVK (Voce Viva Kit)       - Distributed to target repos
  └── vvx → vvr           - What users invoke
```

VOK compiles the `vvr` binary and prepares releases. VVK is the installable artifact containing the wrapper, utilities, and binaries.
