import SwiftUI

/**
 solid-name: HookOutputSection
 solid-category: view-component
 solid-description: Renders the output produced by a hook execution.
 */
struct HookOutputSection: View {
    let data: HookToolData

    var body: some View {
        stdoutIfPresent
        stderrIfPresent
        contextIfPresent
    }

    @ViewBuilder
    private var stdoutIfPresent: some View {
        if let out = data.stdout, !out.isEmpty {
            ToolResultView(content: out)
        }
    }

    @ViewBuilder
    private var stderrIfPresent: some View {
        if let errOut = data.stderr, !errOut.isEmpty {
            MonoTextView(text: errOut, color: .red.opacity(0.85), boxed: false)
        }
    }

    @ViewBuilder
    private var contextIfPresent: some View {
        if let ctx = data.context, !ctx.isEmpty {
            ToolResultView(content: ctx)
        }
    }
}

#Preview {
    HookOutputSection(data: HookToolData(
        hookEvent: "PostToolUse", hookName: "Grep", command: "", toolUseID: "1",
        durationMs: nil, errorMessage: nil, context: nil, stdout: "done", stderr: nil, exitCode: nil, status: nil
    ))
}
