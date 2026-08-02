import AppKit
import SwiftUI

/// Builds the floating panel used to host the root view in standalone-window mode.
struct WindowPanelFactory {
    func makePanel<Content: View>(rootView: Content) -> NSWindow {
        let hostingView = NSHostingController(rootView: rootView)
        // Prevent SwiftUI from trying to auto-resize the window (causes re-entrant layout crash)
        hostingView.sizingOptions = []

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingView
        panel.title = "Claude Usage"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameAutosaveName("ClaudeUsageBarWindow")
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 300)
        return panel
    }
}
