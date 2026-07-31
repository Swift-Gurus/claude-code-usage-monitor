import SwiftUI

/**
 solid-name: TextBlocksContent
 solid-category: view-component
 solid-description: Displays a sequence of text blocks.
 */
struct TextBlocksContent: View {
    let textContent: [String]

    var body: some View {
        ForEach(Array(textContent.enumerated()), id: \.offset) { _, text in
            TextBlockView(text: text)
        }
    }
}

#Preview {
    TextBlocksContent(textContent: ["First block", "Second block"])
}
