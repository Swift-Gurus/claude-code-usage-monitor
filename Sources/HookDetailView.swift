import SwiftUI

/**
 solid-name: HookDetailView
 solid-category: view-component
 solid-description: Renders detailed information about a hook tool call execution.
 */
struct HookDetailView: View {
    let data: HookToolData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HookHeaderRow(data: data)
            HookBodyContent(data: data)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    HookDetailView(data: HookToolData(
        hookEvent: "PostToolUse", hookName: "PostToolUse:Grep", command: "echo hi", toolUseID: "1",
        durationMs: 120, errorMessage: nil, context: nil, stdout: "done", stderr: nil, exitCode: 0, status: .success
    ))
    .padding()
}