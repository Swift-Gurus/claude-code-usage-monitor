import SwiftUI

/**
 solid-name: MessageThinkingView
 solid-category: view-component
 solid-description: Displays auxiliary reasoning content in an expandable collapsible section.
 */
struct MessageThinkingView: View {
    let thinking: String
    let expanded: Bool

    var body: some View {
        ExpandableSection(expanded: expanded, tintColor: .purple.opacity(0.8)) {
            thinkingText
        } label: {
            thinkingLabel
        }
    }

    private var thinkingText: some View {
        Text(thinking)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }

    private var thinkingLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.system(size: 9))
            Text("Thinking")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.purple.opacity(0.8))
    }
}

#Preview {
    MessageThinkingView(thinking: "Considering the best approach...", expanded: true)
        .padding()
}