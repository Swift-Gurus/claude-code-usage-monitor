import AppKit

/// Owns the menu-bar status item button and its title text.
@MainActor
final class MenuBarStatusItem {
    private var statusItem: NSStatusItem!

    func setup(target: AnyObject, action: Selector) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Usage")
        button.imagePosition = .imageLeading
        button.target = target
        button.action = action
    }

    var button: NSStatusBarButton? { statusItem.button }

    func updateTitle(_ title: String) {
        statusItem.button?.title = title
    }
}
