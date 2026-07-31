import SwiftUI

/**
 solid-name: TextBlockView
 solid-category: view-component
 solid-description: Displays selectable text.
 */
struct TextBlockView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .textSelection(.enabled)
    }
}

#Preview {
    TextBlockView(text: "Sample text block")
}
