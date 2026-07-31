import SwiftUI

/**
 solid-name: ToolChipLabel
 solid-category: view-component
 solid-description: Displays a formatted label for tool chip information.
 */
struct ToolChipLabel: View {
    let tc: LogToolCall
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            nameText
            summaryIfPresent
        }
    }

    private var nameText: some View {
        Text(tc.name)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var summaryIfPresent: some View {
        if !tc.data.summary.isEmpty {
            SummaryTextView(text: tc.data.summary)
        }
    }
}

#Preview {
    ToolChipLabel(
        tc: LogToolCall(id: "1", name: "Bash", data: .bash(BashToolData(command: "ls -la", description: "", timeout: nil))),
        color: .orange
    )
}
