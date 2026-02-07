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

## Slush Items (future paces or separate heats)

- Investigate whether mirroring/duplicating screens confuses PB on macOS
- Build system monitor overlay visible when holding the switching chord a while: IO, CPU, GPU
- Implement app-specific Control+CVX emulation
- Word highlight on tab switcher entries
- Dechatter: debounce swap lag sometimes seen at work
- Apple Developer ID signing and binary distribution
- Convert to binary-only distribution

## References

- PaneBoard POC spec: `../pb_paneboard02/poc/paneboard-poc.md`
- Green border pattern: POC spec "Display Characterization (Startup Diagnostic)" section (~line 392)
- Overlay infrastructure: `pbmbo_overlay.rs` (base overlay rendering utilities)
- Alt-Tab session state: `pbmsa_alttab.rs`
- Swift overlay: `pbmbo_observer.swift`
- MRU tracking: `pbmsm_mru.rs`
- Source repo: `../pb_paneboard02/poc/src/`
