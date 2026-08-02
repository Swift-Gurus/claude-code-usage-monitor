import AppKit
import SwiftUI

/// Shows the root view in a transient `NSPopover` anchored to the status item.
@MainActor
final class PopoverRootPresenter<Content: View>: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?
    private var anchor: NSStatusBarButton?

    func present(rootView: Content, anchor: NSStatusBarButton?) {
        self.anchor = anchor
        let newPopover = NSPopover()
        newPopover.behavior = .transient
        newPopover.delegate = self
        newPopover.contentViewController = NSHostingController(rootView: rootView)
        popover = newPopover
    }

    func toggle(onWillShow: () -> Void) {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else if let anchor {
            onWillShow()
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        popover?.contentViewController?.view.window?.makeKey()
    }
}
