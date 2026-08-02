import SwiftUI

/**
 solid-name: LogViewerHeaderView
 solid-category: view-component
 solid-description: Displays session status and provides controls for log viewer operations.
 */
struct LogViewerHeaderView: View {
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
        HStack {
            BackButton(font: navFont, action: onDismiss)
            centeredTitleRow
            trailingButtons
        }
    }

    private var centeredTitleRow: some View {
        titleRow
            .frame(maxWidth: .infinity)
    }

    private var titleRow: some View {
        LogViewerTitleRow(title: title, isConnected: isConnected, titleFont: titleFont)
    }

    private var trailingButtons: some View {
        LogViewerHeaderTrailingButtons(
            showTaskPanel: $showTaskPanel, hasTasks: hasTasks,
            showStatsPanel: $showStatsPanel, hasStats: hasStats,
            canStop: canStop, navFont: navFont, onStop: onStop, onOpenFile: onOpenFile
        )
    }
}

#Preview {
    LogViewerHeaderView(
        title: "Preview Session", isConnected: true, showTaskPanel: .constant(true),
        hasTasks: true, showStatsPanel: .constant(false), hasStats: true,
        canStop: true, navFont: .caption, titleFont: .headline,
        onDismiss: {}, onStop: {}, onOpenFile: {}
    )
}