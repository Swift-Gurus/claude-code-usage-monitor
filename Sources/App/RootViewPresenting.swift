import AppKit
import SwiftUI

/// One display strategy (popover or window) for the app's root view.
@MainActor
protocol RootViewPresenting<Content>: AnyObject {
    associatedtype Content: View
    func present(rootView: Content, anchor: NSStatusBarButton?)
    func toggle(onWillShow: () -> Void)
}
