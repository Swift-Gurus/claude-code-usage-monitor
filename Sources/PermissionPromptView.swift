import SwiftUI

/**
 solid-name: PermissionPromptView
 solid-category: view-component
 solid-description: Prompts the user to approve or deny execution of a tool call.
 */
struct PermissionPromptView: View {
    let tc: LogToolCall
    let bridge: TTYBridge?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PromptHeaderRow(tc: tc)
            PermissionButtonsRow(bridge: bridge)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PermissionPromptView(
        tc: LogToolCall(id: "1", name: "Bash", data: .bash(BashToolData(command: "rm -rf /", description: "", timeout: nil))),
        bridge: nil
    )
}