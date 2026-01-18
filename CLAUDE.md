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

<!-- MANAGED:BUK:BEGIN -->
## Bash Utility Kit (BUK)

BUK provides tabtarget/launcher infrastructure for bash-based tooling.

**Key files:**
- `Tools/buk/buc_command.sh` — command utilities
- `Tools/buk/bud_dispatch.sh` — dispatch utilities
- `Tools/buk/buw_workbench.sh` — workbench formulary

**Tabtarget pattern:** `{colophon}.{frontispiece}[.{imprint}].sh`

For full documentation, see `Tools/buk/README.md`.

<!-- MANAGED:BUK:END -->

<!-- MANAGED:CMK:BEGIN -->
## Concept Model Kit Configuration

Concept Model Kit (CMK) is installed for managing concept model documents.

**Configuration:**
- Lenses directory: `lenses`
- Kit path: `Tools/cmk/README.md`
- Upstream remote: `OPEN_SOURCE_UPSTREAM`

**Concept Model Patterns:**
- **Linked Terms**: `{category_term}` - references defined vocabulary
- **Attribute References**: `:category_term: <<anchor,Display Text>>` - in mapping section
- **Anchors**: `[[anchor_name]]` - definition targets
- **Annotations**: `// ⟦content⟧` - Strachey brackets for type categorization

**Available commands:**
- `/cma-normalize` - Apply full MCM normalization (haiku)
- `/cma-render` - Transform to ClaudeMark (sonnet)
- `/cma-validate` - Check links and annotations
- `/cma-prep-pr` - Prepare upstream contribution
- `/cma-doctor` - Validate installation

**Subagents:**
- `cmsa-normalizer` - Haiku-enforced MCM normalization (text, mapping, validation)

For full MCM specification, see `Tools/cmk/MCM-MetaConceptModel.adoc`.

**Important**: Restart Claude Code session after installation for new commands and subagents to become available.

<!-- MANAGED:CMK:END -->

<!-- MANAGED:JJK:BEGIN -->
## Job Jockey Configuration

Job Jockey (JJ) is installed for managing project initiatives.

**Concepts:**
- **Heat**: Bounded initiative with coherent goals that are clear and present (3-50 sessions). Location: `current/` (active) or `retired/` (done).
- **Pace**: Discrete action within a heat; can be bridled for autonomous execution via `/jjc-pace-bridle`
- **Itch**: Future work (any detail level), lives in jji_itch.md
- **Scar**: Closed work with lessons learned, lives in jjs_scar.md

**Identities vs Display Names:**
- **Firemark**: Heat identity (`₣AA` or `AA`). Used in CLI args and JSON keys.
- **Coronet**: Pace identity (`₢AAAAk` or `AAAAk`). Used in CLI args and JSON keys.
- **Silks**: kebab-case display name. Human-readable only — NOT usable for lookups.

When a command takes `<firemark>` or `<coronet>`, provide the identity, not the silks.

- Target repo dir: `.`
- JJ Kit path: `Tools/jjk/README.md`

**JJ Slash Command Reference:**

ALWAYS read the corresponding slash command before attempting JJ operations.

**CRITICAL**: JJK CLI syntax is non-standard. Do NOT guess based on common CLI conventions.
- Specs go via stdin, not `--spec`
- Positioning uses `--move X --first`, not `--position first`
- Read the slash command to see the exact `./tt/vvw-r.RunVVX.sh jjx_*` invocation pattern.

| When you need to... | Read first |
|---------------------|------------|
| Add a new pace | /jjc-pace-slate |
| Refine pace spec | /jjc-pace-reslate |
| Bridle for autonomous execution | /jjc-pace-bridle |
| Mark pace complete | /jjc-pace-wrap |
| Commit with JJ context | /jjc-pace-notch |
| Execute next pace | /jjc-heat-mount |
| Review heat plan | /jjc-heat-groom |
| Evaluate bridleable paces | /jjc-heat-quarter |
| Reorder paces | /jjc-heat-rail |
| Add steeplechase marker | /jjc-heat-chalk |
| Create new heat | /jjc-heat-nominate |
| List all heats | /jjc-heat-muster |
| Draft paces between heats | /jjc-heat-restring |
| Retire completed heat | /jjc-heat-retire |
| View heat summary | /jjc-parade-overview |
| View pace order | /jjc-parade-order |
| View heat detail | /jjc-parade-detail |
| View full heat | /jjc-parade-full |

**Quick Verbs** — When user says just the verb, invoke the corresponding command:

| Verb | Command |
|------|---------|
| mount | /jjc-heat-mount |
| slate | /jjc-pace-slate |
| wrap | /jjc-pace-wrap |
| bridle | /jjc-pace-bridle |
| muster | /jjc-heat-muster |
| groom | /jjc-heat-groom |
| quarter | /jjc-heat-quarter |

**Build & Run Discipline:**
Always run these after Rust code changes:
- `tt/vow-b.Build.sh` — Build
- `tt/vvw-r.RunVVX.sh` — Run VVX

**Important**: New commands are not available in this installation session. You must restart Claude Code before the new commands become available.

### Bridleability Assessment

When evaluating whether a pace is ready for autonomous execution (bridled state), apply these criteria:

**Bridleable** (can bridle for autonomous execution) — ALL must be true:
- **Mechanical**: Clear transformation, not design work
- **Pattern exists**: Following established pattern, not creating new one
- **No forks**: Single obvious approach, not "we could do X or Y"
- **Bounded**: Touches known files, not "find where this should go"

**NOT bridleable** (needs human judgment):
- Language like "define", "design", "architect", "decide"
- Establishing new patterns others will follow
- Multiple valid approaches requiring human choice
- Scope unclear or requires judgment calls

**Examples:**
- ✓ Bridleable: "Rename function `getCwd` to `getCurrentWorkingDirectory` across codebase"
- ✓ Bridleable: "Add error handling to `fetchUser` following pattern in `fetchOrder`"
- ✗ Not bridleable: "Define KitAsset struct and registry pattern" (design decisions)
- ✗ Not bridleable: "Improve performance of dashboard" (unclear scope, many approaches)

<!-- MANAGED:JJK:END -->

<!-- MANAGED:VVK:BEGIN -->
## Voce Viva Kit (VVK)

VVK provides core infrastructure for Claude Code kits.

**Key commands:**
- `/vvc-commit` — Guarded git commit with size validation

**Key files:**
- `Tools/vvk/bin/vvx` — Core binary
- `.vvk/vvbf_brand.json` — Installation brand file

For installation/uninstallation, use `vvi_install.sh` and `vvu_uninstall.sh`.

<!-- MANAGED:VVK:END -->
