import SwiftUI

/**
 solid-name: DiffLineRow
 solid-category: view-component
 solid-description: Displays a styled text line with a prefix and customizable color.
 */
struct DiffLineRow: View {
    let text: String
    let prefix: String
    let color: Color

    var body: some View {
        styledDiffText
    }

    private var styledDiffText: some View {
        Text("\(prefix) \(text)")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(color.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
    }
}

#Preview {
    DiffLineRow(text: "sample line", prefix: "+", color: .green)
}