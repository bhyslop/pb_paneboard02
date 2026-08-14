// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

import Foundation
import Cocoa

// C callback types
public typealias ActivationCallback = @convention(c) (Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void
public typealias TerminationCallback = @convention(c) (Int32) -> Void
public typealias PrepopulationCallback = @convention(c) (Int32, UnsafePointer<CChar>?, UnsafePointer<CChar>?, Bool) -> Void

// MARK: - Timer Lifecycle Utilities

/// Manages timer lifecycle for reusable timer management
class TimerManager {
    private var timer: Timer?

    /// Start a timer with specified interval and handler
    func start(interval: TimeInterval, repeats: Bool = true, handler: @escaping () -> Void) {
        stop() // Ensure any existing timer is stopped
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            handler()
        }
    }

    /// Stop the current timer
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

// MARK: - FFI String Conversion Helpers

/// Convert C string array to Swift strings
/// - Parameters:
///   - count: Number of strings
///   - ptrs: Pointer to array of C string pointers
/// - Returns: Array of Swift strings
func ffiToStrings(count: Int32, ptrs: UnsafePointer<UnsafePointer<CChar>?>) -> [String] {
    var result: [String] = []
    for i in 0..<Int(count) {
        guard let ptr = ptrs[i] else {
            result.append("")
            continue
        }
        result.append(String(cString: ptr))
    }
    return result
}

// MARK: - Screen Diagnostics

private let pbmboTimestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

func pbmboTimestamp() -> String {
    return pbmboTimestampFormatter.string(from: Date())
}

private func pbmboRectString(_ r: NSRect) -> String {
    return "(\(Int(r.origin.x)),\(Int(r.origin.y)),\(Int(r.size.width)),\(Int(r.size.height)))"
}

/// CGDirectDisplayID backing an NSScreen, or 0 if AppKit won't say.
private func pbmboDisplayId(of screen: NSScreen) -> CGDirectDisplayID {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
}

/// Whether this login session currently owns the console (false while locked).
private func pbmboOnConsole() -> String {
    guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return "<none>" }
    let onConsole = (d["kCGSSessionOnConsoleKey"] as? Bool) ?? false
    let loginDone = (d["kCGSessionLoginDoneKey"] as? Bool) ?? false
    return "onConsole=\(onConsole) loginDone=\(loginDone)"
}

/// Height of the display at the global origin, for server↔Cocoa Y conversion.
private func pbmboPrimaryHeight() -> CGFloat {
    for s in NSScreen.screens where s.frame.origin == .zero {
        return s.frame.height
    }
    return NSScreen.screens.first?.frame.height ?? 0
}

/// Window-server bounds for a window id, converted to Cocoa coordinates
/// (bottom-left origin, Y up) so it compares directly against NSWindow.frame.
///
/// This is ground truth independent of both AX and AppKit: AX can serve stale
/// geometry, and NSWindow.frame reports what AppKit believes rather than where
/// the server actually composited the window. Where the three disagree names
/// the culprit.
private func pbmboServerFrameCocoa(_ windowId: UInt32) -> NSRect? {
    guard windowId != 0,
          let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowId) as? [[String: Any]],
          let entry = info.first,
          let boundsDict = entry[kCGWindowBounds as String],
          let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary)
    else { return nil }

    // kCGWindowBounds is top-left origin, Y down; flip to Cocoa.
    return NSRect(x: bounds.origin.x,
                  y: pbmboPrimaryHeight() - bounds.origin.y - bounds.size.height,
                  width: bounds.size.width,
                  height: bounds.size.height)
}

/// Log a timestamped snapshot of all screens plus the persistent highlight
/// border window's state. Fired at alt-tab session start and on display
/// sleep/wake/reconfiguration, so a capture spanning monitor power-down shows
/// what geometry AppKit believed at each transition and whether the reused
/// border NSWindow drifted with it.
func pbmboLogScreenSnapshot(_ tag: String) {
    let screens = NSScreen.screens
    let running = NSApp?.isRunning ?? false
    let policy = NSApp?.activationPolicy().rawValue ?? -1
    print("SCREEN: [\(pbmboTimestamp())] \(tag) count=\(screens.count) nsapp_running=\(running) policy=\(policy) \(pbmboOnConsole())")

    for (idx, s) in screens.enumerated() {
        let primary = (s.frame.origin == .zero) ? " primary" : ""

        // AppKit caches its NSScreen objects and refreshes them as the
        // application event loop handles a reconfiguration. This process runs a
        // bare CFRunLoop and never starts that loop, so the cache may go stale —
        // and because the configuration returns to identical values across a
        // wake, a stale array is indistinguishable from a fresh one by geometry
        // alone. Print the object address, so a rebuild is visible, and
        // CoreGraphics' bounds for the same display id, so a disagreement
        // between AppKit's belief and the hardware truth is named outright.
        let did = pbmboDisplayId(of: s)
        let obj = UInt(bitPattern: Unmanaged.passUnretained(s).toOpaque().hashValue) & 0xffffff
        var cgStr = "<none>"
        var disagree = ""
        if did != 0 {
            let cg = CGDisplayBounds(did)
            cgStr = "(\(Int(cg.origin.x)),\(Int(cg.origin.y)),\(Int(cg.size.width)),\(Int(cg.size.height)))"
            if abs(cg.size.width - s.frame.width) > 2 || abs(cg.size.height - s.frame.height) > 2 {
                disagree = " APPKIT_CG_DISAGREE"
            }
        }
        print("SCREEN:   [\(idx)] \"\(s.localizedName)\" id=\(did) obj=\(String(obj, radix: 16)) frame=\(pbmboRectString(s.frame)) visible=\(pbmboRectString(s.visibleFrame)) cg_bounds=\(cgStr)\(disagree)\(primary)")
    }

    if let hw = highlightBorderWindow {
        let screenName = hw.screen?.localizedName ?? "<none>"
        print("SCREEN:   highlightBorderWindow frame=\(pbmboRectString(hw.frame)) screen=\"\(screenName)\" visible=\(hw.isVisible)")
    }
}

private func pbmboReconfigFlagNames(_ flags: CGDisplayChangeSummaryFlags) -> String {
    let table: [(CGDisplayChangeSummaryFlags, String)] = [
        (.beginConfigurationFlag, "begin"),
        (.movedFlag, "moved"),
        (.setMainFlag, "setMain"),
        (.addFlag, "add"),
        (.removeFlag, "remove"),
        (.enabledFlag, "enabled"),
        (.disabledFlag, "disabled"),
        (.mirrorFlag, "mirror"),
        (.unMirrorFlag, "unmirror"),
        (.desktopShapeChangedFlag, "desktopShapeChanged"),
    ]
    let names = table.filter { flags.contains($0.0) }.map { $0.1 }
    return names.isEmpty ? "none" : names.joined(separator: "|")
}

/// CoreGraphics-level display reconfiguration hook.
///
/// PaneBoard drives a bare CFRunLoop and never starts an NSApplication event
/// loop, so NSApplication.didChangeScreenParametersNotification may never post
/// here — its silence cannot be read as "no reconfiguration happened". This
/// callback is delivered by CoreGraphics directly to the run loop and does not
/// depend on NSApp, making it the authoritative detector.
private func pbmboDisplayReconfigCallback(_ display: CGDirectDisplayID,
                                          _ flags: CGDisplayChangeSummaryFlags,
                                          _ userInfo: UnsafeMutableRawPointer?) {
    print("SCREEN: [\(pbmboTimestamp())] event=displayReconfig display=\(display) flags=\(pbmboReconfigFlagNames(flags))")
    // The begin pass fires before the new geometry is readable; snapshot on the
    // settled pass only.
    if !flags.contains(.beginConfigurationFlag) {
        pbmboLogScreenSnapshot("event=displayReconfigSettled display=\(display)")
    }
}

private var pbmboPumpTotal = 0
private var pbmboPumpQuietTicks = 0

/// Drain and dispatch AppKit's pending events.
///
/// This process runs a bare CFRunLoop and never starts the application event
/// loop, so nothing consumes the NSEvents the window server delivers — including
/// the display-reconfiguration events AppKit uses to refresh its screen table
/// and window-placement state. That is the standing candidate for why every
/// window this process creates is committed at the global origin after a wake
/// until the process restarts.
///
/// Draining the queue by hand is the documented way to process AppKit events
/// without NSApplication.run(). It must happen on the main thread, which the
/// health tick that calls this already is.
///
/// The drain is bounded. This shares a run loop with the CGEventTap, and macOS
/// disables a tap whose callbacks run long; a flood of events must not be able
/// to stall the tick that exists to keep that tap alive.
@_cdecl("pbmbo_pump_app_events")
public func pbmbo_pump_app_events() {
    let app = NSApplication.shared
    var pumped = 0

    // Dequeue only — deliberately no sendEvent.
    //
    // Dispatching into an NSApplication that was never started ended the
    // process: it exited cleanly three seconds in, as the characterization
    // windows closed, because AppKit believes it is inside its own run loop and
    // a dispatched event stopped the main CFRunLoop out from under us.
    //
    // Draining without dispatching is also strictly closer to today's behaviour
    // than dispatching is: nothing consumes these events at present, so they
    // simply accumulate. PaneBoard takes its input from the CGEventTap and its
    // overlays ignore mouse events, so discarding them costs nothing — while
    // the dequeue itself still gives AppKit the chance to run the bookkeeping
    // that refreshes its screen table.
    while pumped < 32,
          app.nextEvent(matching: .any,
                        until: .distantPast,
                        inMode: .default,
                        dequeue: true) != nil {
        pumped += 1
    }

    guard pumped > 0 else { return }
    pbmboPumpTotal += pumped

    // Report sparsely: a line every ~5s of non-empty ticks keeps a long capture
    // readable, but never swallow a large drain, which is the interesting case.
    pbmboPumpQuietTicks += 1
    if pumped >= 8 || pbmboPumpQuietTicks >= 10 {
        print("PUMP: [\(pbmboTimestamp())] drained=\(pumped) total=\(pbmboPumpTotal)")
        pbmboPumpQuietTicks = 0
    }
}

/// C-ABI entry so the Rust-side configuration poll can emit a timestamped
/// AppKit snapshot alongside its own findings.
@_cdecl("pbmbo_log_screen_snapshot")
public func pbmbo_log_screen_snapshot(_ tag: UnsafePointer<CChar>?) {
    let label = tag.map { String(cString: $0) } ?? "unspecified"
    pbmboLogScreenSnapshot("event=\(label)")
}

// Global callback storage
private var globalActivationCallback: ActivationCallback?
private var globalTerminationCallback: TerminationCallback?

// Observer class to handle notifications
class PbmsoObserver {
    init() {
        let workspace = NSWorkspace.shared
        let center = workspace.notificationCenter

        // App activation notification
        center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            let pid = app.processIdentifier
            let bundleID = app.bundleIdentifier ?? "<no_bundle_id>"
            let name = app.localizedName ?? "<no_name>"

            // Call into Rust
            if let callback = globalActivationCallback {
                bundleID.withCString { bundlePtr in
                    name.withCString { namePtr in
                        callback(pid, bundlePtr, namePtr)
                    }
                }
            }
        }

        // App termination notification
        center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            let pid = app.processIdentifier

            // Call into Rust
            if let callback = globalTerminationCallback {
                callback(pid)
            }
        }

        // Display sleep/wake and reconfiguration: timestamped screen snapshots,
        // so a log spanning monitor power-down records what AppKit believed at
        // each transition (highlight-border misplacement investigation).
        center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            pbmboLogScreenSnapshot("event=screensDidSleep")
        }

        center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            pbmboLogScreenSnapshot("event=screensDidWake")
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            pbmboLogScreenSnapshot("event=didChangeScreenParameters")
        }

        // System sleep, distinct from screen sleep.
        for (name, label) in [(NSWorkspace.willSleepNotification, "willSleep"),
                              (NSWorkspace.didWakeNotification, "didWake")] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                pbmboLogScreenSnapshot("event=\(label)")
            }
        }

        // Idle progresses through separable stages — screensaver start, screen
        // lock, then display power-down — and only some of them disturb the
        // display configuration. Observing each separately tells us which stage
        // the geometry breakage tracks, rather than lumping them as "sleep".
        let distributed = DistributedNotificationCenter.default()
        for name in ["com.apple.screenIsLocked",
                     "com.apple.screenIsUnlocked",
                     "com.apple.screensaver.didstart",
                     "com.apple.screensaver.didstop"] {
            distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { _ in
                pbmboLogScreenSnapshot("event=\(name)")
            }
        }

        CGDisplayRegisterReconfigurationCallback(pbmboDisplayReconfigCallback, nil)
    }
}

// Keep observer alive
private var observer: PbmsoObserver?

// C-ABI entry point called by Rust
@_cdecl("pbmso_register_observer")
public func pbmso_register_observer(
    _ activationCallback: @escaping ActivationCallback,
    _ terminationCallback: @escaping TerminationCallback
) {
    // Swift's stdout is block-buffered when not a TTY, while Rust's is line
    // buffered. Sharing one fd through two buffers splices Rust lines into the
    // middle of Swift lines and strands Swift's tail, so a captured log cannot
    // be read in order. Line-buffer this side to match.
    setvbuf(stdout, nil, _IOLBF, 0)

    globalActivationCallback = activationCallback
    globalTerminationCallback = terminationCallback
    observer = PbmsoObserver()
}

// C-ABI entry point for prepopulation
@_cdecl("pbmso_prepopulate_mru")
public func pbmso_prepopulate_mru(
    _ callback: @escaping PrepopulationCallback
) {
    let workspace = NSWorkspace.shared

    // Get frontmost app to mark it as KNOWN
    let frontmostApp = workspace.frontmostApplication
    let frontmostPid = frontmostApp?.processIdentifier ?? -1

    // Get all running applications
    let runningApps = workspace.runningApplications

    // Filter to .regular activation policy only
    let regularApps = runningApps.filter { $0.activationPolicy == .regular }

    // Call callback for frontmost first (if it's regular)
    if let frontmost = frontmostApp, regularApps.contains(where: { $0.processIdentifier == frontmost.processIdentifier }) {
        let pid = frontmost.processIdentifier
        let bundleID = frontmost.bundleIdentifier ?? "<no_bundle_id>"
        let name = frontmost.localizedName ?? "<no_name>"

        bundleID.withCString { bundlePtr in
            name.withCString { namePtr in
                callback(pid, bundlePtr, namePtr, true) // true = KNOWN
            }
        }
    }

    // Then call callback for all other regular apps (as GUESS)
    for app in regularApps {
        let pid = app.processIdentifier

        // Skip frontmost (already added as KNOWN)
        if pid == frontmostPid {
            continue
        }

        let bundleID = app.bundleIdentifier ?? "<no_bundle_id>"
        let name = app.localizedName ?? "<no_name>"

        bundleID.withCString { bundlePtr in
            name.withCString { namePtr in
                callback(pid, bundlePtr, namePtr, false) // false = GUESS
            }
        }
    }
}

// MARK: - Unified Overlay Manager

// Overlay entry data structure (used for both Alt-Tab and Clipboard)
public struct OverlayEntry {
    let bundleId: String
    let title: String
    let activationState: String  // "KNOWN", "GUESS", or "CLIPBOARD"
    let icon: NSImage?
}

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// One of these is placed per screen, so the secondary-display panel is
    /// subject to the same stale-screen clamp that drags the highlight border
    /// onto the primary. See HighlightBorderWindow.constrainFrameRect.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let wanted = super.constrainFrameRect(frameRect, to: screen)
        if abs(wanted.origin.x - frameRect.origin.x) > 1 || abs(wanted.origin.y - frameRect.origin.y) > 1 {
            print("OVERLAY:   CONSTRAIN_CLAMP proposed=(\(Int(frameRect.origin.x)),\(Int(frameRect.origin.y))) appkit_wanted=(\(Int(wanted.origin.x)),\(Int(wanted.origin.y))) — refused")
        }
        return frameRect
    }
}

class OverlayManager {
    private var overlayWindows: [OverlayWindow] = []

    func showOverlays(entries: [OverlayEntry], highlightIndex: Int) {
        // Called from main runloop via CFRunLoopPerformBlock, already on main thread
        // Hide any existing overlays first (use orderOut, not close)
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()

        // Create overlay on each display
        for screen in NSScreen.screens {
            let overlay = createOverlay(for: screen, entries: entries, highlightIndex: highlightIndex)
            overlayWindows.append(overlay)
            overlay.orderFrontRegardless()
        }

    }

    /// Discriminator for the border-box misplacement.
    ///
    /// The border box is pinned at the global origin by the server while its
    /// size is honoured, and neither the window's age, AppKit's clamp, nor the
    /// screen anchor accounts for it. These list panels are separate windows
    /// built by a separate path. If they are pinned too, the damage belongs to
    /// the process's window-server connection and no per-window remedy can
    /// reach it; if they place correctly, the difference between these two
    /// window configurations localises the fault.
    ///
    /// Called from the border box's own deferred probe rather than at creation:
    /// a window is not yet in the server's list one run-loop turn after being
    /// ordered front, which left every reading from the earlier probe site
    /// empty.
    func logPanelServerBounds() {
        for (idx, w) in overlayWindows.enumerated() {
            let believed = w.frame
            guard let server = pbmboServerFrameCocoa(UInt32(max(0, w.windowNumber))) else {
                print("OVERLAY:   panel[\(idx)] server=<unavailable>")
                continue
            }
            let agrees = abs(server.origin.x - believed.origin.x) < 2
                && abs(server.origin.y - believed.origin.y) < 2
            let tag = agrees ? "" : " PANEL_SERVER_MISMATCH"
            print("OVERLAY:   panel[\(idx)] appkit=\(pbmboRectString(believed)) server=\(pbmboRectString(server))\(tag)")
        }
    }

    func updateHighlight(entries: [OverlayEntry], highlightIndex: Int) {
        // Called from main runloop via CFRunLoopPerformBlock, already on main thread
        // Update all overlays with new highlight
        for overlay in overlayWindows {
            if let contentView = overlay.contentView as? OverlayContentView {
                contentView.updateContent(entries: entries, highlightIndex: highlightIndex)
            }
        }
    }

    func hideOverlays() {
        // Called from main runloop via CFRunLoopPerformBlock, already on main thread
        // Use orderOut instead of close() to avoid complex cleanup
        for window in overlayWindows {
            window.orderOut(nil)
        }
        // Don't remove from array - will be cleaned up on next showOverlays
    }

    private func createOverlay(for screen: NSScreen, entries: [OverlayEntry], highlightIndex: Int) -> OverlayWindow {
        // Use visibleFrame so overlays fit inside usable display area (menu bar & Dock)
        // BUT convert from global coords to this screen's local coordinate space.
        let vf = screen.visibleFrame
        let sf = screen.frame

        // Convert global visibleFrame.origin → local-to-this-screen origin.
        let localX = vf.origin.x - sf.origin.x
        let localY = vf.origin.y - sf.origin.y

        let overlayHeight = vf.height / 2
        // Expand width slightly to accommodate icons (add 60pt for icon + spacing)
        let overlayWidth = min(vf.width * 0.9, vf.width - 100)
        let overlayFrame = NSRect(
            x: localX + (vf.width - overlayWidth) / 2,
            y: localY,
            width: overlayWidth,
            height: overlayHeight
        )

        let window = OverlayWindow(
            contentRect: overlayFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = false
        window.backgroundColor = NSColor(white: 0.1, alpha: 0.9)
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        // Borderless windows inherit .default animationBehavior, which makes macOS
        // fade them in/out on orderFront/orderOut. Suppress it so Alt-Tab appears
        // and dismisses instantly.
        window.animationBehavior = .none

        // Create content view
        let contentView = OverlayContentView(frame: overlayFrame)
        contentView.updateContent(entries: entries, highlightIndex: highlightIndex)
        window.contentView = contentView

        return window
    }
}

class OverlayContentView: NSView {
    private var entries: [OverlayEntry] = []
    private var highlightIndex: Int = 0

    func updateContent(entries: [OverlayEntry], highlightIndex: Int) {
        self.entries = entries
        self.highlightIndex = highlightIndex
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !entries.isEmpty else {
            // Draw empty message based on type
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.white
            ]
            let message = "(no items)"
            let size = message.size(withAttributes: attrs)
            let point = NSPoint(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2
            )
            message.draw(at: point, withAttributes: attrs)
            return
        }

        // Detect overlay type from first entry
        let isClipboard = entries.first?.activationState == "CLIPBOARD"

        if isClipboard {
            drawClipboardEntries()
        } else {
            drawAltTabEntries()
        }
    }

    private func drawClipboardEntries() {
        let padding: CGFloat = 20
        let lineHeight: CGFloat = 34
        var yPos = bounds.height - padding - lineHeight

        for (index, entry) in entries.enumerated() {
            let isHighlighted = (index == highlightIndex)

            if isHighlighted {
                NSColor(white: 0.3, alpha: 0.8).setFill()
                let highlightRect = NSRect(
                    x: padding,
                    y: yPos,
                    width: bounds.width - 2 * padding,
                    height: lineHeight
                )
                NSBezierPath(rect: highlightRect).fill()
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular),
                .foregroundColor: NSColor.white
            ]

            // Use title field for clipboard text (already truncated)
            let displayText = entry.title
            let text = "\(index + 1). \(displayText)"

            let textHeight = text.size(withAttributes: attrs).height
            let textYOffset = (lineHeight - textHeight) / 2

            let textRect = NSRect(
                x: padding + 10,
                y: yPos + textYOffset,
                width: bounds.width - 2 * padding - 20,
                height: textHeight
            )

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            var attrsWithTruncation = attrs
            attrsWithTruncation[.paragraphStyle] = paragraphStyle

            (text as NSString).draw(in: textRect, withAttributes: attrsWithTruncation)

            yPos -= lineHeight

            if yPos < padding {
                break
            }
        }
    }

    private func drawAltTabEntries() {
        let padding: CGFloat = 20
        let iconSize: CGFloat = 32
        let iconTextSpacing: CGFloat = 10
        let lineHeight: CGFloat = 44
        var yPos = bounds.height - padding - lineHeight

        for (index, entry) in entries.enumerated() {
            let isHighlighted = (index == highlightIndex)

            // Draw highlight background (full width)
            if isHighlighted {
                NSColor(white: 0.3, alpha: 0.8).setFill()
                let highlightRect = NSRect(
                    x: padding,
                    y: yPos,
                    width: bounds.width - 2 * padding,
                    height: lineHeight
                )
                NSBezierPath(rect: highlightRect).fill()
            }

            // Draw icon (32×32, vertically centered in line)
            let iconYOffset = (lineHeight - iconSize) / 2
            let iconRect = NSRect(
                x: padding + 10,
                y: yPos + iconYOffset,
                width: iconSize,
                height: iconSize
            )

            if let icon = entry.icon {
                icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }

            // Draw text (20pt, vertically centered with truncation)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .regular),
                .foregroundColor: NSColor.white
            ]

            let reversedBundle = entry.bundleId
                .split(separator: ".")
                .reversed()
                .joined(separator: ".")
            let text = "\(index + 1). \(entry.title) | \(reversedBundle) [\(entry.activationState)]"
            let textXPos = padding + 10 + iconSize + iconTextSpacing
            let textHeight = text.size(withAttributes: attrs).height
            let textYOffset = (lineHeight - textHeight) / 2

            // Create constrained rect for text with truncation
            let textRect = NSRect(
                x: textXPos,
                y: yPos + textYOffset,
                width: bounds.width - textXPos - padding - 10,
                height: textHeight
            )

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            var attrsWithTruncation = attrs
            attrsWithTruncation[.paragraphStyle] = paragraphStyle

            (text as NSString).draw(in: textRect, withAttributes: attrsWithTruncation)

            yPos -= lineHeight

            // Stop if we run out of space
            if yPos < padding {
                break
            }
        }
    }
}

// Global overlay manager (shared for both Alt-Tab and Clipboard)
private var overlayManager: OverlayManager?

// Icon cache to avoid repeated NSWorkspace lookups
private var iconCache: [String: NSImage] = [:]

// Helper function to fetch app icon by bundle ID
private func fetchAppIcon(bundleId: String) -> NSImage? {
    // Check cache first
    if let cached = iconCache[bundleId] {
        return cached
    }

    // Try to find running app by bundle ID
    let runningApps = NSWorkspace.shared.runningApplications
    if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
        let icon = app.icon
        iconCache[bundleId] = icon
        return icon
    }

    // If not running, try to get icon from bundle path
    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        iconCache[bundleId] = icon
        return icon
    }

    return nil
}

// C-ABI entry points for overlay management
@_cdecl("pbmbo_show_alt_tab_overlay")
public func pbmbo_show_alt_tab_overlay(
    bundle_ids: UnsafePointer<UnsafePointer<CChar>?>,
    titles: UnsafePointer<UnsafePointer<CChar>?>,
    activation_states: UnsafePointer<UnsafePointer<CChar>?>,
    count: Int32,
    highlightIndex: Int32
) {
    if overlayManager == nil {
        overlayManager = OverlayManager()
    }

    // Convert FFI entries to Swift entries using helper
    let bundleIds = ffiToStrings(count: count, ptrs: bundle_ids)
    let titles = ffiToStrings(count: count, ptrs: titles)
    let activationStates = ffiToStrings(count: count, ptrs: activation_states)

    var swiftEntries: [OverlayEntry] = []
    for i in 0..<Int(count) {
        let icon = fetchAppIcon(bundleId: bundleIds[i])
        swiftEntries.append(OverlayEntry(
            bundleId: bundleIds[i],
            title: titles[i],
            activationState: activationStates[i],
            icon: icon
        ))
    }

    // Screen-state snapshot once per alt-tab session (not per tab-press)
    pbmboLogScreenSnapshot("event=altTabSessionStart")

    // Start each gesture with a fresh border window even if the previous
    // session ended without a hide, so none can span a reconfiguration.
    pbmboDestroyHighlightBorder()

    // Debug: print overlay content to console
    print("=== ALT-TAB OVERLAY (showing) ===")
    for (index, entry) in swiftEntries.enumerated() {
        let marker = (index == Int(highlightIndex)) ? " <--" : ""
        print("\(index + 1). \(entry.bundleId) | \"\(entry.title)\" [\(entry.activationState)]\(marker)")
    }
    print("=================================")

    overlayManager?.showOverlays(entries: swiftEntries, highlightIndex: Int(highlightIndex))
}

@_cdecl("pbmbo_update_alt_tab_highlight")
public func pbmbo_update_alt_tab_highlight(
    bundle_ids: UnsafePointer<UnsafePointer<CChar>?>,
    titles: UnsafePointer<UnsafePointer<CChar>?>,
    activation_states: UnsafePointer<UnsafePointer<CChar>?>,
    count: Int32,
    highlightIndex: Int32
) {
    // Convert FFI entries to Swift entries using helper
    let bundleIds = ffiToStrings(count: count, ptrs: bundle_ids)
    let titles = ffiToStrings(count: count, ptrs: titles)
    let activationStates = ffiToStrings(count: count, ptrs: activation_states)

    var swiftEntries: [OverlayEntry] = []
    for i in 0..<Int(count) {
        let icon = fetchAppIcon(bundleId: bundleIds[i])
        swiftEntries.append(OverlayEntry(
            bundleId: bundleIds[i],
            title: titles[i],
            activationState: activationStates[i],
            icon: icon
        ))
    }

    // Debug: print overlay content to console
    print("=== ALT-TAB OVERLAY (highlight update) ===")
    for (index, entry) in swiftEntries.enumerated() {
        let marker = (index == Int(highlightIndex)) ? " <--" : ""
        print("\(index + 1). \(entry.bundleId) | \"\(entry.title)\" [\(entry.activationState)]\(marker)")
    }
    print("==========================================")

    overlayManager?.updateHighlight(entries: swiftEntries, highlightIndex: Int(highlightIndex))
}

@_cdecl("pbmbo_hide_alt_tab_overlay")
public func pbmbo_hide_alt_tab_overlay() {
    overlayManager?.hideOverlays()
}

// MARK: - Clipboard Monitoring

public typealias ClipboardChangeCallback = @convention(c) (UnsafePointer<CChar>?, Int) -> Void

private var globalClipboardCallback: ClipboardChangeCallback?
private var clipboardMonitorManager = TimerManager()
private var lastChangeCount: Int = 0

@_cdecl("pbmso_start_clipboard_monitor")
public func pbmso_start_clipboard_monitor(_ callback: @escaping ClipboardChangeCallback) {
    globalClipboardCallback = callback

    // Initialize with current change count
    lastChangeCount = NSPasteboard.general.changeCount

    // Poll pasteboard every 0.5 seconds using TimerManager
    clipboardMonitorManager.start(interval: 0.5) {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount

            // Try to get text content
            if let text = NSPasteboard.general.string(forType: .string) {
                text.withCString { textPtr in
                    callback(textPtr, text.utf8.count)
                }
            } else {
                // Non-text content (ignore)
                callback(nil, 0)
            }
        }
    }
}

@_cdecl("pbmso_stop_clipboard_monitor")
public func pbmso_stop_clipboard_monitor() {
    clipboardMonitorManager.stop()
    globalClipboardCallback = nil
}

@_cdecl("pbmso_set_clipboard_text")
public func pbmso_set_clipboard_text(_ text: UnsafePointer<CChar>) {
    let swiftText = String(cString: text)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(swiftText, forType: .string)
}

// MARK: - Clipboard Overlay FFI (uses unified OverlayManager)

@_cdecl("pbmbo_show_clipboard_overlay")
public func pbmbo_show_clipboard_overlay(
    entries: UnsafePointer<UnsafePointer<CChar>?>,
    count: Int32,
    highlightIndex: Int32
) {
    if overlayManager == nil {
        overlayManager = OverlayManager()
    }

    // Convert string entries to OverlayEntry with "CLIPBOARD" marker
    let stringEntries = ffiToStrings(count: count, ptrs: entries)
    var overlayEntries: [OverlayEntry] = []

    for text in stringEntries {
        // Truncate long entries and replace newlines
        let displayText = text.count > 100 ? String(text.prefix(100)) + "..." : text
        let singleLine = displayText.replacingOccurrences(of: "\n", with: " ")

        overlayEntries.append(OverlayEntry(
            bundleId: "clipboard",
            title: singleLine,
            activationState: "CLIPBOARD",
            icon: nil
        ))
    }

    overlayManager?.showOverlays(entries: overlayEntries, highlightIndex: Int(highlightIndex))
}

@_cdecl("pbmbo_update_clipboard_highlight")
public func pbmbo_update_clipboard_highlight(
    entries: UnsafePointer<UnsafePointer<CChar>?>,
    count: Int32,
    highlightIndex: Int32
) {
    // Convert string entries to OverlayEntry with "CLIPBOARD" marker
    let stringEntries = ffiToStrings(count: count, ptrs: entries)
    var overlayEntries: [OverlayEntry] = []

    for text in stringEntries {
        // Truncate long entries and replace newlines
        let displayText = text.count > 100 ? String(text.prefix(100)) + "..." : text
        let singleLine = displayText.replacingOccurrences(of: "\n", with: " ")

        overlayEntries.append(OverlayEntry(
            bundleId: "clipboard",
            title: singleLine,
            activationState: "CLIPBOARD",
            icon: nil
        ))
    }

    overlayManager?.updateHighlight(entries: overlayEntries, highlightIndex: Int(highlightIndex))
}

@_cdecl("pbmbo_hide_clipboard_overlay")
public func pbmbo_hide_clipboard_overlay() {
    overlayManager?.hideOverlays()
}

// MARK: - Display Characterization Windows

/// Characterization window with 4px green border and transparent interior
class CharacterizationWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Characterization content view - draws 4px green border only
class CharacterizationContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Clear background (fully transparent)
        NSColor.clear.setFill()
        bounds.fill()

        // Draw 4px green border
        let borderWidth: CGFloat = 4.0
        NSColor.green.setStroke()

        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        borderPath.lineWidth = borderWidth
        borderPath.stroke()
    }
}

/// Manager for characterization windows
private var characterizationWindows: [CharacterizationWindow] = []
private var characterizationTimer: Timer?

/// Show characterization windows with green borders at specified viewport bounds
/// Parameters are flat arrays: xs, ys, widths, heights (each of length count)
@_cdecl("pbmbo_show_characterization_windows")
public func pbmbo_show_characterization_windows(
    xs: UnsafePointer<Double>,
    ys: UnsafePointer<Double>,
    widths: UnsafePointer<Double>,
    heights: UnsafePointer<Double>,
    count: Int32,
    duration_seconds: Double
) {
    // Clean up any existing characterization windows
    for window in characterizationWindows {
        window.orderOut(nil)
    }
    characterizationWindows.removeAll()
    characterizationTimer?.invalidate()

    let screens = NSScreen.screens
    guard !screens.isEmpty else {
        print("CHAR: No screens available for characterization windows")
        return
    }

    // Create a window for each rect
    for i in 0..<Int(count) {
        let rectX = xs[i]
        let rectY = ys[i]
        let rectW = widths[i]
        let rectH = heights[i]

        // Find which screen this rect belongs to
        // (based on the x coordinate falling within screen bounds)
        var targetScreen: NSScreen? = nil
        for screen in screens {
            let sf = screen.frame
            if rectX >= sf.origin.x && rectX < sf.origin.x + sf.size.width {
                targetScreen = screen
                break
            }
        }

        guard let screen = targetScreen else {
            print("CHAR: No screen found for rect at x=\(rectX)")
            continue
        }

        let windowFrame = NSRect(
            x: rectX,
            y: rectY,
            width: rectW,
            height: rectH
        )

        let window = CharacterizationWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar + 1  // Above normal overlays
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true

        let contentView = CharacterizationContentView(frame: windowFrame)
        window.contentView = contentView

        // windowFrame is global; the screen: initializer above treats contentRect as
        // screen-local, double-counting the origin and throwing the box off secondary
        // displays. setFrame takes true global coordinates, so it lands it correctly.
        window.setFrame(windowFrame, display: false)

        characterizationWindows.append(window)
        window.orderFrontRegardless()

        print("CHAR: Window \(i) shown at (\(rectX), \(rectY), \(rectW), \(rectH))")
    }

    // Schedule auto-dismiss after duration
    characterizationTimer = Timer.scheduledTimer(withTimeInterval: duration_seconds, repeats: false) { _ in
        for window in characterizationWindows {
            window.orderOut(nil)
        }
        characterizationWindows.removeAll()
        print("CHAR: Characterization windows dismissed")
    }
}

// MARK: - Emblem rendering (pbge_ grammar reader)

// Reader half of the FROZEN pbge_ emblem grammar (see paneboard-poc.md
// "Emblem File Format"). The writer is rbm's vvx, in a separate repo; each side
// parses independently. paneboard reads by the window-id it already enumerates.
// The one supported scheme today is iterm-session (the single resolver); the
// typed namespace generalizes later.

private let kPbgeEmblemRoot = ".config/paneboard/emblems"
private let kPbgeScheme = "iterm-session"

// Built-in per-location defaults for any absent style field (the writer config
// supplies the rest at write time; paneboard compiles in fallbacks only, never
// content). The corners (top/bottom) read as glanceable identity badges; the
// middle reads as the centered, highlighted repo/path line.
private let kEmblemCornerColor = NSColor.white
private let kEmblemCornerSize: CGFloat = 84
private let kEmblemMiddleColor = NSColor.yellow
private let kEmblemMiddleSize: CGFloat = 28

// Pill geometry, shared by every placement.
private let kEmblemInset: CGFloat = 14       // from the box edge (clears the 6px border)
private let kEmblemPillPadX: CGFloat = 8
private let kEmblemPillPadY: CGFloat = 5
private let kEmblemLineGap: CGFloat = 2
private let kEmblemCornerRadius: CGFloat = 6

/// Where a region paints on the box. Placement is paneboard's policy keyed by the
/// frozen pbge_location enum — the grammar carries the location, not the geometry.
private enum EmblemPlacement { case topCorners, middleCenter, bottomCorners }

/// One parsed pbge_region: its placement, text lines, and any explicit style.
/// Nil style fields fall back to the per-placement defaults above at draw time.
private struct EmblemRegion {
    var placement: EmblemPlacement
    var lines: [String]
    var color: NSColor?
    var size: CGFloat?
}

/// Resolve a region's color and font size, applying per-placement defaults for
/// any field the file left unset.
private func emblemStyle(for region: EmblemRegion) -> (NSColor, CGFloat) {
    switch region.placement {
    case .middleCenter:
        return (region.color ?? kEmblemMiddleColor, region.size ?? kEmblemMiddleSize)
    case .topCorners, .bottomCorners:
        return (region.color ?? kEmblemCornerColor, region.size ?? kEmblemCornerSize)
    }
}

/// Parse a `### pbge_region { ... }` brace attr-set into key=value pairs.
private func pbgeParseBrace(_ line: String) -> [String: String] {
    guard let open = line.firstIndex(of: "{"),
          let close = line.lastIndex(of: "}"),
          open < close else { return [:] }
    let inner = line[line.index(after: open)..<close]
    var out: [String: String] = [:]
    for pair in inner.split(separator: ",") {
        let kv = pair.split(separator: "=", maxSplits: 1)
        if kv.count == 2 {
            let k = kv[0].trimmingCharacters(in: .whitespaces)
            let v = kv[1].trimmingCharacters(in: .whitespaces)
            out[k] = v
        }
    }
    return out
}

/// Parse a `#rrggbb` hex color; nil on absence or malformed input (caller defaults).
private func pbgeParseColor(_ s: String?) -> NSColor? {
    guard var hex = s else { return nil }
    if hex.hasPrefix("#") { hex.removeFirst() }
    guard hex.count == 6, let v = Int(hex, radix: 16) else { return nil }
    let r = CGFloat((v >> 16) & 0xff) / 255.0
    let g = CGFloat((v >> 8) & 0xff) / 255.0
    let b = CGFloat(v & 0xff) / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
}

private func pbgeLocationPlacement(_ loc: String) -> EmblemPlacement {
    switch loc {
    case "pbge_middle": return .middleCenter
    case "pbge_bottom": return .bottomCorners
    default: return .topCorners  // pbge_top and unknown
    }
}

/// Read and parse the emblem file for one window-id, returning regions in
/// placement order (top, middle, bottom). Empty array = no emblem (absent file,
/// empty file, or no populated regions) — the box then paints exactly as today.
private func pbgeLoadRegions(windowId: UInt32) -> [EmblemRegion] {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(kPbgeEmblemRoot)
        .appendingPathComponent(kPbgeScheme)
        .appendingPathComponent("\(windowId).emblem")

    guard let content = try? String(contentsOf: url, encoding: .utf8),
          !content.isEmpty else {
        return []
    }

    var regions: [EmblemRegion] = []
    var current: EmblemRegion?

    func flush() {
        if let c = current { regions.append(c) }
        current = nil
    }

    for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = String(rawLine)
        if line.hasPrefix("### pbge_region") {
            flush()
            let attrs = pbgeParseBrace(line)
            current = EmblemRegion(
                placement: pbgeLocationPlacement(attrs["pbge_location"] ?? "pbge_top"),
                lines: [],
                color: pbgeParseColor(attrs["pbge_color"]),
                size: attrs["pbge_size"].flatMap { Double($0) }.map { CGFloat($0) }
            )
        } else if line.hasPrefix("#") {
            // H1 (pbge_emblem) / H2 (pbge_pane) close any open region's content.
            flush()
        } else {
            let text = line.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                current?.lines.append(text)
            }
        }
    }
    flush()

    // Order is irrelevant: each placement paints an independent, non-overlapping
    // region of the box.
    return regions.filter { !$0.lines.isEmpty }
}

/// The emblem-drawing surface: a transparent overlay sitting on top of the
/// outline-only highlight border view (which it never modifies). Draws the
/// stacked regions as black backing pills of multi-line text when an emblem is
/// present, and nothing at all when absent — so the box is unchanged from today.
class EmblemContentView: NSView {
    var windowId: UInt32 = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let regions = pbgeLoadRegions(windowId: windowId)
        guard !regions.isEmpty else {
            return  // absent → paint nothing; the box looks exactly like today
        }

        for region in regions {
            let (color, size) = emblemStyle(for: region)
            let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            let block = blockSize(lines: region.lines, font: font)

            switch region.placement {
            case .topCorners:
                let y = bounds.height - kEmblemInset - block.height
                drawBlock(region.lines, font: font, color: color, centered: false,
                          at: NSRect(x: kEmblemInset, y: y, width: block.width, height: block.height))
                drawBlock(region.lines, font: font, color: color, centered: false,
                          at: NSRect(x: bounds.width - kEmblemInset - block.width, y: y, width: block.width, height: block.height))
            case .bottomCorners:
                let y = kEmblemInset
                drawBlock(region.lines, font: font, color: color, centered: false,
                          at: NSRect(x: kEmblemInset, y: y, width: block.width, height: block.height))
                drawBlock(region.lines, font: font, color: color, centered: false,
                          at: NSRect(x: bounds.width - kEmblemInset - block.width, y: y, width: block.width, height: block.height))
            case .middleCenter:
                drawBlock(region.lines, font: font, color: color, centered: true,
                          at: NSRect(x: bounds.midX - block.width / 2, y: bounds.midY - block.height / 2, width: block.width, height: block.height))
            }
        }
    }

    /// Measure the pill footprint (text extent + padding) for a set of lines.
    private func blockSize(lines: [String], font: NSFont) -> NSSize {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var maxW: CGFloat = 0
        var sumH: CGFloat = 0
        for line in lines {
            let sz = (line as NSString).size(withAttributes: attrs)
            maxW = max(maxW, sz.width)
            sumH += sz.height
        }
        let w = maxW + 2 * kEmblemPillPadX
        let h = sumH + CGFloat(max(0, lines.count - 1)) * kEmblemLineGap + 2 * kEmblemPillPadY
        return NSSize(width: w, height: h)
    }

    /// Draw one black backing pill with its text lines, top-to-bottom; left-aligned
    /// in the pill, or horizontally centered when `centered`.
    private func drawBlock(_ lines: [String], font: NSFont, color: NSColor, centered: Bool, at pillRect: NSRect) {
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: kEmblemCornerRadius, yRadius: kEmblemCornerRadius).fill()

        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        var lineY = pillRect.maxY - kEmblemPillPadY
        for line in lines {
            let sz = (line as NSString).size(withAttributes: attrs)
            lineY -= sz.height
            let x = centered ? pillRect.midX - sz.width / 2 : pillRect.minX + kEmblemPillPadX
            (line as NSString).draw(at: NSPoint(x: x, y: lineY), withAttributes: attrs)
            lineY -= kEmblemLineGap
        }
    }
}

// MARK: - Highlight Border Window

/// Highlight border window with parameterized color and 6px border
class HighlightBorderWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Refuse AppKit's "keep this window on a screen" adjustment.
    ///
    /// AppKit runs every setFrame through this and pulls the origin back onto
    /// what it believes the screens are, keeping the size. After a display
    /// reconfiguration that belief goes stale here — this process never runs an
    /// NSApplication event loop, so it never handles the reconfiguration — and
    /// the clamp drags every box to one corner of the primary display while the
    /// size still tracks. That is the observed signature exactly, and it also
    /// explains why creating a fresh window per gesture did not help: the clamp
    /// is applied on every placement regardless of the window's age.
    ///
    /// This box is positioned in global coordinates to bound a specific window,
    /// so it must be free to sit anywhere, including on a secondary display at
    /// negative x. Return the proposed rect untouched.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let wanted = super.constrainFrameRect(frameRect, to: screen)
        if abs(wanted.origin.x - frameRect.origin.x) > 1 || abs(wanted.origin.y - frameRect.origin.y) > 1 {
            print("HIGHLIGHT:   CONSTRAIN_CLAMP proposed=(\(Int(frameRect.origin.x)),\(Int(frameRect.origin.y))) appkit_wanted=(\(Int(wanted.origin.x)),\(Int(wanted.origin.y))) — refused")
        }
        return frameRect
    }
}

/// Highlight border content view - draws 6px colored border only
class HighlightBorderContentView: NSView {
    private var borderColor: NSColor = .orange
    private let borderWidth: CGFloat = 6.0

    func setColor(r: Double, g: Double, b: Double) {
        borderColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Clear background (fully transparent)
        NSColor.clear.setFill()
        bounds.fill()

        // Draw translucent fill
        borderColor.withAlphaComponent(0.15).setFill()
        bounds.fill()

        // Draw 6px colored border
        borderColor.setStroke()

        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        borderPath.lineWidth = borderWidth
        borderPath.stroke()
    }
}

/// Global highlight border window instance (single persistent window)
private var highlightBorderWindow: HighlightBorderWindow?

/// Emblem overlay riding on top of the highlight border view (created with it).
private var highlightEmblemView: EmblemContentView?

/// Show or create highlight border at specified rect with given color.
/// window_id keys the emblem read at the draw site (see EmblemContentView).
@_cdecl("pbmbo_show_highlight_border")
public func pbmbo_show_highlight_border(x: Double, y: Double, w: Double, h: Double, r: Double, g: Double, b: Double, window_id: UInt32) {
    let screens = NSScreen.screens
    guard !screens.isEmpty else {
        print("HIGHLIGHT: No screens available")
        return
    }

    // Find which screen contains this rect
    var targetScreen: NSScreen? = nil
    for screen in screens {
        let sf = screen.frame
        if x >= sf.origin.x && x < sf.origin.x + sf.size.width {
            targetScreen = screen
            break
        }
    }

    guard let screen = targetScreen else {
        print("HIGHLIGHT: No screen found for rect at x=\(x)")
        return
    }

    let windowFrame = NSRect(
        x: x,
        y: y,
        width: w,
        height: h
    )

    // Create window if it doesn't exist, otherwise update existing
    if highlightBorderWindow == nil {
        // Deliberately built without the screen: parameter.
        //
        // AppKit's NSScreen objects are never rebuilt in this process — their
        // addresses are identical from startup through a lock/wake — while the
        // displays behind them are genuinely torn down and recreated, as
        // CoreGraphics reporting a 1x1 secondary mid-wake shows. Anchoring a new
        // window to one of those stale objects appears to leave it without a
        // valid display association, after which the server pins it at the
        // global origin and honours only its size. That matches what the server
        // reports, and it explains why creating the window fresh each gesture
        // did not help: the fresh window was anchored to the same stale screen.
        //
        // Position is set below by setFrame in global coordinates, which needs
        // no screen anchor. The initializer's screen: argument was already
        // suspect here — see the setFrame note below.
        let window = HighlightBorderWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar + 2  // Above Alt-Tab popup (which is at .statusBar)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        // Match the Alt-Tab overlay: no implicit fade on orderFront/orderOut.
        window.animationBehavior = .none
        // We own this reference and drop it to destroy the window; the default
        // release-on-close would double-release it under ARC.
        window.isReleasedWhenClosed = false

        let contentView = HighlightBorderContentView(frame: windowFrame)
        window.contentView = contentView

        // Emblem surface rides on top of the outline-only border view, never
        // altering it; autoresizes with the box as it repositions per tab-press.
        let emblemView = EmblemContentView(frame: contentView.bounds)
        emblemView.autoresizingMask = [.width, .height]
        contentView.addSubview(emblemView)
        highlightEmblemView = emblemView

        // Same screen-local trap as the characterization window: the screen:
        // initializer mis-places the first frame on secondary displays. Force the
        // true global frame so there's no off-screen flash before the first reposition.
        window.setFrame(windowFrame, display: false)

        highlightBorderWindow = window
    } else {
        // Reposition existing window
        highlightBorderWindow?.setFrame(windowFrame, display: true)
    }

    // Set color
    if let contentView = highlightBorderWindow?.contentView as? HighlightBorderContentView {
        contentView.setColor(r: r, g: g, b: b)
    }

    // Point the emblem surface at the selected window; it re-reads at paint time.
    highlightEmblemView?.windowId = window_id

    // Show window
    highlightBorderWindow?.orderFrontRegardless()

    pbmboLogHighlightPlacement(action: "shown", requested: windowFrame, window_id: window_id)
}

/// Log requested vs actual frame after positioning the highlight border.
/// If the window server clamped or reinterpreted the setFrame (the leading
/// hypothesis for post-display-sleep misplacement), the two disagree and the
/// line is tagged DRIFT.
private func pbmboLogHighlightPlacement(action: String, requested: NSRect, window_id: UInt32) {
    guard let window = highlightBorderWindow else { return }
    let actual = window.frame
    let screenName = window.screen?.localizedName ?? "<none>"

    func near(_ a: NSRect, _ b: NSRect) -> Bool {
        return abs(a.origin.x - b.origin.x) < 2
            && abs(a.origin.y - b.origin.y) < 2
            && abs(a.size.width - b.size.width) < 2
            && abs(a.size.height - b.size.height) < 2
    }

    let drift = near(actual, requested) ? "" : " DRIFT"
    print("HIGHLIGHT: [\(pbmboTimestamp())] \(action) requested=\(pbmboRectString(requested)) actual=\(pbmboRectString(actual)) screen=\"\(screenName)\" window_id=\(window_id)\(drift)")

    // Where the window server says the TARGET window is. The border is placed
    // from the AX rect; if AX is serving stale geometry after display sleep the
    // box lands on the window's old position and this line disagrees.
    if let targetBox = pbmboServerFrameCocoa(window_id) {
        let tag = near(targetBox, requested) ? "" : " AX_STALE"
        print("HIGHLIGHT:   target_server=\(pbmboRectString(targetBox))\(tag)")
    } else {
        print("HIGHLIGHT:   target_server=<unavailable>")
    }

    // Where the window server actually put our border box. NSWindow.frame is
    // only AppKit's belief; a disagreement means the server composited the box
    // somewhere other than where it was placed, which requested-vs-actual
    // cannot see. setFrame commits asynchronously, so querying in this run-loop
    // turn always reports the previous frame — defer a turn to read the settled
    // state, otherwise every placement looks mismatched by one step.
    let borderWindowId = UInt32(max(0, window.windowNumber))
    DispatchQueue.main.async {
        if let serverBox = pbmboServerFrameCocoa(borderWindowId) {
            let tag = near(serverBox, requested) ? "" : " SERVER_MISMATCH"
            print("HIGHLIGHT:   border_server_settled=\(pbmboRectString(serverBox)) for=\(pbmboRectString(requested))\(tag)")
        } else {
            print("HIGHLIGHT:   border_server_settled=<unavailable>")
        }
        // Measure the list panels at the same instant, so the two window kinds
        // are compared under identical conditions.
        overlayManager?.logPanelServerBounds()
    }
}

/// Reposition existing highlight border window
@_cdecl("pbmbo_reposition_highlight_border")
public func pbmbo_reposition_highlight_border(x: Double, y: Double, w: Double, h: Double, window_id: UInt32) {
    guard let window = highlightBorderWindow else {
        return  // No-op if not shown
    }

    let screens = NSScreen.screens
    guard !screens.isEmpty else {
        return
    }

    // Find which screen contains this rect
    var targetScreen: NSScreen? = nil
    for screen in screens {
        let sf = screen.frame
        if x >= sf.origin.x && x < sf.origin.x + sf.size.width {
            targetScreen = screen
            break
        }
    }

    guard let screen = targetScreen else {
        return
    }

    let windowFrame = NSRect(
        x: x,
        y: y,
        width: w,
        height: h
    )

    window.setFrame(windowFrame, display: true)

    // Trigger redraw (content view auto-resizes with window)
    if let contentView = window.contentView as? HighlightBorderContentView {
        contentView.needsDisplay = true
    }

    // Re-point the emblem surface; it re-reads at paint time.
    highlightEmblemView?.windowId = window_id

    pbmboLogHighlightPlacement(action: "repositioned", requested: windowFrame, window_id: window_id)
}

/// Destroy the border window rather than merely hiding it.
///
/// A border window that outlives a display reconfiguration stops accepting
/// position changes: the server keeps it pinned at a fixed origin and applies
/// only size changes, so every box lands in the same wrong place. NSWindow.frame
/// still reports the requested rect, which is why this hid behind an
/// AppKit-only check for so long — kCGWindowBounds is the authority.
///
/// The alt-tab list overlays have never shown this, and they are recreated per
/// session; the border box was the one window reused for the process lifetime.
/// Recreating it the same way costs one borderless window per gesture and needs
/// no reconfiguration detection — which matters, because macOS withheld every
/// display notification through the transition that caused this.
private func pbmboDestroyHighlightBorder() {
    guard let window = highlightBorderWindow else { return }
    window.orderOut(nil)
    highlightEmblemView = nil
    window.contentView = nil
    highlightBorderWindow = nil
}

/// Hide highlight border window
@_cdecl("pbmbo_hide_highlight_border")
public func pbmbo_hide_highlight_border() {
    pbmboDestroyHighlightBorder()
    print("HIGHLIGHT: Border hidden")
}
