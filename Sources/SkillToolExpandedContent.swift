import SwiftUI

/**
 solid-name: SkillToolExpandedContent
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Renders the expanded detail panel for a skill tool call. Displays the skill name, arguments, and status in a compact collapsible layout. Used inside the tool call chip expansion area in LogViewerView.
 */
struct SkillToolExpandedContent: View {
    let data: SkillToolData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusRow
            argumentsText
        }
        .textSelection(.enabled)
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Text(data.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            if !data.status.isEmpty {
                Text(data.status)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var argumentsText: some View {
        Group {
            if !data.arguments.isEmpty {
                Text(data.arguments)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch data.status.lowercased() {
        case "success", "completed": return .green
        case "error", "failed": return .red
        case "running", "in_progress": return .orange
        default: return .secondary
        }
    }
}
