import SwiftUI

/**
 solid-name: MessageListContent
 solid-category: view-component
 solid-description: Renders a collection of messages with configurable role labels and content expansion, without scroll behavior.
 */
struct MessageListContent: View {
    let displayedMessages: [LogMessage]
    let roleLabel: (LogMessage) -> String
    let expandThinking: Bool
    let expandTools: Bool
    let toolResultLookup: [String: String]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            MessageListItems(
                displayedMessages: displayedMessages, roleLabel: roleLabel, expandThinking: expandThinking,
                expandTools: expandTools, toolResultLookup: toolResultLookup
            )
        }
    }
}

#Preview {
    MessageListContent(
        displayedMessages: [], roleLabel: { _ in "" }, expandThinking: false,
        expandTools: false, toolResultLookup: [:]
    )
}