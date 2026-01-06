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

        // Convert global coordinates to screen-local coordinates
        let sf = screen.frame
        let localX = rectX - sf.origin.x
        let localY = rectY - sf.origin.y

        let windowFrame = NSRect(
            x: localX,
            y: localY,
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
