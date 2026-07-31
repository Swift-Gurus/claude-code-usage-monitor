import SwiftUI

/**
 solid-name: ToolChipView
 solid-category: view-component
 solid-description: Displays a tool call in compact form with optional expansion to show details.
 */
struct ToolChipView: View {
    let tc: LogToolCall
    let resultContent: String?
    let expandTools: Bool

    private var chipColor: Color { tc.data.chipColor }

    var body: some View {
        chipBody
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(chipColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var chipBody: some View {
        if !tc.data.hasDetail && resultContent == nil {
            PlainChipRow(tc: tc, color: chipColor)
        } else {
            ExpandableToolChip(tc: tc, resultContent: resultContent, expandTools: expandTools, color: chipColor)
        }
    }
}

#Preview {
    ToolChipView(
        tc: LogToolCall(id: "1", name: "Bash", data: .bash(BashToolData(command: "ls", description: "", timeout: nil))),
        resultContent: nil, expandTools: false
    )
    .padding()
}
