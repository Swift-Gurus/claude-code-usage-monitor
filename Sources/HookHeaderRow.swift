import SwiftUI

/**
 solid-name: HookHeaderRow
 solid-category: view-component
 solid-description: Displays a visual summary of hook execution information.
 */
struct HookHeaderRow: View {
    let data: HookToolData

    var body: some View {
        HStack(spacing: 6) {
            nameText
            statusBadgeIfPresent
            exitCodeIfPresent
            durationIfPresent
        }
    }

    private var nameText: some View {
        Text(data.hookName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private var statusBadgeIfPresent: some View {
        if let status = data.status, let label = status.badgeLabel {
            HookStatusBadge(label: label, color: status.badgeColor)
        }
    }

    @ViewBuilder
    private var exitCodeIfPresent: some View {
        if let code = data.exitCode {
            exitCodeLabel(code)
        }
    }

    private func exitCodeLabel(_ code: Int) -> some View {
        Text("exit \(code)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(code == 0 ? Color.secondary : Color.red)
    }

    @ViewBuilder
    private var durationIfPresent: some View {
        if let ms = data.durationMs {
            durationLabel(ms)
        }
    }

    private func durationLabel(_ ms: Int) -> some View {
        Text("\(ms) ms")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    HookHeaderRow(data: HookToolData(
        hookEvent: "PostToolUse", hookName: "PostToolUse:Grep", command: "", toolUseID: "1",
        durationMs: 120, errorMessage: nil, context: nil, stdout: nil, stderr: nil, exitCode: 0, status: .success
    ))
}
