import SwiftUI

/**
 solid-name: TaskPanelHeaderView
 solid-category: view-component
 solid-description: Displays task completion progress.
 */
struct TaskPanelHeaderView: View {
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        HStack {
            icon
            title
            Spacer()
            countText
        }
    }

    private var icon: some View {
        Image(systemName: "checklist")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var title: some View {
        Text("Tasks")
            .font(.caption)
            .fontWeight(.medium)
    }

    private var countText: some View {
        Text("\(completedCount)/\(totalCount)")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    TaskPanelHeaderView(completedCount: 2, totalCount: 5)
}
