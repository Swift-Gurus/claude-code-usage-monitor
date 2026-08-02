import AppKit
import SwiftUI

/// Shows the root view in a standalone floating panel.
@MainActor
final class WindowRootPresenter<Content: View> {
    private var window: NSWindow?
    private let panelFactory: WindowPanelFactory

    init(panelFactory: WindowPanelFactory = WindowPanelFactory()) {
        self.panelFactory = panelFactory
    }

    func present(rootView: Content, anchor: NSStatusBarButton?) {
        window = panelFactory.makePanel(rootView: rootView)
    }

    func toggle(onWillShow: () -> Void) {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            onWillShow()
            window.orderFront(nil)
        }
    }
}
