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

### 6. A periodic refresh does exist — pump the AppKit event queue

Follow-up sweep, prompted by the question "is there something we could do every
second to refresh this?" The answer is yes, and it is a documented pattern rather
than a trick.

The standard way to let AppKit process its events without running
`NSApplication.run()` is to drain the queue by hand:

```
while let e = NSApp.nextEvent(matching: .any, until: .distantPast,
                              inMode: .default, dequeue: true) {
    NSApp.sendEvent(e)
}
```

Two properties make this a good fit here. It **must** run on the main thread — and
PaneBoard's 500ms health tick already does, so there is a correct home for it
with no new machinery. And consuming events periodically is described as
*particularly* important for applications that run in the background, which is
exactly our shape: an agent process that never starts the application event loop
and therefore never consumes the events AppKit would use to notice a display
reconfiguration.

Caveat worth respecting: manual event dispatch is not normal practice and is
noted as able to produce odd behaviour. Introduce it deliberately, and watch for
interactions with the CGEventTap, which is a separate mechanism on the same run
loop.

Precedent worth knowing: Godot removed its custom macOS main loop in favour of
`[NSApp run]` plus a CFRunLoop observer — a real project meeting the same
architectural tension and resolving it toward the application event loop rather
than away from it.

Source: [Godot PR #104397 — replace custom main loop with NSApp run](https://github.com/godotengine/godot/pull/104397),
[nextEventMatchingMask must be called on the main thread](https://forums.ni.com/t5/LabVIEW/Labview-crashed-on-Mac-OS-X-Sierra-nextEventMatchingMask-should/td-p/3574639)

### 7. No public way to force the screen cache to refresh

There is no supported API to invalidate `NSScreen`'s cached list on demand. AppKit
does it internally via the private `+[NSScreen _invalidateIfNeededForReason:]`,
visible in the AppKit headers. As shipping SPI it is a non-starter, but as a
*diagnostic* it is attractive: calling it once in the broken state would settle
whether the stale screen cache actually causes the pinning, which the anchor
experiment left unresolved. Treat that strictly as a throwaway experiment, never
as a fix.

Source: [AppKit NSScreen.h headers](https://github.com/w0lfschild/macOS_headers/blob/master/macOS/Frameworks/AppKit/1865.10.102/NSScreen.h),
[NSScreen.screens](https://developer.apple.com/documentation/appkit/nsscreen/1388393-screens)

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
2. Pump the AppKit event queue from the existing 500ms health tick (item 6).
   Also cheap, already has a correct main-thread home, and unlike item 1 it
   addresses the *reason* the process never notices a reconfiguration. These two
   are independent and can be tried in either order — or together, though then a
   success will not say which one earned it.
3. If a causal answer is wanted before committing to either, the private
   screen-cache invalidation (item 7) settles whether staleness is the cause.
   Diagnostic only; never ship it.
4. Only then consider the activation-policy and `NSApp.run()` change, weighing
   the focus-contention risk for a utility whose whole job is focus, and
   expecting the idle-until-first-event behaviour noted in item 4.

A restart-on-detection fallback remains available at any point: the condition is
now reliably detectable via `kCGWindowBounds`, so PaneBoard can report it or
re-exec itself without touching AppKit at all.
