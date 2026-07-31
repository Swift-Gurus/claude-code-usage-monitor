import SwiftUI

/**
 solid-name: DiffContentView
 solid-category: view-component
 solid-description: Displays the differences between two text versions.
 */
struct DiffContentView: View {
    let filePath: String
    let oldText: String
    let newText: String

    var body: some View {
        let lines = DiffLines(oldText: oldText, newText: newText)
        if lines.isLarge {
            CollapsedDiffView(filePath: filePath, oldText: oldText, newText: newText)
        } else {
            FullDiffView(filePath: filePath, oldLines: lines.old, newLines: lines.new)
        }
    }
}

#Preview {
    DiffContentView(filePath: "Sample.swift", oldText: "old line", newText: "new line")
        .padding()
}