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

<!-- MANAGED:JJK:BEGIN -->
## Job Jockey Configuration

Job Jockey (JJ) is installed for managing project initiatives.

**Concepts:**
- **Heat**: Bounded initiative with coherent goals that are clear and present (3-50 officia). Status: `racing` (active execution) or `stabled` (paused for planning). Location: `current/` or `retired/` (done).
- **Pace**: Discrete action within a heat.
- **Itch**: Future work (any detail level), lives in jji_itch.md
- **Scar**: Closed work with lessons learned, lives in jjs_scar.md
- **Spook**: Team infrastructure stumble — any workflow failure improvable with deft attention. Capture as a pace when encountered, don't lose the current thread.

**Identities vs Display Names:**
- **Firemark**: Heat identity (`₣AA` or `AA`). Used in command params and JSON keys.
- **Coronet**: Pace identity (`₢AAAAk` or `AAAAk`). Used in command params and JSON keys.
- **Silks**: kebab-case display name. Human-readable only — NOT usable for lookups.

When a command takes a firemark or coronet, provide the identity, not the silks.

- Target repo dir: `.`
- JJ Kit path: `Tools/jjk/README.md`

**MCP Tool Usage:**

All JJK commands are accessed via the single `mcp__vvx__jjx` MCP tool with two parameters:
- `command`: string selecting the operation — always the canonical `jjx_*` name (e.g., `"jjx_show"`, `"jjx_enroll"`, `"jjx_record"`)
- `params`: JSON object with command-specific fields (see reference below)

**Verb names are NOT command names**: there is no `jjx_slate`, `jjx_mount`, `jjx_notch`, `jjx_groom` command. The verb table below maps horse vocabulary to actual MCP commands.
NEVER invent param fields — check the reference below first.

**Quick Verbs** — When user says just the verb, invoke the corresponding command:

| Verb | Noun | MCP command |
|------|------|-------------|
| muster | heats | `jjx_list` |
| parade | heat/pace | `jjx_show` |
| scout | heats | `jjx_search` |
| nominate | heat | `jjx_create` |
| mount | heat/pace | See Mount Protocol below |
| groom | heat | See Groom Protocol below |
| slate | pace | `jjx_enroll` |
| reslate | pace | `jjx_redocket` |
| notch | pace | See Commit Discipline below |
| wrap | pace | `jjx_close` |
| rail | heat | `jjx_reorder` |
| furlough | heat | `jjx_alter` |
| retire | heat | `jjx_archive` |
| restring | heat | `jjx_transfer` |

**MCP Command Reference:**

All params are JSON objects. `?` = optional, `[]` = array. Booleans default to false.

```
jjx_show           {target?, detail?, remaining?}
jjx_list           {status?}
jjx_orient         {firemark?}
jjx_create         {silks}
jjx_enroll         {firemark, silks, docket, before?, after?, first?}
jjx_reorder        {firemark, move?, before?, after?, first?, last?}
jjx_alter          {firemark, racing?, stabled?, silks?}
jjx_record         {identity, files[], size_limit?, intent?}
jjx_close          {coronet, summary?, size_limit?}
jjx_log            {firemark, limit?}
jjx_search         {pattern, actionable?}
jjx_archive        {firemark, execute?, size_limit?}
jjx_transfer       {firemark, to, coronets}
jjx_continue       {firemark}
jjx_paddock        {firemark, content?, note?}
jjx_relocate       {coronet, to, before?, after?, first?}
jjx_redocket  {coronet, docket}
jjx_relabel        {coronet, silks}
jjx_drop           {coronet}
jjx_brief      {coronet}
jjx_coronets   {firemark, remaining?, rough?}
jjx_landing        {coronet, agent, content?}
jjx_validate       {}
```

**Key points:**
- `jjx_show` takes firemark OR coronet in the `target` param
  - Heat overview: `{"target": "AF"}`
  - Single pace: `{"target": "AFAAb"}`
  - Additional params: `detail`, `remaining` only
- `jjx_orient` output includes next actionable pace — no separate show call needed
- `jjx_enroll` takes `docket` as a string param (not stdin)
- `jjx_close` takes `summary` as a string param (not stdin pipe)
- `jjx_record` takes `files` as a native JSON array: `["file1.rs", "file2.rs"]`
- `jjx_transfer` takes `coronets` as a JSON-encoded string (not a native array): `"[\"AYAAA\", \"AYAAB\"]"`

### Mount Protocol

When user says "mount" or you need to engage the next pace:

1. Run `jjx_orient` command (with optional firemark) to get context
2. Parse output: Racing-heats table, Heat/Paddock/Next/Docket/Recent-work sections
3. Display context to user: racing heats, heat silks, paddock summary, recent work, current pace and docket
4. **Name assessment**: If pace silks doesn't fit docket, offer rename via `jjx_relabel`
5. Analyze docket, propose approach (2-4 bullets), assess execution strategy:
   - Model tier: haiku (mechanical), sonnet (standard dev), opus (architectural)
   - Parallelization: file independence, task decomposability
   - State recommendation explicitly (e.g., "Sequential sonnet — single file")
6. Ask to proceed, then begin work

### Groom Protocol

When user says "groom":

1. Run `jjx_show` command with `{target: FIREMARK, detail: true, remaining: true}`
2. Display overview: heat silks, progress, remaining paces with dockets
3. Enter planning mode: suggest structural operations (slate new paces, rail to reorder, reslate to refine dockets, paddock review)

### Commit Discipline

When working on a heat, use `jjx_record` for commits with heat/pace affiliation.

**Pace-affiliated commit** (active pace provides context):
Use `jjx_record` with `{identity: "CORONET", files: ["file1", "file2"], intent: "description"}`

**Heat-affiliated commit** (no active pace, but part of heat work):
Use `jjx_record` with `{identity: "FIREMARK", files: ["file1", "file2"], intent: "description"}`

Synthesize intent from the conversation — describe *what* was accomplished, not *how*.

**Size guard**: If the commit fails due to size limits, report the failure to the user and ask how to proceed. Do not retry silently.

When user says "notch", determine context (pace or heat affiliated) and invoke `jjx_record` with the appropriate identity and explicit file list.

**Multi-Officium Discipline:**
Multiple Claude officia (concurrent git-activity streams, not sessions — see VOS `vost_officium`) may work concurrently in the same repo. The explicit file list in `jjx_record` enables orthogonal commits.

- Claude is **additive only** — make commits, never discard changes
- "Unexpected" uncommitted changes are likely another officium's work
- If something looks wrong, ASK — do not "fix" by discarding
- Commit only YOUR files; ignore everything else

**Forbidden Git Commands — NO exceptions, NO "safe" variants:**
- `git reset` — ALL forms: `--hard`, `--soft`, `--mixed`, with paths, without paths. Even `git reset HEAD <file>` (unstaging) is forbidden — it's too close to destructive variants and Claude will reason its way into worse forms.
- `git restore` — ALL forms: working tree, staged, with `--source`, without
- `git checkout <file>` — when used to discard changes (navigating branches is fine)
- `git clean` — ALL forms
- `git stash` — ALL forms

**What to do instead:**
- Staging wrong? Run `jjx_record` with the correct file list — it handles staging
- Made a mistake? Make a new commit that fixes it — additive, not destructive
- Confused by repo state? ASK the user — another officium may be mid-work
- Need to undo something? Explain the situation to the user and let them decide

**Build & Run Discipline:**
Always run these after Rust code changes:
- `tt/vow-b.Build.sh` — Build
- `tt/vvw-r.RunVVX.sh` — Run VVX

**JJX Commands Are Self-Committing:**
`jjx_enroll`, `jjx_close`, `jjx_record`, and other state-mutating jjx commands create git commits internally. **`jjx_close` (wrap) commits ALL uncommitted changes** — code files and gallops state together in one commit. Do NOT follow `jjx_record` or `jjx_close` with another commit command — the tree will already be clean. If a commit command says "Nothing to commit", check `git status --short` and accept the result.

**Diagnose Before Escalating:**
When a command fails, check the simplest explanation first. "Nothing to commit" means the tree is clean — verify with `git status`, don't try creative workarounds. "Invalid params" means wrong field names — check the MCP Command Reference above, don't guess. One diagnostic command beats three speculative retries.

### Wrap Discipline

**NEVER auto-wrap a pace.** Always ask the user explicitly: "Ready to wrap ₢XXXXX?" and wait for confirmation before running `jjx_close`. The user decides when work is complete, not the agent.

When work is complete, report outcomes and ask. Do not wrap.

When wrapping (after user confirms), always include a summary of the work:
Use `jjx_close` with `{coronet: "CORONET", summary: "Added bitmap displays to orient output"}`
The agent always has context about what was accomplished — include it.

**Wrap commits everything.** `jjx_close` stages and commits all dirty files (code edits + gallops state) in one commit. Do NOT notch before or after wrapping — the wrap IS the final commit. If you want separate commits for intermediate code milestones, notch during work; remaining uncommitted changes are captured by wrap.

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
