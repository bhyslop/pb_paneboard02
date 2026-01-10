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

**Configuration Source:**
* Default config source: `poc/form.default.xml` (embedded at build time via `include_str!()`)
* Runtime config location: `~/.config/paneboard/form.xml`
* At every startup, existing `form.xml` is archived to `form.xml.NNNNN` (starting at 10000) and replaced with the embedded default
* This ensures the latest compiled configuration is always used, while preserving user edits for manual inspection

**Elements:**
* **Form** - Root configuration document
* **Measure** - Named pixel constants for display matching
* **Space** - Display matching rules (name, orientation, resolution)
* **Frame** - Reusable pane geometries (x, y, width, height as percentages)
* **Layout** - Composition of frames with conditional logic
* **LayoutAction** - Keyboard shortcuts mapped to layouts with traversal order
* **DisplayMove** - Keyboard shortcuts for moving windows between displays
* **Application** - Per-application behavior overrides with platform-specific matchers
  - **Mac** / **Windows** / **Linux** - Platform-specific application identifiers
  - **Clipboard** - Clipboard monitoring and mirroring behavior

---

### Current File Map

| File | Responsibility |
|------|----------------|
| `poc/src/main.rs` | Program entry point and runtime orchestration |
| `poc/src/pbgc_core.rs` | Generic core constants and state structures |
| `poc/src/pbgr_retry.rs` | Generic retry and timing utilities |
| `poc/src/pbgk_keylog.rs` | Optional diagnostic key state logging |
| `poc/src/pbgx_layout.rs` | Generic layout and geometry utilities |
| `poc/src/pbxs_schema.xsd` | XML schema defining layout configuration format |
| `poc/src/pbmba_ax.rs` | Core AX FFI, types, and RAII wrappers shared across features |
| `poc/src/pbmbe_eventtap.rs` | Main event tap that dispatches to all features |
| `poc/src/pbmbd_display.rs` | NSScreen enumeration and visible frame calculations |
| `poc/src/pbmbk_keymap.rs` | Key code mappings and virtual key to HID conversions |
| `poc/src/pbmbo_overlay.rs` | Base overlay rendering utilities |
| `poc/src/pbmbo_observer.h` | C-ABI header for NSWorkspace observers |
| `poc/src/pbmbo_observer.rs` | App activation/termination observers for switcher |
| `poc/src/pbmbo_observer.swift` | Swift NSWorkspace observers and overlay |
| `poc/src/pbmbs_sandbox.rs` | macOS Seatbelt sandbox to permanently block network access |
| `poc/src/pbmcl_clipboard.rs` | Clipboard history management and monitoring |
| `poc/src/pbmp_pane.rs` | Window tiling and geometry |
| `poc/src/pbmsa_alttab.rs` | Alt-Tab session state and overlay UI coordination |
| `poc/src/pbmsb_browser.rs` | MRU browser logic for switcher |
| `poc/src/pbmsm_mru.rs` | MRU stack management and window tracking |

**Note:** The file naming convention uses 'b' for base/shared macOS components, and 'x' for cross-platform XML/schema files

---

### Motet

**Motet** = Sema + Coda (parallel agent workflow for spec + implementation changes)

Configured agents in `.claude/agents/`:
- **sema.md** - Spec agent: updates documentation and schemas (`.md`, `.xsd`)
- **coda.md** - Implementation agent: writes and modifies code (`.rs`, `.xml`, `.swift`, `.h`, build files)

**Usage pattern:**
- Dispatch both agents in parallel for changes with clean file domain separation
- Each agent uses Sonnet model for complex reasoning
- No filesystem snapshot guarantees - strict file orthogonality required to avoid conflicts
- Use code anchors (function names, unique strings) not line numbers in prompts

**Orchestration patterns:**
- **Simple**: Sema + Coda in parallel (2 agents)
- **Fan-out**: Planner agent → multiple Coda instances for orthogonal changes (up to 10 concurrent)
- **Sequential**: Planner → review → workers (when conflicts possible)

**Key constraint**: Agents cannot spawn subagents. Claude orchestrates all dispatch and integration.

---

### BUK Bash Patterns

BCG (Bash Console Guide) is the authoritative reference for enterprise bash patterns used by BUK utilities.

- **BCG** → `Tools/buk/lenses/bpu-BCG-BashConsoleGuide.md`

---

### Contributing to Upstream (Prep PR Workflow)

**Branch Strategy:**
- **develop** - Default branch for daily work; contains all internal files (CLAUDE.md, paneboard-poc.md, etc.)
- **main** - Clean mirror of `OPEN_SOURCE_UPSTREAM/main`; never commit directly
- **candidate-###-#** - Ephemeral PR branches; created from main, exclude internal files
  - `###` = batch/PR number (increments for each new contribution)
  - `#` = revision within batch (starts at 1, increments if fixes needed)

**Remotes:**
- **origin** - Your fork (github.com/bhyslop/pb_paneboard02)
- **OPEN_SOURCE_UPSTREAM** - Original repo (github.com/scaleinv/paneboard)

**Prep PR Procedure:**

1. Ensure develop is clean and pushed
2. Sync main with upstream
3. Create PR branch from main
4. Cherry-pick or apply selected changes
5. Verify internal files are excluded
6. Manual review and push

**Commands:**
```bash
# 1. Verify develop is clean
git checkout develop
git status
git push origin develop

# 2. Sync main with upstream
git fetch OPEN_SOURCE_UPSTREAM
git branch -f main OPEN_SOURCE_UPSTREAM/main
git push origin main --force

# 3. Create PR branch (use next available batch number)
git checkout -b candidate-NNN-1 main

# 4. Cherry-pick commits (identify SHAs from develop)
git log develop --oneline -20
git cherry-pick <SHA1> <SHA2> ...

# 5. Verify no internal files present
git ls-files | grep -E '(CLAUDE\.md|paneboard-poc\.md|REFACTORING_ROADMAP\.md|\.claude/)'

# 6. Review changes, then push
git log --stat
# Manual: git push -u origin candidate-NNN-1
```

**Files to exclude from PRs (all markdown except README.md):**
- CLAUDE.md
- .claude/ directory (including agents/, commands/, all configuration)
- poc/paneboard-poc.md
- poc/REFACTORING_ROADMAP.md
- Any other internal notes/documentation

**Note:** README.md is the ONLY markdown file that should be included in upstream PRs.

**Slash Commands:**
- `/prep-pr` - Automated workflow to prepare a candidate branch for upstream contribution