import SwiftUI

/**
 solid-name: TodoRowView
 solid-category: view-component
 solid-description: Displays a todo item with visual indication of its completion status.
 */
struct TodoRowView: View {
    let item: TodoItem

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
    TodoRowView(item: TodoItem(content: "Sample todo", status: "pending"))
}
