import SwiftUI

/**
 solid-name: MessageBubbleView
 solid-category: view-component
 solid-description: Displays a message with role context and optional thinking and tool response details.
 */
struct MessageBubbleView: View {
    let msg: LogMessage
    let roleLabel: String
    let expandThinking: Bool
    let expandTools: Bool
    let toolResultLookup: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MessageRoleHeaderView(role: msg.role, roleLabel: roleLabel, timestamp: msg.timestamp)
            if let thinking = msg.thinking {
                MessageThinkingView(thinking: thinking, expanded: expandThinking)
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if msg.role == .user, let fullText = msg.textContent.first, fullText.count > 120 {
            LongUserMessageView(fullText: fullText, allTextContent: msg.textContent)
        } else {
            MessageContentBubbleView(msg: msg, expandTools: expandTools, toolResultLookup: toolResultLookup)
        }
    }
}

#Preview {
    MessageBubbleView(
        msg: LogMessage(
            id: "1", role: .assistant, model: "claude-opus-4-6", timestamp: Date(), thinking: nil,
            textContent: ["Hello, how can I help?"], toolCalls: [], toolResultIDs: [], toolResponses: [:],
            toolResultContents: [:]
        ),
        roleLabel: "Opus 4.6", expandThinking: false, expandTools: false, toolResultLookup: [:]
    )
    .padding()
}
