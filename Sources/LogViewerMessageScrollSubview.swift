import SwiftUI

/// Thin wrapper isolating MessageScrollSection's parameter list from LogViewerView's body.
struct LogViewerMessageScrollSubview: View {
    let isLoading: Bool
    let messages: [LogMessage]
    let displayedMessages: [LogMessage]
    let roleLabel: (LogMessage) -> String
    let expandThinking: Bool
    let expandTools: Bool
    let toolResultLookup: [String: String]
    let scrollHeight: CGFloat?

    var body: some View {
        MessageScrollSection(
            isLoading: isLoading, messages: messages, displayedMessages: displayedMessages,
            roleLabel: roleLabel, expandThinking: expandThinking, expandTools: expandTools,
            toolResultLookup: toolResultLookup, scrollHeight: scrollHeight
        )
    }
}

#Preview {
    LogViewerMessageScrollSubview(
        isLoading: false, messages: [], displayedMessages: [],
        roleLabel: { _ in "Assistant" }, expandThinking: false, expandTools: false,
        toolResultLookup: [:], scrollHeight: nil
    )
}
