import SwiftUI

/**
 solid-name: CollapsedDiffView
 solid-category: view-component
 solid-description: Displays file modifications in compact form with the file path.
 */
struct CollapsedDiffView: View {
    let filePath: String
    let oldText: String
    let newText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            filePathIfPresent
            oldTextIfPresent
            newTextIfPresent
        }
    }

    @ViewBuilder
    private var filePathIfPresent: some View {
        if !filePath.isEmpty {
            FilePathLabel(filePath: filePath)
        }
    }

    @ViewBuilder
    private var oldTextIfPresent: some View {
        if !oldText.isEmpty { ToolResultView(content: oldText) }
    }

    @ViewBuilder
    private var newTextIfPresent: some View {
        if !newText.isEmpty { ToolResultView(content: newText) }
    }
}

#Preview {
    CollapsedDiffView(filePath: "Sample.swift", oldText: "old", newText: "new")
}
