import SwiftUI

/**
 solid-name: MessageListItems
 solid-category: view-component
 solid-description: Renders the provided log messages.
 */
struct MessageListItems: View {
    let displayedMessages: [LogMessage]
    let roleLabel: (LogMessage) -> String
    let expandThinking: Bool
    let expandTools: Bool
    let toolResultLookup: [String: String]

    var body: some View {
        ForEach(displayedMessages) { msg in
            MessageBubbleView(
                msg: msg, roleLabel: roleLabel(msg), expandThinking: expandThinking,
                expandTools: expandTools, toolResultLookup: toolResultLookup
            )
            .id(msg.id)
        }
    }
}

#Preview {
    MessageListItems(
        displayedMessages: [], roleLabel: { _ in "" }, expandThinking: false,
        expandTools: false, toolResultLookup: [:]
    )
}
