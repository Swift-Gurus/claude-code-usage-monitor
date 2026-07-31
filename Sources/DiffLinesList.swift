import SwiftUI

/**
 solid-name: DiffLinesList
 solid-category: view-component
 solid-description: Displays styled diff lines with a specified prefix and color.
 */
struct DiffLinesList: View {
    let lines: [String]
    let prefix: String
    let color: Color

    var body: some View {
        if !lines.isEmpty {
            rows
        }
    }

    private var rows: some View {
        EnumeratedListContent(items: lines) { line in
            DiffLineRow(text: line, prefix: prefix, color: color)
        }
    }
}

#Preview {
    DiffLinesList(lines: ["line one", "line two"], prefix: "+", color: .green)
}
