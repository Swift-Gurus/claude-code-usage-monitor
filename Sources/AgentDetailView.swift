import SwiftUI

/**
 solid-name: AgentDetailView
 solid-category: view-component
 solid-description: Displays formatted details from agent tool data.
 */
struct AgentDetailView: View {
    let data: AgentToolData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            typeIfPresent
            promptIfPresent
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var typeIfPresent: some View {
        if !data.subagentType.isEmpty {
            Text("type: \(data.subagentType)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var promptIfPresent: some View {
        if !data.prompt.isEmpty {
            MonoTextView(text: data.prompt)
        }
    }
}

#Preview {
    AgentDetailView(data: AgentToolData(description: "Explore code", prompt: "Find all usages of X", subagentType: "Explore"))
        .padding()
}
