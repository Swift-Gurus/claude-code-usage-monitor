import SwiftUI

/**
 solid-name: FullDiffView
 solid-category: view-component
 solid-description: Shows the line-by-line differences between old and new file content.
 */
struct FullDiffView: View {
    let filePath: String
    let oldLines: [String]
    let newLines: [String]

    var body: some View {
        content
            .textSelection(.enabled)
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            filePathIfPresent
            DiffLinesList(lines: oldLines, prefix: "-", color: .red)
            DiffLinesList(lines: newLines, prefix: "+", color: .green)
        }
    }

    @ViewBuilder
    private var filePathIfPresent: some View {
        if !filePath.isEmpty {
            FilePathLabel(filePath: filePath)
                .padding(.bottom, 4)
        }
    }
}

#Preview {
    FullDiffView(filePath: "Sample.swift", oldLines: ["old line"], newLines: ["new line"])
        .padding()
}
