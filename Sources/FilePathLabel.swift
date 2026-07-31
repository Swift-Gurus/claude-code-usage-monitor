import SwiftUI

/**
 solid-name: FilePathLabel
 solid-category: view-component
 solid-description: Displays a file path string.
 */
struct FilePathLabel: View {
    let filePath: String

    var body: some View {
        Text(filePath)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    FilePathLabel(filePath: "Sources/Sample.swift")
}
