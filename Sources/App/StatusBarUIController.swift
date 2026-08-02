import AppKit
import ClaudeUsageBarLib
import SwiftUI

/// Wires the menu-bar status item to a display presenter (popover or window) and
/// drives the on-open refresh.
@MainActor
final class StatusBarUIController<Content: View, Presenter: RootViewPresenting>: NSObject where Presenter.Content == Content {
    private let statusItem: MenuBarStatusItem
    private let openRefreshTrigger: OpenRefreshTrigger
    private let rootView: Content
    private let presenter: Presenter

    init(statusItem: MenuBarStatusItem, openRefreshTrigger: OpenRefreshTrigger, rootView: Content, presenter: Presenter) {
        self.statusItem = statusItem
        self.openRefreshTrigger = openRefreshTrigger
        self.rootView = rootView
        self.presenter = presenter
    }

    func setup() {
        statusItem.setup(target: self, action: #selector(toggleUI))
        presenter.present(rootView: rootView, anchor: statusItem.button)
    }

    func updateStatusItemTitle(_ title: String) {
        statusItem.updateTitle(title)
    }

    @objc func toggleUI() {
        presenter.toggle { [weak self] in
            self?.openRefreshTrigger.fire()
        }
    }
}
