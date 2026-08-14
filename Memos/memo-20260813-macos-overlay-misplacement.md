# Memo: macOS overlay misplacement after display wake — literature sweep

Date: 2026-08-13
Companion to: commit `6e2f6e6` (empty commit recording the investigation state)

This memo records what a web sweep turned up *after* the investigation had
narrowed the fault, and what each finding is worth. The empirical record lives in
`6e2f6e6`; this is only the outside reading.

## The fault, in one paragraph

After a lock/wake cycle, every window PaneBoard creates is committed by the
window server at the global top-left origin, size honoured exactly and position
discarded. It is process-wide — the highlight border box and both alt-tab list
panels all collapse to the identical spot — and only restarting the process
clears it. Our computed geometry is provably correct throughout, and AppKit's
`NSWindow.frame` reports the requested rect while `kCGWindowBounds` disagrees.

## Findings, ranked by what they're worth

### 1. Show the window first, move it afterwards — untried, cheap, best lead

The documented pattern for placing an `NSWindow` on a secondary display is to
**order it front first, then set its position asynchronously on the next run-loop
turn** — commonly with `alphaValue = 0` during the move to avoid a visible jump.
Setting the frame before the window is visible is reported not to work when the
target position is on another screen.

PaneBoard does the opposite everywhere. The border box runs
`setFrame(...)` and *then* `orderFrontRegardless()`; the list panels set their
frame at construction via the initializer and never reposition after being shown.
Both are placed before they are visible, and both are the windows that fail.

This is the most attractive remaining candidate: it is cheap, contained, needs no
`NSApp` change, and matches our code's ordering exactly. It should be tried
*before* anything touching the application event loop. It does not explain why the
same code works fine until a wake — so treat it as a robustness fix that may or
may not be the cause, not as a confirmed diagnosis.

Source: [Programmatically move an NSWindow to another screen](https://medium.com/@clyapp/programmatically-move-a-nswindow-to-another-screen-din-macos-a50e12bd722e),
[orderFrontRegardless()](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless())

### 2. This family of breakage is recognised, and restart is the known cure

For agent-style apps, a display disconnect/reconnect is documented to leave AppKit
in a bad state, with **quitting and restarting the app** given as the resolution —
which is exactly our observed behaviour. That is worth knowing mostly as
reassurance that PaneBoard is not doing something exotic; this is a known macOS
failure family for background apps across display reconfiguration.

The catch is that the commonly cited workaround intercepts
`applicationDidChangeScreenParameters:` and re-applies state from there. **We have
measured that notification firing zero times in this process**, so the standard
remedy is unavailable to us as written. Any fix that assumes that notification
will arrive is dead on arrival here.

Source: [Application menu problems and TransformProcessType/SetSystemUIMode](https://developer.apple.com/forums/thread/660203),
[Phantom external display after disconnect](https://discussions.apple.com/thread/251988600)

### 3. Window server coordinate limits — rules out a class of explanation

The window server clamps window position coordinates to ±16,000 and sizes to
10,000. Our secondary display sits at x = −3840 and the boxes are at most a few
thousand points, so we are nowhere near those limits. This *rules out* the
"coordinates out of range so the server clamps to origin" explanation, which was
otherwise a plausible reading of the symptom.

Source: [setFrame:display:](https://developer.apple.com/documentation/appkit/nswindow/setframe(_:display:)?language=objc)

### 4. A risk note for the NSApp.run() option

In agent apps, `NSApplication.run()` is reported to sit idle until some event
arrives to create a Cocoa event — startup can appear to hang until something
provokes it. If the event-loop route is ever taken, expect this and do not
mistake it for a deadlock. This slightly strengthens the case for the smaller
variant discussed in `6e2f6e6` — pumping events from the existing health tick —
over switching the main loop wholesale.

Source: [LSUIElement applications stuck before OnInit](https://github.com/wxWidgets/wxWidgets/issues/16156),
[LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)

### 5. Corroborating background, no action

`NSScreen.screens` returning a stale cached array in apps that are not
conventional `NSApplication`s is documented, and matches our measurement that
AppKit's screen objects keep identical addresses across a wake. It remains
unproven that this staleness *causes* the pinning — dropping the `screen:`
initializer anchor did not help.

Source: [Sunshine: macOS host won't reliably update connected/removed screens](https://github.com/LizardByte/Sunshine/issues/2523)

## What the literature did not answer

Nothing found describes our precise signature: *position discarded while size is
honoured, for every window in a process, persisting until restart*. The reports
above are about windows being *moved* by the system, or about a stale screen list,
not about a process losing the ability to position windows at all. So the sweep
narrowed the options and supplied one concrete untried fix, but it did not
identify a matching root cause. Treat item 1 as the next experiment, not as an
answer.

## Suggested order of attack

1. Reorder placement to show-then-move-async (item 1). Cheap, no `NSApp` change.
2. If that fails, the bounded event-pump experiment described in `6e2f6e6`,
   which only acts once the state is already broken.
3. Only then consider the activation-policy and `NSApp.run()` change, weighing
   the focus-contention risk for a utility whose whole job is focus.

A restart-on-detection fallback remains available at any point: the condition is
now reliably detectable via `kCGWindowBounds`, so PaneBoard can report it or
re-exec itself without touching AppKit at all.
