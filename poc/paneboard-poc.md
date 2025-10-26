# PaneBoard PoC

### Purpose

A **console proof-of-concept** to demonstrate that PaneBoard can intercept and log **modifier + key chords** with top priority across Windows, macOS, and Linux.

* **Left side:** modifier state (lowercase = released, UPPERCASE = pressed).
* **Right side:** ordered list of currently held non-modifier keys.
* **Output:** one new row on every press/release event.

---

### Canonical Modifier Set (Left side)

1. lsh / LSH – Left Shift
2. rsh / RSH – Right Shift
3. lct / LCT – Left Control
4. rct / RCT – Right Control
5. lal / LAL – Left Alt / Option
6. ral / RAL – Right Alt / Option / AltGr
7. lme / LME – Left Meta (Command/Windows/Super)
8. rme / RME – Right Meta
9. cap / CAP – Caps Lock (toggle)

* **Not included:** Fn (hardware, usually hidden), Scroll Lock (legacy), Hyper/Compose (Linux niche), Num Lock (absent on most Mac keyboards).

---

### Sample Console Output

```
lsh rsh lct rct lal ral lme rme cap || Keys: a
lsh rsh lct rct lal ral lme rme cap || Keys: a s
lsh rsh lct rct lal ral lme rme cap || Keys: s
lsh rsh lct rct lal ral lme rme cap || Keys:
```

---

### Platform APIs & Subtleties

#### Windows 🚧 TBD

* **Status:** Not implementing for initial PoC - focusing on macOS first.

#### macOS 🔧 Implementation Decisions

* **API:** IOHIDManager (usage page 0x07) - going straight to this for full L/R modifier support.
* **Permissions:** Request Input Monitoring permission and fail fast if denied. Exit with one-line instruction.
* **Rust crates:** Minimal bindings: `core-foundation`, `objc`/`objc2`, thin IOHID/IOKit FFI.
* **Event handling:** Dual role - IOHID for logging/capture; CGEventTap for selective blocking (e.g. Option-Tab, Control-Shift quadrants).
* **Autorepeat:** Ignored in IOHID path. In CGEventTap path, autorepeats are explicitly filtered.
* **NumLock:** Excluded from PoC (not displayed, not queried).
* **Output format:** Exact sample format with `||` separator and lowercase/UPPERCASE modifier rule.

##### macOS HID notes (why we chose IOHID + normalization)

* **Dual-path reports:** Apple keyboards deliver keys two ways at the HID level:
  1) **ScanCodes array**: element usage is undefined; the value is the usage code when a slot is filled.
  2) **Per-key variable**: element usage *is* the key; the value is 0/1.

* **Problem observed:** Without normalization, ScanCodes appear as phantom `0xFFFFFFFF` keys and spam the log during make/release churn.

* **Normalization rule (ours):**
  - On **ScanCodes**: treat nonzero value as a **press** for that usage; ignore zero (release handled below).
  - On **Per-key variable**: usage is the key; 0/1 is release/press.
  - Accept only usages `0x04..=0xE7`; drop pseudo-keys (e.g., `0x01..0x03`).

* **Outcome:** Clean, ordered chord tracking (`a s d …`) with no phantom entries. This is the minimum needed for reliable chords and L/R modifiers.

#### Linux ⚖️

* **X11:** XInput2 Raw events. Combine with XKB mapping for left/right keys.
* **Wayland:** No global capture by design. Options:

  * Privileged daemon via **libinput** (read `/dev/input/event*`).
  * Compositor-specific plugin/portal.
* **Locks:** X11: `XkbGetIndicatorState`. libinput: track lock events.

---

### Cross-Platform Subtleties

* **Chord order:** maintain insertion-ordered set. On press → append, on release → remove. Ignore repeats.
* **Left/Right fidelity:** Windows ✅, Linux/X11 ✅, macOS ✅ only with IOHID.
* **AltGr:** treat as `RAL` (with possible LCtrl co-press).
* **Fn key:** not exposed; ignore.
* **Priority claim:** RawInput (Windows), IOHID (macOS), libinput (Linux) = as low-level as user space allows.

---

### Complexity Snapshot

* **Windows:** Low.
* **macOS:** Medium (EventTap easy, IOHID proof).
* **Linux:** Medium/High (Xorg straightforward, Wayland requires daemon/privilege).

---

### Relation to PaneBoard (cf. CLAUDE.md)

This PoC is a standalone demo verifying **the critical keyboard capture layer** that PaneBoard depends on. Once proven, it ensures Alt-Tab replacement, tiling, and clipboard hotkeys can all be implemented consistently across platforms.

---

### Source File Organization

#### Current Structure
The PoC has been successfully refactored from a large monolithic file (`pbmsf_focus.rs`, 1714 lines) into focused modules following PaneBoard's naming philosophy. The current structure is organized as follows:

**Naming Pattern Reminder:**
```
pb<platform><feature><uniquifier>_<descriptor>.<ext>
```
- `platform` – g (generic), m (macOS), w (Windows), l (Linux)
- `feature` – s (switcher), c (clipboard), p (pane), b (base/shared)
- `uniquifier` – additional letters ensuring unique acronyms

**Base/Shared macOS Components** (feature code = 'b' for base):
- **`pbmba_ax.rs`** - Core AX FFI, types, and RAII wrappers shared across features
- **`pbmbd_display.rs`** - NSScreen enumeration and visible frame calculations
- **`pbmbe_eventtap.rs`** - Main event tap that dispatches to all features
- **`pbmbk_keymap.rs`** - Key code mappings and virtual key to HID conversions
- **`pbmbo_overlay.rs`** - Base overlay rendering utilities

**Switcher Components** (feature code = 's'):
- **`pbmsa_alttab.rs`** - Alt-Tab session state and overlay UI coordination
- **`pbmsb_browser.rs`** - MRU browser logic for switcher
- **`pbmsm_mru.rs`** - MRU stack management and window tracking
- **`pbmbo_observer.h`** - C-ABI header for NSWorkspace observers
- **`pbmbo_observer.rs`** - App activation/termination observers for switcher
- **`pbmbo_observer.swift`** - Swift NSWorkspace observers and overlay

**Clipboard Components** (feature code = 'c'):
- **`pbmcl_clipboard.rs`** - Clipboard history management and monitoring
- **`pbmco_overlay.rs`** - Clipboard overlay UI and navigation

**Pane Components** (feature code = 'p'):
- **`pbmp_pane.rs`** - Window tiling and geometry

**Generic Components** (platform = 'g'):
- **`pbgc_core.rs`** - Core constants and state structures
- **`pbgk_keylog.rs`** - Optional diagnostic key state logging
- **`pbgr_retry.rs`** - Retry and timing utilities
- **`pbgx_layout.rs`** - (deprecated, will be replaced with new form.xml parser)

This refactoring achieves:
- Clear separation of concerns
- Better testability and maintainability
- Parallel development capability
- Consistent naming that reveals purpose at a glance
- Reduced compilation time for incremental changes

### Developer Notes (PoC Learnings)

#### Key Insight
* **Successful Command+Tab takeover requires hybrid approach**
  - IOHID for authoritative state tracking (L/R modifiers, chord order)
  - CGEventTap for surgical blocking decisions (respects semantic modifiers)
  - Atomic coordination between the two layers (`AtomicU32` state mask)

#### Capture vs Blocking
* **Capture** (IOHIDManager): always sees raw HID events, cannot stop delivery.
* **Blocking** (CGEventTap): can veto key events, but only at CG layers and with Accessibility permission; watches for **Command key flags** (`kCGEventFlagMaskCommand`).
* PaneBoard uses IOHID for fidelity (L/R modifiers, chord order) and CGEventTap for selective veto (e.g. ⌘+Tab).

#### Permissions & Debugging
* **Input Monitoring** → required for IOHID.
* **Accessibility** → required for CGEventTap.
* When run from a terminal (iTerm/Terminal), the *terminal app* appears in System Settings, not the binary.
* **Secure Input** (password fields) disables both IOHID and CGEventTap.
* **Permission debugging**:
  - Test with `sudo` first to isolate permission vs code issues
  - Terminal apps inherit permissions → grant to iTerm/Terminal, not binary
  - Use error messages to guide users to correct System Settings panels

#### Keyboard Remap Nuance
* IOHID reports *physical* modifiers before macOS remapping.
* CGEvent flags report *semantic* modifiers after remapping.
* **For blocking, use CGEvent flags** (respects Option/Command swaps via `CGEventGetFlags()`).
* For chord tracking, IOHID remains the source of truth.
* **Critical constants**:
  - `K_CG_EVENT_FLAG_MASK_COMMAND: u64 = 1 << 20` (Command) — **primary modifier for Alt-Tab takeover**
  - `K_CG_EVENT_FLAG_MASK_SHIFT: u64 = 1 << 17` (Shift)
  - `K_CG_EVENT_FLAG_MASK_CONTROL: u64 = 1 << 18` (Control)
  - `K_CG_EVENT_FLAG_MASK_ALTERNATE: u64 = 1 << 19` (Option) — not used for Alt-Tab in current implementation

#### Phantom Events (0xFFFFFFFF)
* Caused by IOHID ScanCode array elements with undefined usage.
* Fix: normalize ScanCodes vs per-key variable elements.
* Outcome: clean chord state (`a s d`) without phantom entries.

#### Escape Hatch
* Current PoC: holding both ⌘ keys suspends blocking (`BLOCKING: suspended/resumed`).
* Future: add timed long-press (2s) for safer recovery.

#### Logging Conventions
* Normal state: `lsh rsh ... || Keys: ...` (from IOHID).
* Blocked chord: `BLOCKED: cmd+tab (forward)` or `BLOCKED: cmd+shift+tab (reverse)`.
* Blocked keyup: `BLOCKED: cmd+tab (keyup)` or `BLOCKED: cmd+shift+tab (keyup)`.
* Escape state: `BLOCKING: suspended/resumed`.

#### Gotchas Avoided
* **Static mut in callbacks** → replaced with `AtomicBool` for thread safety
* **FFI pointer const-ness** → CF pointers are `*const`, not `*mut`
  - `CFMachPortCreateRunLoopSource(allocator: *const c_void, port: *const c_void, ...)`
* **Tab session tracking** → block both keyDown and matching keyUp
  - Track forward/reverse state: `TAB_BLOCK_ACTIVE` values (0=inactive, 1=forward, 2=reverse)

#### CGEventTap Reliability & Auto-Recovery (macOS)

**Problem discovered:**
macOS can **silently disable a CGEventTap** if the callback function takes longer than ~500ms to process an event. This is a protective measure to prevent system hangs, but it creates a critical failure mode: once disabled, the tap stops receiving events entirely.

**Observable symptoms:**
* Alt-Tab switcher overlay becomes stuck on screen (cannot close)
* Overlay remains visible and on top, but does not respond to keyboard input
* User can still interact with windows underneath the overlay (`ignoresMouseEvents = true`)
* Hotkeys (quadrant tiling, clipboard history) stop working
* No error or warning is logged when the tap is disabled

**Root cause:**
When any of the following occurs during event processing:
* AX operations take too long (e.g., enumerating windows, querying geometry)
* System is under heavy load
* App switching triggers cascading AX queries
* Other security/monitoring tools interfere with event delivery

...macOS decides the tap is unresponsive and disables it automatically. The tap does **not** recover on its own.

**Why this affects the switcher overlay:**
The cleanup logic for the Alt-Tab switcher depends on receiving the **Option key release** event via `CGEventFlagsChanged`. If the tap is disabled before that event arrives, the cleanup code never runs, leaving the overlay stuck visible with `session.active = true`.

**Solution implemented:**
PaneBoard now runs a **periodic health check timer** (every 500ms) on the main runloop that:

1. Calls `CGEventTapIsEnabled(tap)` to verify the tap is still active
2. If disabled:
   - Logs a prominent console warning: `⚠️  WARNING: CGEventTap was DISABLED by macOS`
   - Automatically re-enables the tap via `CGEventTapEnable(tap, true)`
   - Verifies recovery and logs outcome (`✓ SUCCESS` or `✗ FAILED`)
3. Continues monitoring indefinitely

**Implementation notes:**
* Timer is created with `CFRunLoopTimerCreate` and added to the default runloop mode
* Tap pointer is stored in `static EVENT_TAP_PTR: AtomicPtr<c_void>` for timer access
* Health check runs independently of event processing (not in the tap callback)
* First check occurs 500ms after startup; repeats every 500ms thereafter
* Timer setup is logged: `DEBUG: Event tap health monitoring enabled (500ms interval)`

**Logging contract:**
```
⚠️  WARNING: CGEventTap was DISABLED by macOS (likely due to slow callback)
⚠️  RECOVERY: Re-enabling event tap automatically
✓  SUCCESS: Event tap re-enabled
```

or:

```
✗  FAILED: Could not re-enable event tap - hotkeys may not work!
```

**Future improvements considered:**
* Detect stuck switcher state by querying actual Option key state via `CGEventSourceKeyState`
* Add escape hatch (ESC key) to force-close stuck overlays
* Monitor app activation during active Alt-Tab session to detect unexpected focus loss

**Outcome:**
PaneBoard now automatically recovers from CGEventTap disablement, maintaining hotkey functionality and preventing permanent overlay lock-ups. Console warnings alert the developer/user to abnormal system behavior.

#### Single-Instance Enforcement (macOS)

**Problem:**
Running multiple PaneBoard instances simultaneously causes severe conflicts:
* Multiple CGEventTaps compete for the same keyboard events
* MRU window tracking becomes inconsistent (duplicate entries, race conditions)
* Clipboard monitoring duplicates pasteboard change events
* Keyboard shortcuts fire multiple times per press
* System resources are unnecessarily consumed

**Solution implemented:**
PaneBoard now enforces a **single-instance constraint** using file-based advisory locking via the `single-instance` crate (wraps `flock(2)` on macOS).

**Mechanism:**
1. On startup (immediately after AX permission check), PaneBoard attempts to create an exclusive lock
2. Lock file location: `/tmp/paneboard.lock` (system-wide)
3. If lock succeeds: PaneBoard proceeds normally and holds the lock for entire lifetime
4. If lock fails: Another instance is already running → print error and exit immediately
5. Lock is **automatically released** when process terminates (crash-safe, no stale locks)

**Why flock is safe:**
* Locks are tied to **file descriptors**, not files or PIDs
* Kernel automatically releases locks when process exits (including crashes and force-kills)
* No manual cleanup needed
* No stale lock detection required
* Works reliably across command-line launches (`cargo run`)

**User-facing error message:**
```
ERROR: Another instance of PaneBoard is already running.
Only one instance can run at a time.

If you believe this is incorrect, check for a stale lock file at:
  /tmp/paneboard.lock

The lock is automatically released when the process exits.
```

**Implementation notes:**
* Lock guard is intentionally leaked via `std::mem::forget()` to ensure lifetime = process lifetime
* Lock file uses `/tmp` directory (world-writable, requires no setup)
* System-wide location prevents multiple instances across all users
* Lock automatically disappears on reboot (prevents stale locks)
* Location is logged in error message for transparency

**Testing scenarios verified:**
* First instance starts successfully
* Second instance exits with clear error message
* Lock released after clean exit (Ctrl+C)
* Lock released after force-kill (`kill -9`)
* Third instance starts after first is terminated
* Works identically whether launched via `cargo run` or binary directly

#### Outcome
* PaneBoard PoC successfully demonstrates *simultaneous capture + selective blocking*.
* Tested across Mac and PC keyboards (with Option/Command remap).
* Behavior is consistent, predictable, and respects macOS permission model.
* **Command+Tab takeover works identically** regardless of System Settings → Keyboard → Modifier Keys remapping.
* **Chrome window tiling now works reliably** with proper Position → Size sequencing! 🎉

#### NSScreen.visibleFrame Unreliability (macOS Bug)

**Problem discovered:**
`NSScreen.visibleFrame` reports incorrect `origin.y` values on macOS, causing quadrant overlap.

**Observed behavior (tested on dual-display setup):**
* **Primary display (x=0):**
  - `visibleFrame = (0, 0, 2560, 3169)` — claims to start at y=0
  - `frame = (0, 0, 2560, 3200)` — full screen starts at y=0
  - **BUT:** macOS forces windows to y=31 (reserves menu bar space)
  - Result: UL quadrant target `(0, 0, w, h)` → actual `(0, 31, w, h)` ❌

* **Secondary display (x=2560):**
  - `visibleFrame = (2560, 0, 2560, 3200)` — claims to start at y=0
  - `frame = (2560, 0, 2560, 3200)` — identical to visible frame
  - **BUT:** macOS still forces windows to y=31 (reserved space for menu bar when mouse moves to top)
  - Result: UL quadrant target `(2560, 0, w, h)` → actual `(2560, 31, w, h)` ❌

**Root cause:**
macOS **universally reserves ~31 pixels** at the top of every display for the menu bar (primary) or potential menu bar (secondary), but `NSScreen.visibleFrame` does **not** reflect this reservation on either display type.

**Impact on quadrant tiling:**
* UL quadrant: forced down by 31px → starts at y=31 instead of y=0
* LL quadrant: calculated using wrong `midY` (based on visibleFrame height that includes reserved space)
* Result: **31-pixel overlap** between UL and LL quadrants

**Fix strategy:**
1. Query actual menu bar height from system (via `NSApplication.shared.mainMenu?.menuBarHeight` or similar)
2. When `visibleFrame.minY == frame.minY` (no offset detected), apply correction:
   - `corrected_minY = vf.minY + menuBarHeight`
   - `corrected_height = vf.height - menuBarHeight`
3. Recalculate `midY` using corrected values
4. Log corrected geometry for validation

**Expected outcome:**
* All displays: quadrants start at y=31 (or y + menuBarHeight)
* UL/LL boundary aligns exactly at corrected `midY`
* No overlap or dead space across any display configuration

---

### Layout Configuration System

#### Overview

PaneBoard uses a declarative XML configuration system to define window tiling layouts, keyboard bindings, and display-specific behavior. The configuration is stored in a single file:

```
~/.config/paneboard/form.xml
```

**Configuration Deployment Strategy:**

The default configuration is maintained in `poc/form.default.xml` and embedded at build time via Rust's `include_str!()` macro.

At **every application startup** (not just first run), PaneBoard:
1. Checks if `~/.config/paneboard/form.xml` exists
2. If it exists, renames it to `form.xml.NNNNN` (where NNNNN starts at 10000 and increments to find an unused filename)
3. Writes a fresh copy of the embedded default to `~/.config/paneboard/form.xml`
4. Parses and uses the fresh copy

**Rationale:** This ensures that every run uses the latest compiled configuration while preserving any user edits as archived files for manual inspection or recovery. Users must manually clean up archived files if desired.

The configuration is parsed once at startup; changes require a restart to take effect. (A hot-reload mechanism may be added in a future cycle.)

Parse errors or semantic errors (e.g., undefined references) cause PaneBoard to **disable all layout-triggered window tiling** while allowing other features (Alt-Tab, clipboard) to continue working. The error is logged with actionable detail.

#### Configuration Structure

The root element `<Form>` contains eight types of child elements, each serving a distinct purpose:

- **`<Measure>`** - Named pixel constants for dimension constraints
- **`<DisplayQuirk>`** - Platform-specific display geometry corrections (workarounds for hardware/OS quirks)
- **`<Space>`** - Display matching rules based on resolution, orientation, name
- **`<Frame>`** - Reusable geometric patterns (collections of Panes)
- **`<Layout>`** - Compositions of Frames with conditional logic
- **`<LayoutAction>`** - Keyboard shortcuts that trigger Layouts
- **`<DisplayMove>`** - Keyboard shortcuts that move windows between displays
- **`<Application>`** - Per-application behavior overrides

Elements are processed in dependency order at parse time. All references (e.g., `<LayoutAction layout="foo"/>` → `<Layout name="foo"/>`) are validated; missing references cause the entire configuration to fail.

##### Measure

Defines reusable pixel values referenced by name in dimension constraints:

```xml
<Measure name="hdWidth" value="1920"/>
<Measure name="ultrawide" value="3440"/>
```

Measures can be referenced in `<Space>` and `<Shape>` dimension attributes (`minWidth`, `minHeight`, `underWidth`, `underHeight`). References accept either a Measure name or a literal integer.

##### DisplayQuirk

Platform-specific workarounds for displays where the OS-reported visible frame doesn't match the actual usable tiling area. Applied before all Space matching and layout calculations.

```xml
<DisplayQuirk nameContains="FlipGo-A" platform="macos" minBottomInset="31"/>
```

**Attributes:**
- `nameContains`: Substring match against display name (minimum 3 alphanumeric characters)
- `platform`: Target OS (`macos`, `windows`, or `linux`)
- `minBottomInset`: Pixels to reserve at bottom of display (positive integer)

**Merging behavior:**
Multiple quirks can match the same display. The final bottom inset is the **maximum** of all matching `minBottomInset` values, ensuring all constraints are satisfied.

**Common use cases:**
- External monitors with physical obstructions (bezels, built-in control panels)
- OS bugs where visibleFrame doesn't account for reserved UI space
- Platform-specific rendering issues requiring safe margins

**Processing:** Quirks are embedded in DisplayInfo objects during Form parsing:
- **Parse-time:** Filtered by platform and embedded into each DisplayInfo. Design dimensions (design_width/design_height) are adjusted for pane list precomputation and Space matching
- **Runtime:** Each DisplayInfo provides a `live_viewport()` method that fetches current NSScreen geometry and applies the embedded quirks consistently

**Design note:** This is intentionally a "patch" mechanism, not integrated with Space/Measure. Future extensions may add `minTopInset`, `minLeftInset`, `minRightInset`.

##### Space

Defines matching rules for physical displays. Layouts can reference Spaces to activate only on appropriate displays:

```xml
<Space name="LargeDisplays">
  <Match minWidth="1920" minHeight="1080" whenOrientation="landscape"/>
  <Exclude nameContains="Built-in"/>
</Space>
```

**Matching logic:**
- Multiple `<Match>` elements are OR'd (any Match succeeds → display is candidate)
- Within a single `<Match>`, all attributes are AND'd
- Multiple `<Exclude>` elements are OR'd (any Exclude vetoes the match)
- Final result: (any Match passes) AND (no Exclude vetoes) = display matches Space

Dimension constraints: `min*` is inclusive (≥), `under*` is exclusive (<).

##### Frame

Defines a collection of Pane geometries that can be referenced by Layouts. Each Pane specifies position and size as **fractions** (proportions) relative to its parent context:

```xml
<Frame name="sidebar">
  <Pane x="0" y="0" width="3/10" height="1"/>
  <Pane x="3/10" y="0" width="7/10" height="1"/>
</Frame>
```

**Pane coordinates:**
- Format: `"numerator/denominator"` or whole number shorthand (`"1"` = `"1/1"`, `"0"` = `"0/1"`)
- Values are proportions of parent context (0 to 1 in practice, though schema allows >1)
- For top-level Panes: relative to display's `visibleFrame`
- For nested Panes: relative to parent Pane's geometry

**Nesting:** Frames can be composed hierarchically via Shapes (see Layout below). A Frame defines only the immediate subdivision of its parent context; deeper subdivisions are achieved by referencing additional Frames in child Shapes.

##### Layout

Composes Frames into a hierarchical tiling structure using a tree of Shapes:

```xml
<Layout name="sidebar-split" space="LargeDisplays">
  <Needs measure="hdWidth"/>
  <Shape frame="sidebar">
    <Shape frame="leftColumn"/>
    <Shape/>
  </Shape>
</Layout>
```

**Shape tree semantics:**
1. A Shape with `frame="foo"` references a Frame by name
2. Child Shapes map 1:1 to the parent Frame's Panes (in order)
3. Each child Shape subdivides its corresponding parent Pane
4. If a child Shape has no `frame` attribute (empty `<Shape/>`), that Pane is **not subdivided** (it becomes a leaf/target Pane)
5. Extra child Shapes beyond parent Pane count are ignored
6. Missing child Shapes mean remaining Panes are not subdivided (also become leaf Panes)

**Conditional logic:**
- `<Layout space="..."/>` - Only activates on displays matching the named Space
- `<Shape whenOrientation="..." minWidth="..." underHeight="..."/>` - Prunes Shape (and entire subtree) if conditions don't match current display

**Measure dependencies:**
If any Shape references a Measure, that Measure must be declared in a `<Needs measure="..."/>` element. This makes dependencies explicit and allows validation to fail fast. If a required Measure is undefined, the entire Layout is pruned (all-or-nothing).

##### LayoutAction

Maps a keyboard shortcut to a Layout, specifying traversal order and mirroring:

```xml
<LayoutAction key="h" layout="sidebar-split" traverse="xfyf" mirrorX="keep" mirrorY="keep"/>
```

**Attributes:**
- `key` - Unmodified key name (see KeyType enum in schema for valid values)
- `layout` - References a Layout by name
- `traverse` - 4-character traversal token (see Traversal Behavior below)
- `mirrorX` / `mirrorY` - Geometry mirroring (`keep` or `flip`)

**Global modifier chord:** All LayoutActions share the same modifier chord: **Ctrl + Shift + Option** (macOS) / **Ctrl + Shift + Alt** (Windows/Linux). This chord is not configurable in the current cycle.

##### DisplayMove

Maps a keyboard shortcut to move the focused window between displays:

```xml
<DisplayMove key="pageup" target="prev" wrap="true"/>
<DisplayMove key="pagedown" target="next" wrap="true"/>
<DisplayMove key="1" target="0"/>
```

**Attributes:**
- `key` - Unmodified key name
- `target` - Destination: `"next"`, `"prev"`, or display index (`"0"`, `"1"`, etc.)
- `wrap` - (optional, default `true`) Cycle from last → first display at boundaries

Display indices are platform-specific (OS enumeration order). Uses the same global modifier chord as LayoutActions.

**Size preservation across moves:**
When moving a window between displays, PaneBoard attempts to preserve the window's size and position. If the window is too large for the target display or partially off-screen, it is resized to fill the target's `visibleFrame` (100% width/height).

**Consecutive moves:** If a user performs multiple DisplayMove actions within a single held chord (e.g., Ctrl+Shift held, pressing PageUp → PageDown → PageUp), PaneBoard remembers the **original size** from before the first move and reinstates it when returning to a display large enough to accommodate it. This prevents jarring size changes when moving a large window through a small display to another large display.

##### Application

Defines per-application behavior overrides with platform-specific matchers:

```xml
<Application name="Chrome">
  <Mac bundleId="com.google.Chrome"/>
  <Windows exe="chrome.exe"/>
  <Linux process="chrome"/>
  <Clipboard monitor="true" copyMirror="false"/>
</Application>
```

At runtime, PaneBoard checks the active application against matchers for the current platform and applies specified overrides. Multiple matchers of the same type can be specified (e.g., Chrome stable, beta, canary).

#### Runtime Behavior

##### Parse-Time Processing

1. **Parse XML** into intermediate structures (quick-xml events → temporary parse tree)
2. **Validate references** (all `layout="..."`, `frame="..."`, `space="..."`, `measure="..."` attributes must resolve)
3. **Discard XML structures** - parsing artifacts are not retained after this phase

##### Pane List Construction (Per LayoutAction, Per Display)

For each `<LayoutAction>` and each connected display at startup:

1. **Resolve Layout** - Follow `layout` reference to `<Layout>` element
2. **Check Space match** - If Layout has `space` attribute, verify display matches; if not, skip this LayoutAction for this display
3. **Evaluate Shape tree conditionally** - Prune any `<Shape>` whose `whenOrientation`, `minWidth`, `minHeight`, `underWidth`, `underHeight` don't match display properties; remove entire subtrees of pruned Shapes
4. **Flatten to leaf Panes** - Traverse the Shape tree and collect all Panes that are **not subdivided** (both container Panes with no child Shape, and recursively all sub-Panes). This includes Panes at any depth.
5. **Apply mirroring** - Transform each Pane's fractional coordinates using:
   - `mirrorX="flip"`: `x' = 1 - x - width`
   - `mirrorY="flip"`: `y' = 1 - y - height`
6. **Convert to pixels** - Multiply fractional coordinates by display's `visibleFrame` dimensions to get pixel rects
7. **Cull undersized Panes** - Remove any Pane smaller than 100×100 pixels (minimum size threshold; may be configurable in future)
8. **Sort by area, then traversal** - Primary sort: descending by area (width × height, largest first); secondary sort: apply `traverse` rule using Pane **center points** `(x + width/2, y + height/2)`
9. **Cache sorted list** - Store for runtime use, indexed by `(LayoutAction, Display)`

**Traversal rule encoding:** The 4-character `traverse` token specifies sort order:
- Characters 1-2: primary axis and direction (`xf`, `xr`, `yf`, `yr`)
- Characters 3-4: secondary axis and direction
- Example: `"xfyf"` = sort by x ascending, then y ascending (left-to-right, top-to-bottom)
- Example: `"yrxf"` = sort by y descending, then x ascending (bottom-to-top, left-to-right)

**Display configuration changes:** If a display is connected/disconnected after startup, PaneBoard does **not** recompute pane lists in the current cycle. Restart required.

##### Activation and Cycling

**Session start:**
- User presses **Ctrl + Shift + {key}** where `{key}` matches a `<LayoutAction>`.
- PaneBoard looks up the cached pane list for that LayoutAction on the focused window's display.
- If no pane list exists (Layout pruned or doesn't match display), log `LAYOUT: no panes available for key={key} on display={index}` and no-op.

**First press:**
- Apply pane 0 (largest pane by area) to focused window using AX `Position → Size` sequencing.
- Store ephemeral index = 1.

**Subsequent presses (while Ctrl+Shift held):**
- Same key: advance index modulo pane list length, apply next pane.
- Different key: reset index to 0 for new LayoutAction, apply its pane 0.

**Chord release (Ctrl or Shift released):**
- Reset all LayoutAction indices to 0.
- Session ends.

**DisplayMove during Layout session:**
- Execute the window move (see Size Preservation below).
- Reset LayoutAction index to 0 (Layout session interrupted).
- Chord remains held; user can continue with new LayoutAction.

##### Size Preservation for DisplayMove

When `<DisplayMove>` moves a window to another display:

1. **Window fits:** Preserve size and position (translated to target display's coordinate space).
2. **Window too large or partially off-screen:** Resize to target's `visibleFrame` (100% width, 100% height).
3. **Consecutive moves in one chord:** Track original size from before first move; reinstate when moving to a display large enough to accommodate it.

**Logging:**
- `DISPLAYMOVE: SUCCESS target=next | preserved size`
- `DISPLAYMOVE: SUCCESS target=prev | resized to full screen (too large)`
- `DISPLAYMOVE: SUCCESS target=1 | restored original size`

##### Error Handling

**Parse errors:**
- Log error with line/column if available: `LAYOUT: parse_error at line 42: unexpected element`
- Disable all LayoutActions (chords ignored, no window tiling).
- Other PaneBoard features (Alt-Tab, clipboard) continue working.
- Exit message: `Fix ~/.config/paneboard/form.xml and restart PaneBoard`

**Semantic errors (at parse time):**
- Undefined reference: `LAYOUT: ERROR layout="foo" references undefined Layout`
- Missing Measure dependency: `LAYOUT: ERROR Shape references undefined Measure "ultrawide"`
- Behavior same as parse errors: disable all LayoutActions.

**Runtime no-ops (not errors):**
- LayoutAction triggered on display where Layout doesn't match: `LAYOUT: no panes available for key=h on display=1` (silent to user, logged for debugging).
- DisplayMove to nonexistent display index: `DISPLAYMOVE: target=5 out of range (max=2)` (no-op).

#### Logging Contract

**Parse-time:**
```
LAYOUT: parsing ~/.config/paneboard/form.xml
LAYOUT: loaded 4 Measures, 2 Spaces, 6 Frames, 8 Layouts, 12 LayoutActions
LAYOUT: precomputed 18 pane lists across 2 displays
LAYOUT: ERROR layout="foo" references undefined Layout
LAYOUT: parse_error at line 42: unexpected element
```

**Runtime (LayoutAction):**
```
LAYOUT: key=h | pane=0/8 | SUCCESS app="com.google.Chrome" frame=(x,y,w,h)
LAYOUT: key=h | pane=3/8 | FAILED reason=ax_error(op=AXSetSize)
LAYOUT: no panes available for key=j on display=1
```

**Runtime (DisplayMove):**
```
DISPLAYMOVE: SUCCESS target=next | preserved size
DISPLAYMOVE: SUCCESS target=prev | resized to full screen (too large)
DISPLAYMOVE: SUCCESS target=1 | restored original size
DISPLAYMOVE: target=5 out of range (max=2)
```

**Debug output (pane list construction):**
```
DEBUG: [LAYOUT] action=h display=0 | flattened 8 leaf panes
DEBUG: [LAYOUT] action=h display=0 | applied mirrorX=flip
DEBUG: [LAYOUT] action=h display=0 | culled 2 undersized panes (< 100x100px)
DEBUG: [LAYOUT] action=h display=0 | sorted by area desc, traverse=xfyf
DEBUG: [LAYOUT] action=h display=0 | cached 6 panes
```

#### AX Patterns & Implementation Strategy

**What we verified (latest)**

* **Amethyst**: uses macOS Accessibility (AX); users must grant Accessibility permission.
* **Rectangle**: also requires Accessibility permission; troubleshooting docs reference resetting Accessibility consent.
* **Hammerspoon**: provides AX wrappers and a first-class **AX observer** API (`hs.axuielement`, `hs.axuielement.observer`) supporting focus/window notifications; common scripting patterns use retries on AX failures.
* **yabai**: relies on WindowServer/SkyLight private APIs for some capabilities; several features historically require (partial) SIP disable or a scripting addition to Dock.app. (Not PoC-safe.)

**Implication:** For a sandbox-safe PoC, follow the **Hammerspoon-style AX + AXObserver** model; avoid private APIs (yabai).

**Decisions for the Quadrant Feature**

1. **Permissions & Trust**
   * Require and verify **Accessibility** at launch; fail fast with a single actionable line if missing. (AX is table-stakes for Amethyst/Rectangle too.)

2. **Event Model (Hotkey → Work)**
   * **Do not** perform AX work in the hotkey/tap path. Defer actual window queries/moves onto the main runloop. (This mirrors common guidance and Hammerspoon practice.)

3. **Focused-window Resolution**
   * Primary path: System-wide → focused app → focused window (AX attributes).
   * If this call reports *not ready* or *cannot complete*, create a short-lived **AXObserver** for that app and subscribe to `AXFocusedWindowChanged`.
   * Act immediately when the observer callback delivers a usable focused window.
   * If no usable window arrives within ~300 ms, cancel and log `FAILED reason=not_ready_timeout`.

4. **Observers: Scope & Lifetime**
   * Maintain a **per-target-app AXObserver** only during the resolution of a chord.
   * Register it on the main runloop, listen for `AXFocusedWindowChanged`.
   * Remove it immediately after success or timeout. This replaces all timer-based retry logic.

5. **Cache (lightweight)**
   * Keep ephemeral "current focused window ref" only as a **session aid**; do **not** build a full global window model for the PoC cycle. (Amethyst likely maintains internal state, but we won't replicate that yet.)

6. **Retry Policy**
   * **No timer-based retries.** All transient resolution is handled via AXObservers.
   * A single-shot CFRunLoopTimer is retained solely to enforce a ~300 ms timeout.
   * Observers are torn down as soon as a usable window is received or the timeout expires.

7. **Geometry Contract**
   * Compute from `NSScreen.main.visibleFrame`. Window geometries are defined in `form.xml` as fractional coordinates; **Position → Size** sequencing; abort on any AX failure to keep idempotence.

8. **Chord Policy (XML-Driven Architecture)**
   * **Modifier chord**: **Ctrl+Shift+Option (macOS) / Ctrl+Shift+Alt (Windows/Linux)** - hardcoded, not configurable in current cycle.
   * **Key bindings**: All keys are configured in `~/.config/paneboard/form.xml` via `<LayoutAction>` and `<DisplayMove>` elements.
   * **Routing**: Event tap maps keycode → key name (e.g., `KVK_HOME` → `"home"`), then queries Form configuration:
     1. If key has `<LayoutAction>` binding → execute window tiling via Form pane list
     2. Else if key has `<DisplayMove>` binding → execute display move
     3. Else → no-op (key not configured)
   * **Legacy compatibility**: Old hardcoded quad mappings (`chord_to_quad()` in `pbmbk_keymap.rs`) are deprecated but retained for reference.
   * **Consume on key-down**: all configured chords are consumed; no repeats.

9. **Non-Goals for this cycle**
   * No private APIs (CGS/SkyLight), no SIP tweaks, no Spaces moves.
   * Modifier chord customization deferred to future cycle.

**Diagnostics & UX**
* **Launch-time:** if AX untrusted → one-line instruction referencing System Settings → Privacy & Security → Accessibility. (Aligns with Amethyst/Rectangle user guidance.)
* **Per-chord logs:**
  * Success (LayoutAction): `TILE: <LEGACY_LABEL> | SUCCESS | key=<key> pane=<N> app="<bundle>"`
  * Success (DisplayMove): `DISPLAYMOVE: SUCCESS key=<key> | app="<bundle>" from_display=<N> to_display=<M>`
  * Failures: `TILE: <LEGACY_LABEL> | FAILED reason=ax_error(...)` or `LAYOUT: no panes available for key=<key> on display=<N>`
  * Consume: `BLOCKED: ctrl+shift+option+<key>` (macOS) / `BLOCKED: ctrl+shift+alt+<key>` (Windows/Linux)
  * Diagnostics: Chromium app detection, pane list precomputation logged to debug output
* **Observer lifecycle:** `OBS: start(pid=…), notif=<FocusedWindowChanged> | timeout=<ms> | end(status=success|timeout)`
* **Note:** Legacy quad labels (UL/UR/LL/LR) still appear in logs for backward compatibility but are deprecated. Future versions will use layout names from XML configuration.

**Risk Register (macOS AX)**
* **Focus across apps:** `kAXFocusedWindowChanged` often fires per-app; when the user switches apps, combine with `NSWorkspace didActivateApplication` to retarget the short-lived observer. (Hammerspoon exposes both app-level and element-level watchers.)
* **Fragility off main loop:** Observers must be registered on a serviced runloop; ensure main-loop registration (Hammerspoon's model implies this).
* **Permissions churn:** Users may need to reset Accessibility consent (Rectangle's docs show this as common). Provide a single remediation line.

**Test Plan (acceptance for this cycle)**
1. **Permissions gating:** start without AX trust → tool exits with the single-line instruction (matches Amethyst/Rectangle patterns).
2. **Happy path:** Ctrl+Shift+{Insert,Delete,Home,End} tiles current focused window into correct quadrant; idempotent on repeats.
3. **Race path:** Trigger chord immediately after app switch; verify observer fires and completes within 300 ms; verify timeout logs on apps that delay focus.
4. **Constraints:** Fullscreen or non-resizable windows → clean failure reasons; no partial moves.
5. **Recovery:** Removing and re-granting Accessibility → app handles gracefully without restart if possible; otherwise prints the remediation line.

**Deferments (future cycles)**
* Full **window model** (Amethyst-style) for proactive tiling.
* Multi-display routing & Spaces manipulation (yabai-class features require deeper integrations and, at times, SIP tradeoffs).

---

### Appendix: macOS FFI Safety & Ownership (Create/Copy Rule)

**Intent:** Keep deps minimal while guaranteeing correctness. We explicitly accept CoreFoundation/AX manual ownership and constrain `unsafe` to tiny shims.

**Guardrails:**

1. **Create/Copy Ledger.** Any API named `Create*` or `Copy*` returns a retained object (refcount +1). We **must** release it exactly once. Examples we use:
   * `AXUIElementCreateSystemWide` (Create)
   * `AXUIElementCopyAttributeValue` (Copy)
   * `AXValueCreate` (Create)
   * `CGEventTapCreate` (Create-like; managed via CFRunLoop source)

2. **Constant CFStrings.** Attribute names (`"AXFocusedApplication"`, `"AXFocusedWindow"`, `"AXPosition"`, `"AXSize"`, `"AXRole"`), and runloop modes are referenced via **true static CFStrings** (no temporaries).

3. **Event Tap ABI Consistency.** A single canonical declaration of `CGEventTapCreate` and callback ABI is used project-wide.

4. **RunLoop Modes.** Use **system constants** (`kCFRunLoopDefaultMode` or `kCFRunLoopCommonModes`) instead of string literals.

5. **Unsafe Boundaries.** Unsafe code is localized to small helpers; everything else remains safe Rust. Each helper documents ownership: *who retains, who releases*.

6. **Two-Step Geometry Policy.** We choose **Position → Size** (AXPosition then AXSize), matching Chrome-safe practice. Logs include before/after rects for diagnostics. Abort on any failure to preserve idempotence.

7. **Permission Semantics.** Check `AXIsProcessTrustedWithOptions` at startup; later failures that *look like* permission issues log `ax_permission_missing_or_revoked` (diagnostic only; no retry logic in PoC).

**Rationale:** Thin FFI keeps binaries small and behavior predictable; RAII wrappers around the few CF/AX types we use eliminate leaks and dangling refs without adding heavy dependencies.

---

### Alt-Tab MRU PoC (Baby Step)

**Intent:**
PaneBoard maintains its own **Most Recently Used (MRU) stack** of windows, updated whenever focus changes.
This stack is independent of Mission Control or Spaces.

#### MRU Validation and Pruning (New for Repair)

**Problem:**
Some applications destroy windows without emitting reliable `AXWindow` teardown events.
As a result, defunct window entries can persist in the MRU stack and appear in the switcher overlay even though the windows are no longer visible.

**Repair Strategy:**
At the **start of each Alt-Tab session** (the first `Tab` press while Command is held),
PaneBoard performs a **live validation pass** over all known MRU entries:

1. For each tracked `(pid, window_id)` pair:
   * Attempt to query its `AXRole` via `AXUIElementCopyAttributeValue`.
   * If the call fails or the role is not `"AXWindow"`, remove the entry.
   * **Minimized windows are not restored** during this validation pass; they remain in the MRU stack if still valid AXWindow objects.
2. After validation, log one summary line:
   ```
   MRU: pruned <N> stale entries (pre-session validation)
   ```

This pruning step occurs **once per session start** and keeps the MRU overlay synchronized with the system's actual window state without adding background polling or runtime overhead. Minimized window restoration happens only at **focus commit time** (see Focus Commit Policy).

**Mechanism:**
* Use a Swift shim for `NSWorkspaceDidActivateApplication` to detect app activation/termination.
* On app activation, attach a per-app AXObserver to listen for `AXFocusedWindowChanged`.
* On app termination, remove its observer.
* Each focus change (app or window) updates the MRU stack (deduplicated, most recent at the top).
* On startup, PaneBoard prepopulates MRU by enumerating all `.regular` apps. For each app, it attempts to list all top-level windows via `AXUIElementCopyAttributeValues(kAXWindowsAttribute, …)`. Some apps delay or restrict window reporting (iTerm2, Chrome, Electron). Such windows may appear as placeholders or not at all until first focus. MRU stabilizes naturally as focus events arrive. Entries seeded at startup are marked `GUESS`. When a window activates, it flips to `KNOWN`.

**Display Trigger:**
* When **Command is held** and **Tab is pressed**, show a popup list of all known windows in MRU order.
* Each entry shows app bundle name (or PID), window title (if accessible), and status (`KNOWN` or `GUESS`).

**Fullscreen / Spaces Policy:**
* PaneBoard does **not** integrate with Mission Control or Spaces.
* If a window enters **macOS native fullscreen**:
  - AX events may not expose it reliably.
  - PaneBoard logs a placeholder entry: `app="<bundle>", window="FULLSCREEN (unsupported)"`.
  - No geometry is stored; MRU stack still advances.
* PaneBoard's **preferred maximization** is "fake fullscreen": resize to the visible frame of the display (menu bar + Dock accounted for).

**Filtering:**
* **Include** only windows with `AXRole = kAXWindowRole`.
* **Exclude** dialogs, sheets, popovers, utility/status windows, and hidden windows.

**Caveats:**
* Requires Accessibility permission.
* Fullscreen windows may not expose geometry.
* Some windows report empty titles until first focus.

**Outcome:**
* The Command-Tab popup shows the **current MRU ordering** of all accessible windows.
* Entries clearly indicate whether a window is fully known (AX-tracked) or only partially observed.

---

#### Developer Notes (MRU Implementation)

**Window Identity Strategy**
* Each window is tracked by `(PID, WindowID)`. AX role filtering ensures only real windows (`AXWindow`) are included.

**AX Role Filtering is Critical**
* Without filtering by `AXRole = "AXWindow"`:
  - Dialogs, sheets, popovers pollute the MRU stack.
  - Hidden/minimized windows create stale entries.
  - Utility windows (palettes, inspectors) clutter the list.
* Filter early: check role immediately after retrieving focused window.
* Reject any role other than `"AXWindow"` to keep the stack clean.

**Fullscreen Detection Nuances**
* `AXFullScreen` attribute exists but may not always be accessible.
* Native fullscreen windows often lack geometry (no `AXPosition`/`AXSize`).
* Detection strategy: check `AXFullScreen` boolean; if true but no rect, log placeholder.
* PaneBoard's **preferred maximization**: "fake fullscreen" (resize to visible frame) is more AX-friendly.

**Event-Driven MRU Updates**
* macOS PoC combines two layers:
  - **NSWorkspace notifications** (via Swift shim) → app activation/termination.
  - **Per-app AXObservers** → window focus changes inside each app.
* This dual mechanism ensures MRU reflects true window order, not just app order.
* Observers must be created/destroyed dynamically as apps start and stop.
* AX role filtering and fullscreen detection remain as described.
* Seed on startup with current focused window.
* Stack naturally stabilizes as user interacts; no polling needed.

**Outcome**
* MRU PoC successfully tracks window focus history with true window-level tracking (not just app-level).
* Command+Tab displays ASCII snapshot (bundle ID, title, KNOWN/FULLSCREEN status).
* Baby step complete: no cycling or activation yet (future work).

---

### Alt-Tab Popup with Focus Switching

**Scope**
This phase adds a **barebones popup overlay** to visualize Alt-Tab navigation and commits focus changes on Command release.

**Behavior**

* **Session start:**

  * Holding `Command` begins a session.
  * First `Tab` press while `Command` is held shows the popup on **every display**.
  * Before displaying the popup, the MRU stack undergoes a pre-session validation pass to prune stale windows as described above.
  * On the first Tab press while Command is held, the highlight advances immediately to the next MRU entry (index 1). The overlay still shows the full MRU stack, but the current window is skipped.
* **Forward paging:**

  * Each subsequent Tab press moves the highlight forward through the MRU stack, starting from index 1.
* **Backward paging:**

  * Each `Shift+Tab` press (while Command held) moves the highlight **backward** through the MRU stack.
* **Auto-repeat suppression:**

  * Tab and Shift+Tab are handled **once per physical key press**. Key auto-repeat events generated by the system are discarded during a Command-Tab session.
* **Session end:**

  * Releasing `Command` triggers immediate cleanup (see below).
* **Mouse click cancellation:**

  * **Any mouse click** (left, right, middle, or other button) during an active Alt-Tab session **immediately cancels the session**.
  * Cancellation means: hide all overlays, reset session state, clear highlight index.
  * The mouse click may be consumed or passed through (implementation chooses simplest path).
  * **No focus switch occurs** when a session is cancelled by mouse click.
  * This prevents conflicting activation when the user clicks a window while the overlay is visible.

**Popup Design**

* **Style:** dark translucent rectangle, showing **larger text** for readability and including an **application icon** for each entry.
* **Content:** each MRU entry shows the app's bundle icon (32×32 pt) + bundle name + window title (if accessible).
* **Text size:** scaled up for visibility (20pt monospaced).
* **Icon styling:** native macOS rounded corners, 8–12 pt horizontal padding between icon and text. Missing icons render as transparent 32×32 box for consistent alignment.
* **Highlight:** full-width background bar behind the selected entry.
* **Placement:** occupy the **lower half of the *visible frame* of every display** (respects menu bar and Dock placement).
  * **Implementation note (macOS):** When initializing `NSWindow` with the `screen:` parameter, provide the `contentRect` in that screen's **local coordinate space** (not global). Compute it by subtracting `screen.frame.origin` from `screen.visibleFrame.origin`.

#### 🔧 Text Column Order Revision (Overlay Display)

**Purpose**
Simplify and clarify the text shown in each Alt-Tab entry by presenting human-relevant information first and technical identifiers last.

**Change Summary**

| Column | New Content                                            | Example                                           |
| ------ | ------------------------------------------------------ | ------------------------------------------------- |
| ①      | **Window title** (entire `AXTitle`, unquoted)          | `ChatGPT – pnb_PaneBoard – Google Chrome – Brad`  |
| ②      | **App identifier reversed** (e.g. `chrome.google.com`) | Derived from `bundleId` by reversing dot segments |
| ③      | **Activation state**                                   | `[KNOWN]`, `[GUESS]`, `[FULLSCREEN]`              |

**Resulting layout example**

```
1. ChatGPT – pnb_PaneBoard – Google Chrome – Brad | chrome.google.com [KNOWN]
2. ✳ Git Commit | iterm2.googlecode.com [KNOWN]
3. src | finder.apple.com [GUESS]
```

**Implementation Notes (developer)**

1. In `drawAltTabEntries()` inside `pbmbo_observer.swift`, replace text construction with:

   ```swift
   let reversedBundle = entry.bundleId
       .split(separator: ".")
       .reversed()
       .joined(separator: ".")
   let text = "\(index + 1). \(entry.title) | \(reversedBundle) [\(entry.activationState)]"
   ```
2. Remove the quotation marks previously surrounding the title.
3. Keep existing truncation (`.byTruncatingTail`) and highlight rendering unchanged.
4. Console debug printouts remain in their original full format for traceability.

**Rationale**
Placing the full title first improves recognition speed, while reversing the bundle identifier reads more naturally and groups related apps visually. The activation tag stays visible for internal validation but can be hidden in future user-facing builds.

---

**Focus Commit Policy (macOS)**

On **Command release**, PaneBoard commits the currently highlighted entry:

* **Cross-app switch** (target PID ≠ frontmost PID):
  * Activate the app via `NSRunningApplication.activate(withOptions: .activateIgnoringOtherApps)`.
  * If the target has a specific window_id ≠ 0, also focus that window using AX (see below).

* **Intra-app switch** (target PID = frontmost PID but different window):
  * Skip app activation (already frontmost).
  * Enumerate app windows via `AXUIElementCopyAttributeValue(app, kAXWindowsAttribute)`.
  * Find the target window by matching window_id.
  * Call `AXUIElementSetAttributeValue(window, kAXMainAttribute, kCFBooleanTrue)` to mark as main.
  * Call `AXUIElementPerformAction(window, kAXRaiseAction)` to bring window forward.

* **Minimized windows:**
  * If the target window is minimized (`AXMinimized = true`), PaneBoard automatically restores it (`AXMinimized = false`) before performing focus and raise actions.
  * This ensures that selecting a minimized window from the switcher visibly brings it forward as the active window.
  * The restoration occurs only at **focus commit time**, not during MRU validation, so background pruning remains lightweight.
  * Log line:
    ```
    ALT_TAB: restored minimized window before focus
    ```

* **Window already focused**:
  * No action needed if the focused window already matches the target window_id.

This ensures per-window switching works correctly (e.g., cycling between multiple Chrome windows).

**Cleanup & State Management**

At **Command release**, always:

* Commit focus change (if a target was highlighted).
* Hide popup overlays on all displays.
* Reset current highlight index to `None`.
* Ensure no stale session state survives into the next run.

On **new Command session**, the first Tab advances immediately to index 1 (skipping the current window).

Treat **early termination** cases (e.g. Command released before Tab, or Command released while Shift still down) identically: immediately hide popup and clear state.

This guarantees each session is independent, no carryover occurs, and debugging shows clear lifecycle boundaries.

**Logging Contract**

* Session lifecycle:
  * `ALT_TAB: session start`
  * `ALT_TAB: forward step -> index=N app=<bundle> win="<title>"`
  * `ALT_TAB: backward step -> index=N app=<bundle> win="<title>"`
  * `ALT_TAB: cleanup | overlays hidden, state reset`
  * `ALT_TAB: cancelled | reason=mouse_click` (when mouse click cancels session)

* Focus commit (on Command release):
  * `ALT_TAB: switch | SUCCESS app="<bundle>" win="<title>"`
  * `ALT_TAB: switch | FAILED reason=<reason>`
  * `ALT_TAB: switch | WARNING failed to focus window_id=<id>`

* Debug output:
  * `DEBUG: [ALT_TAB] Switch type: cross-app|intra-app (target_pid=<pid>, target_window_id=<id>)`
  * `DEBUG: [ALT_TAB] Cross-app activation succeeded for pid=<pid>`
  * `DEBUG: [ALT_TAB] Focusing specific window_id=<id>`
  * `DEBUG: [ALT_TAB] Window focus succeeded`
  * `DEBUG: [ALT_TAB] Target window already focused, no action needed`

**Deferrals**

* No advanced styling polish or persistence across sessions. Basic icons and larger text are now included.

---

### Clipboard Buddy Simplified (Text Only)

**Intent**
PaneBoard maintains a lightweight in-memory history of **text** clipboard entries, while providing seamless Windows-style shortcut parity on macOS.
Native macOS shortcuts (`⌘C`, `⌘X`, `⌘V`, `⌘⇧V`) remain untouched, but **Control** equivalents mirror them for muscle-memory compatibility.

---

**Chord Policy (Cross-Platform)**

| Chord                     | macOS behavior                                                                   | Windows/Linux behavior |
| ------------------------- | -------------------------------------------------------------------------------- | ---------------------- |
| **Ctrl + C**              | Passes through normally **and also issues a synthetic ⌘ + C** to the focused app | Normal copy            |
| **Ctrl + X**              | Passes through normally **and also issues ⌘ + X**                                | Normal cut             |
| **Ctrl + V**              | Passes through normally **and also issues ⌘ + V**                                | Normal paste           |
| **Ctrl + ⇧ V**            | Shows **Clipboard History Picker** overlay                                       | Same                   |
| **Cmd + C / X / V / ⇧ V** | Always native — never intercepted                                                | N/A                    |

*Notes:*

* The Control chords are **not blocked**; PaneBoard merely *duplicates* them as the corresponding Command chords.
* This lets Windows-style shortcuts work transparently on macOS while preserving system behavior.
* `Ctrl + ⇧ V` remains a special case: it is consumed by PaneBoard and shows the session clipboard history overlay.

---

**Behavior**

1. **Clipboard Monitoring**

   * PaneBoard watches the system pasteboard for text changes.
   * Only plain text is stored; images, files, and rich data are ignored.
   * Consecutive identical captures within 250 ms are deduplicated.
   * History is kept **in memory only** (cleared on exit).

2. **Clipboard History Picker (`Ctrl + ⇧ V`)**

   * Displays an overlay listing recent text clippings (most recent first).
   * User can navigate with arrow keys or Tab/Shift + Tab and confirm with Enter.
   * Selecting an entry replaces the system clipboard text and pastes it.

3. **Native Copy Path**

   * When a `Ctrl + C` or `⌘ + C` triggers a copy, the normal application behavior occurs.
   * PaneBoard observes the new clipboard content asynchronously.

---

**Logging Contract**

```
CLIP: captured text | length=<N>
CLIP: overlay shown | entries=<N>
CLIP: pasted historic | index=<i> | length=<N>
CLIP: mirror issued cmd+c  // (debug only, on Ctrl→Cmd duplication)
```

---

**Scope & Limitations**

* Text-only clipboard history
* Session-scoped (no persistence)
* Respects secure input and exclusion lists (e.g., password managers)
* No interference with native macOS shortcuts
* Minimal latency: mirrored Command event posted without blocking Control chord

---

## Appendix: Migration from Legacy Format

**Note:** This appendix will be removed once the new Layout Configuration System is fully implemented in code.

The previous `layouts.xml` format using `<Sequence>` and `<Combo>` elements is **deprecated**. No backward compatibility is provided. Users must migrate to the new `form.xml` schema.

The code in `pbgx_layout.rs` will be removed and replaced with a parser for the new schema that conforms to the specification in the "Layout Configuration System" section above.

### Legacy Format (deprecated)
```xml
<LayoutManager>
  <Sequence key="Insert" id="7">
    <Combo x="0.0" y="0.0" width="50.0" height="50.0"/>
  </Sequence>
</LayoutManager>
```

### New Format (current)
```xml
<Form>
  <Frame name="quadrant-ul">
    <Pane x="0" y="0" width="1/2" height="1/2"/>
  </Frame>
  <Layout name="upper-left">
    <Shape frame="quadrant-ul"/>
  </Layout>
  <LayoutAction key="insert" layout="upper-left" traverse="xfyf" mirrorX="keep" mirrorY="keep"/>
</Form>
```
