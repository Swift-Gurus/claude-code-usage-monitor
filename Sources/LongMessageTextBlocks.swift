import SwiftUI

/**
 solid-name: LongMessageTextBlocks
 solid-category: view-component
 solid-description: Displays text blocks in a styled container.
 */
struct LongMessageTextBlocks: View {
    let textContent: [String]

    var body: some View {
        stack
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextBlocksContent(textContent: textContent)
        }
    }
}

#Preview {
    LongMessageTextBlocks(textContent: ["First block", "Second block"])
}