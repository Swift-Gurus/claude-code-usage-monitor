import SwiftUI

/**
 solid-name: PromptView
 solid-category: view-component
 solid-description: Presents the appropriate interactive prompt for a pending tool call.
 */
struct PromptView: View {
    let tc: LogToolCall
    let bridge: TTYBridge?

    var body: some View {
        switch tc.data {
        case .askUserQuestion(let d): AskUserQuestionPromptView(data: d, toolID: tc.id, bridge: bridge)
        case .exitPlanMode: PlanApprovalPromptView(bridge: bridge)
        default: PermissionPromptView(tc: tc, bridge: bridge)
        }
    }
}

#Preview {
    PromptView(
        tc: LogToolCall(id: "1", name: "Bash", data: .bash(BashToolData(command: "rm -rf /", description: "", timeout: nil))),
        bridge: nil
    )
    .padding()
}
