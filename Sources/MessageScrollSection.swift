import SwiftUI

/**
 solid-name: MessageScrollSection
 solid-category: view-component
 solid-description: Displays messages in the log viewer with appropriate handling for loading and empty states.
 */
struct MessageScrollSection: View {
    let isLoading: Bool
    let messages: [LogMessage]
    let displayedMessages: [LogMessage]
    let roleLabel: (LogMessage) -> String
    let expandThinking: Bool
    let expandTools: Bool
    let toolResultLookup: [String: String]
    let scrollHeight: CGFloat?

    var body: some View {
        if isLoading && messages.isEmpty {
            LoadingStateView()
        } else if messages.isEmpty {
            EmptyStateView()
        } else {
            scrollList
        }
    }

    private var scrollList: some View {
        AutoScrollingMessageList(
            displayedMessages: displayedMessages, roleLabel: roleLabel,
            expandThinking: expandThinking, expandTools: expandTools,
            toolResultLookup: toolResultLookup, scrollHeight: scrollHeight
        )
    }
}

#Preview("Loading") {
    MessageScrollSection(
        isLoading: true, messages: [], displayedMessages: [], roleLabel: { _ in "" },
        expandThinking: false, expandTools: false, toolResultLookup: [:], scrollHeight: nil
    )
}

#Preview("Empty") {
    MessageScrollSection(
        isLoading: false, messages: [], displayedMessages: [], roleLabel: { _ in "" },
        expandThinking: false, expandTools: false, toolResultLookup: [:], scrollHeight: nil
    )
}
