import SwiftUI

/**
 solid-name: TruncatedLabel
 solid-category: view-component
 solid-description: Displays text content in compact form.
 */
struct TruncatedLabel: View {
    let fullText: String

    var body: some View {
        Text(TruncatedFirstLine(of: fullText).value)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

#Preview {
    TruncatedLabel(fullText: "Sample long text that gets truncated in preview")
}