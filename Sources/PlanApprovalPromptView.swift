import SwiftUI

/**
 solid-name: PlanApprovalPromptView
 solid-category: view-component
 solid-description: A prompt interface for user decisions that sends selections through a communication bridge.
 */
struct PlanApprovalPromptView: View {
    let bridge: TTYBridge?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            buttons
        }
        .padding(10)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var header: some View {
        HStack(spacing: 6) {
            approvalIcon
            headerText
        }
    }

    private var approvalIcon: some View {
        Image(systemName: "doc.text")
            .font(.caption)
            .foregroundStyle(.blue)
    }

    private var headerText: some View {
        Text("Plan ready for review")
            .font(.caption)
            .fontWeight(.medium)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            PromptActionButton(title: "Approve", tint: .green) { bridge?.sendRaw("\r") }
            PromptActionButton(title: "Reject", tint: .red) { bridge?.sendRaw("\u{1b}") }
        }
    }
}

#Preview {
    PlanApprovalPromptView(bridge: nil)
}
