import SwiftUI

/**
 solid-name: LogViewerHeaderView
 solid-category: view-component
 solid-description: Displays session status and enables navigation, task panel access, and session control.
 */
struct LogViewerHeaderView: View {
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
        HStack {
            backButton
            centeredTitleRow
            trailingButtons
        }
    }

    private var centeredTitleRow: some View {
        titleRow
            .frame(maxWidth: .infinity)
    }

    private var backButton: some View {
        Button(action: onDismiss) {
            backButtonLabel
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }

    private var backButtonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("Back")
        }
        .font(navFont)
    }

    private var titleRow: some View {
        LogViewerTitleRow(title: title, isConnected: isConnected, titleFont: titleFont)
    }

    private var trailingButtons: some View {
        LogViewerHeaderTrailingButtons(
            showTaskPanel: $showTaskPanel, hasTasks: hasTasks, canStop: canStop,
            navFont: navFont, onStop: onStop, onOpenFile: onOpenFile
        )
    }
}

#Preview {
    LogViewerHeaderView(
        title: "Preview Session", isConnected: true, showTaskPanel: .constant(true),
        hasTasks: true, canStop: true, navFont: .caption, titleFont: .headline,
        onDismiss: {}, onStop: {}, onOpenFile: {}
    )
}
