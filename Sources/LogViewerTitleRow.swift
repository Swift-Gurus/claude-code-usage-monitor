import SwiftUI

/**
 solid-name: LogViewerTitleRow
 solid-category: view-component
 solid-description: Displays the log viewer title with a connection status indicator.
 */
struct LogViewerTitleRow: View {
    let title: String
    let isConnected: Bool
    let titleFont: Font

    var body: some View {
        HStack(spacing: 4) {
            connectionDot
            titleText
        }
    }

    private var connectionDot: some View {
        StatusDot(color: isConnected ? .green : .gray)
            .frame(maxWidth: 6, maxHeight: 6)
    }

    private var titleText: some View {
        Text(title)
            .font(titleFont)
            .lineLimit(1)
    }
}

#Preview {
    LogViewerTitleRow(title: "Preview Session", isConnected: true, titleFont: .headline)
}
