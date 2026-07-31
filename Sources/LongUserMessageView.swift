import SwiftUI

/**
 solid-name: LongUserMessageView
 solid-category: view-component
 solid-description: Displays long user messages with full-content expansion capability.
 */
struct LongUserMessageView: View {
    let fullText: String
    let allTextContent: [String]

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var content: some View {
        CollapsibleLongMessage(fullText: fullText, allTextContent: allTextContent)
    }
}

#Preview {
    LongUserMessageView(
        fullText: String(repeating: "This is a long message. ", count: 20),
        allTextContent: [String(repeating: "This is a long message. ", count: 20)]
    )
    .padding()
}
