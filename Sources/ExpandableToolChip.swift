import SwiftUI

/**
 solid-name: ExpandableToolChip
 solid-category: view-component
 solid-description: Displays tool call information in an expandable format with type-specific details.
 */
struct ExpandableToolChip: View {
    let tc: LogToolCall
    let resultContent: String?
    let expandTools: Bool
    let color: Color

    var body: some View {
        ExpandableSection(expanded: expandTools, tintColor: color.opacity(0.8)) {
            detail
        } label: {
            ToolChipLabel(tc: tc, color: color)
        }
    }

    private var detail: some View {
        ToolDetailContent(data: tc.data, resultContent: resultContent)
    }
}

#Preview {
    ExpandableToolChip(
        tc: LogToolCall(id: "1", name: "Bash", data: .bash(BashToolData(command: "ls -la", description: "", timeout: nil))),
        resultContent: "file1\nfile2", expandTools: true, color: .orange
    )
}
