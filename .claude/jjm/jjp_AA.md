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
