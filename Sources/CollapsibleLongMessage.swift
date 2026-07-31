import SwiftUI

/**
 solid-name: CollapsibleLongMessage
 solid-category: view-component
 solid-description: Displays long messages in collapsible format that toggles between truncated and full text.
 */
struct CollapsibleLongMessage: View {
    let fullText: String
    let allTextContent: [String]

    var body: some View {
        ExpandableSection(expanded: false, tintColor: .green.opacity(0.7)) {
            contentView
        } label: {
            labelView
        }
    }

    private var contentView: some View {
        LongMessageTextBlocks(textContent: allTextContent)
    }

    private var labelView: some View {
        TruncatedLabel(fullText: fullText)
    }
}

#Preview {
    CollapsibleLongMessage(fullText: "Sample long text", allTextContent: ["Sample long text"])
}