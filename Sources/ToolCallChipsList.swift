import SwiftUI

/**
 solid-name: ToolCallChipsList
 solid-category: view-component
 solid-description: Displays tool calls associated with a message as a visual list.
 */
struct ToolCallChipsList: View {
    let toolCalls: [LogToolCall]
    let expandTools: Bool
    let toolResultLookup: [String: String]

    var body: some View {
        if !toolCalls.isEmpty {
            chips
        }
    }

    private var chips: some View {
        ForEach(toolCalls) { tc in
            ToolChipView(tc: tc, resultContent: toolResultLookup[tc.id], expandTools: expandTools)
        }
    }
}

#Preview {
    ToolCallChipsList(toolCalls: [], expandTools: false, toolResultLookup: [:])
}
