import SwiftUI

/**
 solid-name: MessageContentBubbleView
 solid-category: view-component
 solid-description: Displays a message bubble containing its text and tool calls, styled according to message role.
 */
struct MessageContentBubbleView: View {
    let msg: LogMessage
    let expandTools: Bool
    let toolResultLookup: [String: String]

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var bubbleColor: Color {
        switch msg.role {
        case .user: return .green.opacity(0.08)
        case .assistant: return .blue.opacity(0.08)
        case .system: return .orange.opacity(0.08)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextBlocksContent(textContent: msg.textContent)
            ToolCallChipsList(toolCalls: msg.toolCalls, expandTools: expandTools, toolResultLookup: toolResultLookup)
        }
    }
}

#Preview {
    MessageContentBubbleView(
        msg: LogMessage(
            id: "1", role: .assistant, model: nil, timestamp: nil, thinking: nil,
            textContent: ["Sample response"], toolCalls: [], toolResultIDs: [], toolResponses: [:],
            toolResultContents: [:]
        ),
        expandTools: false, toolResultLookup: [:]
    )
    .padding()
}