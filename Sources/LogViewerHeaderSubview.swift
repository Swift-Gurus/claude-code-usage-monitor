import SwiftUI

/// Thin wrapper isolating LogViewerHeaderSection's parameter list from LogViewerView's body.
struct LogViewerHeaderSubview: View {
    let title: String
    let isConnected: Bool
    @Binding var showTaskPanel: Bool
    let hasTasks: Bool
    @Binding var showStatsPanel: Bool
    let hasStats: Bool
    let canStop: Bool
    let navFont: Font
    let titleFont: Font
    let onDismiss: () -> Void
    let onStop: () -> Void
    let onOpenFile: () -> Void

    var body: some View {
        LogViewerHeaderSection(
            title: title, isConnected: isConnected, showTaskPanel: $showTaskPanel,
            hasTasks: hasTasks, showStatsPanel: $showStatsPanel, hasStats: hasStats,
            canStop: canStop, navFont: navFont, titleFont: titleFont,
            onDismiss: onDismiss, onStop: onStop, onOpenFile: onOpenFile
        )
    }
}

#Preview {
    LogViewerHeaderSubview(
        title: "Preview", isConnected: true, showTaskPanel: .constant(true),
        hasTasks: true, showStatsPanel: .constant(false), hasStats: true,
        canStop: true, navFont: .caption, titleFont: .headline,
        onDismiss: {}, onStop: {}, onOpenFile: {}
    )
}
