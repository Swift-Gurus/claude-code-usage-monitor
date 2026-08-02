import SwiftUI

/// Type-erases `StatusBarUIController<Content, Presenter>` so `AppDependencies` doesn't
/// need to know which display strategy was chosen. `Content` (the SwiftUI root view) stays
/// fully concrete inside the wrapped controller — only the controller reference is erased.
@MainActor
struct AnyStatusBarController {
    let setup: () -> Void
    let updateTitle: (String) -> Void

    init<Content: View, Presenter: RootViewPresenting>(_ controller: StatusBarUIController<Content, Presenter>) where Presenter.Content == Content {
        setup = { controller.setup() }
        updateTitle = { controller.updateStatusItemTitle($0) }
    }
}
