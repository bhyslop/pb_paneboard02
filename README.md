# PaneBoard — Proof of Concept

> **PRE-ALPHA SOFTWARE**: This is an early-stage proof of concept demonstrating cross-platform keyboard-driven window management and application switching. Not intended for production use.

## What is PaneBoard?

PaneBoard is a **cross-platform desktop utility** that brings Windows productivity patterns to macOS, Linux, and Windows. Written in Rust, it provides:

- **Alt-Tab Replacement** – Fast, MRU-based task switching with a visual overlay
- **Keyboard-Driven Window Tiling** – Grid-based snapping and quadrant layouts (WinSplit-style)
- **Clipboard Manager** *(planned)* – History and quick recall for copied items

This repository contains the **macOS proof of concept**, demonstrating core keyboard capture, window management, and application switching capabilities.

## Current Status (macOS PoC)

| Feature | Status |
|---------|--------|
| Alt-Tab (MRU window switching) | ✅ Working |
| Quadrant window tiling | ✅ Working |
| Clipboard history | ⏳ Not ready |

## System Requirements

- **macOS Sequoia (15.0) or later**
- **Rust 1.90.0 or later**

## Setup Instructions

### 1. Install Rust

If you don't have Rust installed, get it from [rustup.rs](https://rustup.rs):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Verify installation:

```bash
rustc --version  # Should show 1.90.0 or later
cargo --version
```

### 2. Clone and Build

```bash
git clone https://github.com/your-org/paneboard.git
cd paneboard/poc
cargo build --release
```

The binary will be at `target/release/paneboard-poc`.

### 3. Grant System Permissions

PaneBoard requires two macOS permissions to function:

1. **Accessibility**
   → System Settings → Privacy & Security → Accessibility
   → Add and enable your terminal app (Terminal.app, iTerm2, etc.)

2. **Input Monitoring**
   → System Settings → Privacy & Security → Input Monitoring
   → Add and enable your terminal app

**Note**: When running from a terminal, macOS grants permissions to the *terminal application*, not the binary itself. After granting permissions, restart your terminal.

### 4. Run

```bash
./target/release/paneboard-poc
```

If permissions are missing, PaneBoard will exit with an error message pointing you to the correct System Settings panel.

## Usage

### Alt-Tab Switching

- **⌘ + Tab** – Show window switcher overlay
- **⌘ + Shift + Tab** – Navigate backwards
- Release **⌘** to switch to the highlighted window

The overlay shows all accessible windows in most-recently-used order, with app icons and titles.

### Window Tiling (Quadrant Snapping)

Resize the focused window to screen quadrants using:

| Shortcut | Action |
|----------|--------|
| **⌃⇧ Insert** | Upper-left quadrant |
| **⌃⇧ Delete** | Lower-left quadrant |
| **⌃⇧ Home** | Upper-right quadrant |
| **⌃⇧ End** | Lower-right quadrant |
| **⌃⇧ Page Up** | Move window to previous display |
| **⌃⇧ Page Down** | Move window to next display |

*Notes:*
- **Insert** on PC keyboards often maps to **Help (0x72)** on macOS
- **Delete** means **Forward Delete**, not Backspace
- Quadrants respect the menu bar and Dock (use screen visible frame)

## Architecture

PaneBoard uses a **hybrid keyboard capture** approach on macOS:

- **IOHIDManager** – Low-level HID events for left/right modifier fidelity
- **CGEventTap** – Selective blocking of system shortcuts (e.g., ⌘+Tab takeover)
- **Accessibility API (AX)** – Window enumeration, focus tracking, and geometry manipulation

See [`poc/paneboard-poc.md`](poc/paneboard-poc.md) for the full technical specification and implementation notes.

## Project Structure

```
paneboard/
├── LICENSE              # Apache 2.0
├── README.md            # This file
├── CLAUDE.md            # Project philosophy and naming conventions
└── poc/
    ├── paneboard-poc.md # Detailed PoC specification
    ├── Cargo.toml       # Rust dependencies
    └── src/             # Source code (see naming philosophy in CLAUDE.md)
```

## Known Limitations

- **macOS only** – Linux and Windows implementations are planned but not started
- **Clipboard** – History feature is specified but not implemented
- **No persistence** – Configuration and state are not saved between runs
- **Pre-alpha stability** – Expect rough edges and incomplete error handling

## License

Copyright 2025 Scale Invariant

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

## Questions or Issues?

This is a proof-of-concept release. For technical details, see [`poc/paneboard-poc.md`](poc/paneboard-poc.md).
