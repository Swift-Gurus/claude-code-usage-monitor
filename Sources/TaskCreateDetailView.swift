import SwiftUI

/**
 solid-name: TaskCreateDetailView
 solid-category: view-component
 solid-description: Displays details of a TaskCreate tool invocation.
 */
struct TaskCreateDetailView: View {
    let data: TaskCreateToolData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            descriptionIfPresent
            activeFormIfPresent
        }
        .textSelection(.enabled)
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var descriptionIfPresent: some View {
        if !data.description.isEmpty {
            Text(data.description).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var activeFormIfPresent: some View {
        if !data.activeForm.isEmpty {
            Text(data.activeForm).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    TaskCreateDetailView(data: TaskCreateToolData(subject: "Fix bug", description: "Investigate crash", activeForm: "Fixing bug"))
        .padding()
}