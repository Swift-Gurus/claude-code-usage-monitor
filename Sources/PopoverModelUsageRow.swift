import SwiftUI

/// One model's input/output token usage for the account's monthly usage breakdown.
struct PopoverModelUsageRow: View {
    let modelID: String
    let inputTokens: Int
    let outputTokens: Int

    var body: some View {
        HStack(spacing: 4) {
            nameText
            Spacer()
            tokenCountLabels
        }
        .padding(.leading, 4)
    }

    private var nameText: some View {
        Text(ClaudeModel.displayName(for: modelID)).font(.system(size: 9)).foregroundStyle(.secondary)
    }

    private var tokenCountLabels: some View {
        HStack(spacing: 4) {
            inputText
            outputText
        }
    }

    private var inputText: some View {
        Text("in: \(inputTokens.asTokenCountString)").font(.system(size: 9)).foregroundStyle(.tertiary)
    }

    private var outputText: some View {
        Text("out: \(outputTokens.asTokenCountString)").font(.system(size: 9)).foregroundStyle(.secondary)
    }
}

#Preview {
    PopoverModelUsageRow(modelID: "claude-opus-4-6", inputTokens: 12_000, outputTokens: 4_500)
}
