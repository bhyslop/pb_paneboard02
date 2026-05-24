# Heat Trophy: pb-quick-plus-alt-tab-clue

**Firemark:** ₣AA
**Created:** 260119
**Retired:** 260524
**Status:** retired

## Paddock

# Paddock: pb-quick-plus-alt-tab-clue

## Context

Critical UX improvements to PaneBoard's Alt-Tab switcher. The primary problem: when cycling through windows during a Command+Tab chord, the user can't tell which window is being selected — especially with multiple iTerm instances or similar-looking app windows. This caused a real mistake and needs fixing.

## Primary Feature: Orange Border During Alt-Tab

During a Command+Tab session, as each Tab/Shift+Tab press highlights a different MRU entry, draw an orange border around the *actual window on screen* that corresponds to the highlighted entry. The border should:
- Appear immediately when the highlight changes
- Move to the next window on each Tab/Shift+Tab press
- Disappear when Command is released (session ends)
- Follow the pattern of the green startup characterization border (borderless NSWindow overlay)

This gives spatial confirmation: "that's the window I'm about to switch to."

## Design Decisions (₢AAAAB)

1. **Border thickness**: 6.0 pt (12 physical px on Retina). Thicker than the 4pt green characterization border for at-a-glance visibility during fast Tab cycling. Uses same borderless NSWindow overlay pattern at `.statusBar + 1` level.

2. **Cross-repo strategy**: Resolved — all paces operate in this repo directly.

3. **AX geometry during Alt-Tab**: No shadow structure exists — MruWindowEntry stores only pid/window_id/bundle_id/title/activation_state, no position. Each highlight change requires a live AX query via `AxElement::get_current_rect()`. This is fast (single call per Tab press). Edge cases: minimized/off-Space windows may fail AX query — skip border (no border is better than wrong border).

4. **Slush item scoping**: Completed in ₢AAAAF — 7 items moved to jji_itch.md, 1 resolved as already covered.

## Triage Record (₢AAAAF)

- "Put the box around them during alt-tab" — already covered by ₢AAAAC + ₢AAAAD, resolved
- 7 remaining slush items moved to jji_itch.md (2 flagged as heat candidates: signing + binary distribution)

## References

- PaneBoard POC spec: `../pb_paneboard02/poc/paneboard-poc.md`
- Green border pattern: POC spec "Display Characterization (Startup Diagnostic)" section (~line 392)
- Overlay infrastructure: `pbmbo_overlay.rs` (base overlay rendering utilities)
- Alt-Tab session state: `pbmsa_alttab.rs`
- Swift overlay: `pbmbo_observer.swift`
- MRU tracking: `pbmsm_mru.rs`
- Source repo: `../pb_paneboard02/poc/src/`

## Paces

### list-recent-files (₢AAAAA) [abandoned]

**[260207-1208] abandoned**

Pace abandoned by user request

**[260119-0938] rough**

Make a list of files changed in the last 6 git commits

### triage-slush-reminders (₢AAAAF) [complete]

**[260207-1225] complete**

Triaged 8 slush items: confirmed alt-tab box already covered by AAAAC/AAAAD; moved 7 items to jji_itch.md (2 flagged as heat candidates for signing/distribution). Updated paddock with triage record.

**[260207-1215] rough**

Triage the raw slush reminders below. For each item, decide: slate as a pace on this heat, defer to jji_itch.md, or nominate as a separate heat. Update the paddock accordingly.

Raw slush (verbatim from user)

- Investigate whether mirroring screens confuses PB on macos
- In fact, as the windows are selected during alt tab chord, put the box around them, better than prev idea below
  - put some sort of visual highlight around which window was selected, can't see on iterm plus what window is focused
- Build out system monitor visible when I hold the switching chord a while: IO, CPU, GPU?
- Implement app specific control CVX emulation
- Word Highlight on tab switcher
- dechatter because of swap lag sometimes at work
- do apple Developer ID signing and distribute binary
- Convert to binary distribution only

Notes

The "put the box around them" item is already covered by the main paces on this heat (₢AAAAC, ₢AAAAD). Confirm that during triage and mark it resolved. The remaining items need sorting into actionable locations.

### investigate-design-questions (₢AAAAB) [complete]

**[260207-1228] complete**

Investigated all 4 design questions. Border=6pt, cross-repo resolved, AX query needed per highlight (no shadow cache), slush triaged in AAAAF.

**[260207-1211] rough**

Investigate and decisively answer the open design questions before implementation begins. Read the PaneBoard POC source code and spec, then write answers directly into the paddock file.

Questions to resolve

1. Border thickness: Should the orange highlight border be 4px (matching green startup border) or thicker for at-a-glance visibility during fast Tab cycling? Examine the green border code in pbmbo_overlay.rs or the Swift overlay, measure what 4px looks like at retina scale, and recommend a value. Decide and document.
2. Cross-repo strategy: This heat lives in rbm_alpha but PaneBoard source lives in ../pb_paneboard02/poc/src/. Determine: should paces directly edit PB source files (Claude has permissions per CLAUDE.md for Tools/), or should paces produce design specs that get implemented in the PB repo separately? Examine whether the JJ commit workflow (notch) can handle files outside the current repo. Decide and document.
3. AX geometry during Alt-Tab: During a Command+Tab session, can we reliably query AXPosition/AXSize for the highlighted window? What happens for minimized windows, windows on other Spaces, or fullscreen windows? Review existing AX query patterns in pbmba_ax.rs and the MRU validation logic. Document the edge cases and proposed handling (skip border? show on last known position?).
4. Slush item scoping: Review the slush items in the paddock. Which belong on this heat as paces vs. deferred to itch file or separate heats? Recommend and document.

Deliverable

Updated paddock file (.claude/jjm/jjp_AA.md) with a "Design Decisions" section containing firm answers for each question above.

Files to examine

- poc/src/pbmbo_overlay.rs
- poc/src/pbmba_ax.rs
- poc/src/pbmsa_alttab.rs
- poc/src/pbmsm_mru.rs
- poc/src/pbmbo_observer.swift
- poc/paneboard-poc.md

### pb-window-highlight-overlay (₢AAAAC) [complete]

**[260207-1242] complete**

Added highlight border overlay primitive in Swift (HighlightBorderWindow, 6pt parameterized border, show/reposition/hide C-ABI) + Rust FFI declarations. Fixed content view frame bug in reposition path. Build clean.

**[260207-1211] rough**

Create a reusable "highlight border" overlay that draws a colored border around an arbitrary screen rect.

Goal

A function/module that takes a screen rect (x, y, width, height) and a color, and displays a borderless NSWindow overlay with an N-px colored border around that rect. Adapted from the green startup characterization border pattern.

Requirements

- Borderless, transparent NSWindow with only a colored stroke border
- Must be topmost (above all other windows) so it's visible during Alt-Tab
- Must support show/hide/reposition without recreating the window
- Orange color for Alt-Tab use case (but parameterized)
- Border thickness determined by ₢AAAAB investigation

Pattern to follow

The green startup characterization border (Display Characterization section of POC spec, ~line 392). That code creates a borderless transparent window with a 4px green border positioned at viewport bounds. This is the same pattern, just parameterized for arbitrary rects and colors.

Key files

- pbmbo_overlay.rs (existing base overlay utilities)
- pbmbo_observer.swift (Swift overlay code)

Depends on

₢AAAAB (design decisions determine border thickness and cross-repo strategy)

### pb-wire-highlight-to-alttab (₢AAAAD) [complete]

**[260207-1249] complete**

Wired highlight border into Alt-Tab: get_window_rect() helper, border show/reposition on highlight change, hide on cleanup/cancel. Edge cases handled (GUESS entries, AX failures). Build clean.

**[260207-1212] rough**

Wire the orange highlight border overlay into the Alt-Tab session lifecycle.

Goal

During a Command+Tab session, each time the highlight changes (Tab or Shift+Tab press), query the highlighted window's screen geometry and show the orange border overlay around it. On session end, dismiss the overlay.

Behavior

1. On each highlight change in Alt-Tab session:
  - Get the highlighted MRU entry's (pid, window_id)
  - Query AXPosition and AXSize for that window
  - Show/reposition the orange border overlay to surround that window's rect
2. On Command release (session end): hide the overlay
3. Edge cases (per ₢AAAAB decisions): handle minimized windows, off-screen windows, failed AX queries

Key files

- pbmsa_alttab.rs (Alt-Tab session state, highlight change logic)
- pbmba_ax.rs (AX queries for position/size)
- pbmsm_mru.rs (MRU entry data with pid/window_id)
- New overlay primitive from ₢AAAAC

Depends on

₢AAAAC (highlight overlay primitive must exist)

### pb-highlight-coordinate-fix (₢AAAAE) [complete]

**[260207-1316] complete**

Fixed multi-monitor coordinate bug: removed erroneous screen-local conversion in NSWindow positioning (3 functions). Changed highlight border from orange stroke to yellow with 15% translucent fill. Updated poc spec with correct NSWindow coordinate guidance and coordinate conversion docs.

**[260207-1304] rough**

Debug and fix coordinate system mismatch in highlight border positioning. The border was sized correctly but placed wrong because get_current_rect() returns AX/CG coordinates (top-left origin, Y down) while NSWindow uses Cocoa coordinates (bottom-left origin, Y up). Fix: convert via cocoa_y = primary_screen_height - ax_y - height, reusing get_primary_display_height() from pbmbd_display.rs. Applied to both show_alt_tab_overlay and update_alt_tab_highlight call sites in pbmsa_alttab.rs. Build clean, needs runtime verification.

**[260207-1256] rough**

Reopening: orange border appears sized correctly but positioned incorrectly. Debug needed.

**[260207-1254] complete**

Audited all 5 edge cases. Cases 1+2 already covered by cleanup funnel (hide_alt_tab_overlay_and_cleanup + cancel_alt_tab_session both hide border). Cases 3-5 flow through same funnel. No additional code needed — architecture is sound.

**[260207-1215] rough**

Ensure the orange highlight border is properly dismissed on all session termination paths, not just Command release.

Cases to handle

1. Mouse click cancellation (existing path in Alt-Tab: "Any mouse click during active session immediately cancels")
2. CGEventTap auto-disable recovery (tap health check re-enables tap, but overlay may be stranded)
3. Escape hatch (both Command keys held = blocking suspended)
4. App termination during active session
5. Display disconnect during active session (overlay window on vanished display)

Goal

Audit every session termination path and ensure the orange overlay is hidden. Add defensive cleanup if overlay state is stale (e.g., timer-based check similar to tap health monitor).

Key files

- pbmsa_alttab.rs (session lifecycle, cleanup paths)
- pbmbe_eventtap.rs (tap health monitoring, mouse click handling)
- pbmbo_observer.swift (overlay show/hide)

Depends on

₢AAAAD (overlay must be wired into Alt-Tab before we can harden cleanup)

## Steeplechase

### 2026-01-18 15:28 - Heat - S

investigate-mirrored-screens

### 2026-01-18 15:26 - Heat - N

birthing-job-jockey

