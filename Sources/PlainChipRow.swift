import SwiftUI

/**
 solid-name: PlainChipRow
 solid-category: view-component
 solid-description: Displays a non-expandable tool chip for tools without detail content or results.
 */
struct PlainChipRow: View {
    let tc: LogToolCall
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            chevron
            ToolChipLabel(tc: tc, color: color)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color.opacity(0.8))
    }
}

#Preview {
    PlainChipRow(
        tc: LogToolCall(id: "1", name: "TaskUpdate", data: .taskUpdate(TaskUpdateToolData(taskId: "1", status: "completed"))),
        color: .mint
    )
}
