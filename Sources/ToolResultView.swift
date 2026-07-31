import SwiftUI

/**
 solid-name: ToolResultView
 solid-category: view-component
 solid-description: Displays tool command output results.
 */
struct ToolResultView: View {
    let content: String
    private let previewLineCount = 20
    private let lines: [String]
    private let isTruncated: Bool
    private let preview: String

    @State private var showFull = false

    init(content: String) {
        self.content = content
        let lines = content.components(separatedBy: "\n")
        self.lines = lines
        self.isTruncated = lines.count > previewLineCount
        self.preview = lines.prefix(previewLineCount).joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            resultLabel
            styledResultText
        }
    }

    private var resultLabel: some View {
        HStack(spacing: 4) {
            resultTitleText
            toggleButtonIfTruncated
        }
    }

    private var resultTitleText: some View {
        Text("Result")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var toggleButtonIfTruncated: some View {
        if isTruncated { toggleButton }
    }

    private var toggleButton: some View {
        Button { showFull.toggle() } label: {
            toggleButtonText
        }
        .buttonStyle(.plain)
    }

    private var toggleButtonText: some View {
        Text(showFull ? "collapse" : "\(lines.count) lines")
            .font(.system(size: 9))
            .foregroundStyle(.blue.opacity(0.7))
    }

    private var displayedText: String {
        showFull || !isTruncated ? content : preview + "\n..."
    }

    private var styledResultText: some View {
        Text(displayedText)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview("Short result") {
    ToolResultView(content: "Result line one\nResult line two")
        .padding()
}

#Preview("Long result (truncated)") {
    ToolResultView(content: (1...40).map { "Line \($0)" }.joined(separator: "\n"))
        .padding()
}
