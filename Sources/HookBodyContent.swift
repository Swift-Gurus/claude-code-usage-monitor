import SwiftUI

/**
 solid-name: HookBodyContent
 solid-category: view-component
 solid-description: Displays execution details for a hook.
 */
struct HookBodyContent: View {
    let data: HookToolData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HookCommandAndErrorSection(data: data)
            HookOutputSection(data: data)
        }
    }
}

#Preview {
    HookBodyContent(data: HookToolData(
        hookEvent: "PostToolUse", hookName: "PostToolUse:Grep", command: "echo hi", toolUseID: "1",
        durationMs: nil, errorMessage: nil, context: nil, stdout: "done", stderr: nil, exitCode: nil, status: .success
    ))
}
