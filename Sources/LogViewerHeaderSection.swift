import SwiftUI

/**
 solid-name: LogViewerHeaderSection
 solid-category: view-component
 solid-description: Renders a header section displaying title, connection status, and interactive controls.
 */
struct LogViewerHeaderSection: View {
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
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider()
        }
        .padding(.horizontal, 16)
    }

    private var headerRow: some View {
        LogViewerHeaderView(
            title: title, isConnected: isConnected,
            showTaskPanel: $showTaskPanel, hasTasks: hasTasks,
            canStop: canStop, navFont: navFont, titleFont: titleFont,
            onDismiss: onDismiss, onStop: onStop, onOpenFile: onOpenFile
        )
        .padding(.vertical, 8)
    }
}

#Preview {
    LogViewerHeaderSection(
        title: "Preview Session", isConnected: true, showTaskPanel: .constant(true),
        hasTasks: true, canStop: true, navFont: .caption, titleFont: .headline,
        onDismiss: {}, onStop: {}, onOpenFile: {}
    )
}
