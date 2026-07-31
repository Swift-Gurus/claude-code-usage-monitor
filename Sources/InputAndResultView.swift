import SwiftUI

/**
 solid-name: InputAndResultView
 solid-category: view-component
 solid-description: Displays input paired with an optional result output.
 */
struct InputAndResultView: View {
    let input: String
    let resultContent: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonoTextView(text: input)
            resultIfPresent
        }
    }

    @ViewBuilder
    private var resultIfPresent: some View {
        if let result = resultContent, !result.isEmpty {
            ToolResultView(content: result)
        }
    }
}

#Preview {
    InputAndResultView(input: "ls -la", resultContent: "file1\nfile2")
        .padding()
}
