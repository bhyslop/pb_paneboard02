# PaneBoard Project Memo


### Intent

PaneBoard is a **cross-platform desktop utility** that re-creates and extends classic Windows productivity patterns on macOS, Linux, and Windows. It aims to provide:

1. **Alt-Tab Replacement**

   * Fast, predictable task switching.
   * Customizable ordering (e.g., MRU vs fixed cycle).

2. **WinSplit-Style Window Management**

   * Grid-based tiling and snapping.
   * Keyboard-driven pane resizing and movement.
   * Profiles for multi-monitor setups.

3. **Clipboard Memory / Manager**

   * Keeps history of copied items (text, images, files).
   * Quick recall via hotkey.
   * Privacy-conscious retention and clear-all.

---

### Technical Goals

* **Written in Rust** for safety, speed, and portability.
* **Minimal native glue** per platform (AppKit on macOS, Win32 APIs on Windows, X11/Wayland on Linux).
* Unified **hotkey and event abstraction layer** so the same Rust code can drive all three environments.
* Lightweight, no heavy dependencies (focus on `winit`, `tao`, `copypasta`, etc.).

---

### Philosophy

* Be a **trusted utility**: transparent, auditable, and not phoning home.
* Prioritize **keyboard-centric workflow**.
* Consistent feel across platforms — bring Windows productivity habits to macOS/Linux without friction.

---

### Proof of Concept Specification

The **authoritative PoC specification** is maintained in:

**`poc/paneboard-poc.md`**

This document defines:
* Core keyboard capture architecture (IOHID + CGEventTap hybrid)
* Alt-Tab MRU implementation and overlay requirements
* Quadrant tiling geometry (visible frame enforcement, Position→Size policy)
* Clipboard history and Windows-style shortcut mirroring
* Acceptance criteria, logging contracts, and edge case handling

All PoC implementation decisions, debugging notes, and developer learnings are captured there.

---

### Source Naming Philosophy

PaneBoard uses a structured naming scheme to identify platform and feature affiliation at a glance.

**Pattern**

```
pb<platform><feature><uniquifier>_<descriptor>.<ext>
```
- `platform` – g (generic), m (macOS), w (Windows), l (Linux)
- `feature` – s (switcher), c (clipboard), p (pane) — **only for platform-specific files**
- `uniquifier` – additional letters ensuring unique acronyms
- All lowercase; each acronym maps to exactly one file

**Exception:** `main.rs` retains standard Rust naming convention

### Layout Configuration System

Window layouts are defined in XML using the schema in `pbxs_schema.xsd`.

**Elements:**
* **Form** - Root configuration document
* **Space** - Display matching rules (name, orientation, resolution)
* **Frame** - Reusable pane geometries (x, y, width, height as percentages)
* **Layout** - Composition of frames with conditional logic
* **Binding** - Keyboard shortcuts mapped to layouts with traversal order

Example configurations: `poc/layouts.default.xml`, `poc/layouts.multi-select.xml`

---

### Current File Map

**All files located in:** `poc/src/`

| File | Responsibility |
|------|----------------|
| `main.rs` | Program entry point and runtime orchestration |
| `pbgc_core.rs` | Generic core constants and state structures |
| `pbgr_retry.rs` | Generic retry and timing utilities |
| `pbgk_keylog.rs` | Optional diagnostic key state logging |
| `pbgx_layout.rs` | Generic layout and geometry utilities |
| `pbxs_schema.xsd` | XML schema defining layout configuration format |
| `pbmba_ax.rs` | Core AX FFI, types, and RAII wrappers shared across features |
| `pbmbe_eventtap.rs` | Main event tap that dispatches to all features |
| `pbmbd_display.rs` | NSScreen enumeration and visible frame calculations |
| `pbmbk_keymap.rs` | Key code mappings and virtual key to HID conversions |
| `pbmbo_overlay.rs` | Base overlay rendering utilities |
| `pbmbo_observer.h` | C-ABI header for NSWorkspace observers |
| `pbmbo_observer.rs` | App activation/termination observers for switcher |
| `pbmbo_observer.swift` | Swift NSWorkspace observers and overlay |
| `pbmcl_clipboard.rs` | Clipboard history management and monitoring |
| `pbmp_pane.rs` | Window tiling and geometry |
| `pbmsa_alttab.rs` | Alt-Tab session state and overlay UI coordination |
| `pbmsb_browser.rs` | MRU browser logic for switcher |
| `pbmsm_mru.rs` | MRU stack management and window tracking |

**Note:** The file naming convention uses 'b' for base/shared macOS components, and 'x' for cross-platform XML/schema files