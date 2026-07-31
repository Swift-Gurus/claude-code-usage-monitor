import SwiftUI

/**
 solid-name: HookCommandAndErrorSection
 solid-category: view-component
 solid-description: Displays the command executed and any error encountered during a hook's execution.
 */
struct HookCommandAndErrorSection: View {
    let data: HookToolData

    var body: some View {
        commandIfPresent
        errorIfPresent
    }

    @ViewBuilder
    private var commandIfPresent: some View {
        if !data.command.isEmpty {
            MonoTextView(text: data.command, color: .secondary, boxed: false)
        }
    }

    @ViewBuilder
    private var errorIfPresent: some View {
        if let err = data.errorMessage, !err.isEmpty {
            MonoTextView(text: err, color: .red, boxed: false)
        }
    }
}

#Preview {
    HookCommandAndErrorSection(data: HookToolData(
        hookEvent: "PostToolUse", hookName: "Grep", command: "echo hi", toolUseID: "1",
        durationMs: nil, errorMessage: nil, context: nil, stdout: nil, stderr: nil, exitCode: nil, status: nil
    ))
}