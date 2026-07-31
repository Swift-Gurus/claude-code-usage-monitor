import SwiftUI

/**
 solid-name: SummaryTextView
 solid-category: view-component
 solid-description: Displays text in summary format.
 */
struct SummaryTextView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

#Preview {
    SummaryTextView(text: "Sample summary text")
}