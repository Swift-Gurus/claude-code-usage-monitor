import SwiftUI

/**
 solid-name: StatusRowView
 solid-category: view-component
 solid-description: Renders a row for any StatusRowDisplayable item with appearance determined by its completion status.
 */
struct StatusRowView<Item: StatusRowDisplayable>: View {
    let item: Item

    var body: some View {
        HStack(spacing: 6) {
            icon
            contentText
        }
    }

    private var icon: some View {
        Image(systemName: iconName)
            .font(.system(size: 10))
            .foregroundStyle(iconColor)
    }

    private var contentText: some View {
        Text(item.content)
            .font(.system(size: 10))
            .foregroundStyle(item.status == "completed" ? .secondary : .primary)
            .strikethrough(item.status == "completed")
    }

    private var iconName: String {
        switch item.status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        default: return "circle"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case "completed": return .green
        case "in_progress": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    StatusRowView(item: TaskListItem(id: "1", content: "Sample task", status: "pending", activeForm: ""))
}
