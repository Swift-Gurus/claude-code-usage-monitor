import SwiftUI

/// Thin wrapper isolating LogViewerHeaderSection's parameter list from LogViewerView's body.
struct LogViewerHeaderSubview: View {
    let title: String
    let isConnected: Bool
    @Binding var showTaskPanel: Bool
    let hasTasks: Bool
    let canStop: Bool
    let navFont: Font
    let titleFont: Font
    let onDismiss: () -> Void
    let onStop: () -> Void
    let onOpenFile: () -> Void

    var body: some View {
        LogViewerHeaderSection(
            title: title, isConnected: isConnected, showTaskPanel: $showTaskPanel,
            hasTasks: hasTasks, canStop: canStop, navFont: navFont, titleFont: titleFont,
            onDismiss: onDismiss, onStop: onStop, onOpenFile: onOpenFile
        )
    }
}

#Preview {
    LogViewerHeaderSubview(
        title: "Preview", isConnected: true, showTaskPanel: .constant(true),
        hasTasks: true, canStop: true, navFont: .caption, titleFont: .headline,
        onDismiss: {}, onStop: {}, onOpenFile: {}
    )
}
