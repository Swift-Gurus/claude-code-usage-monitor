import SwiftUI

/**
 solid-name: ToolDetailContent
 solid-category: view-component
 solid-description: Displays expanded details for a tool based on its operation type.
 */
struct ToolDetailContent: View {
    let data: ToolData
    let resultContent: String?

    var body: some View {
        FileOperationDetailContent(data: data, resultContent: resultContent)
        GeneralToolDetailContent(data: data, resultContent: resultContent)
    }
}

#Preview {
    ToolDetailContent(data: .bash(BashToolData(command: "ls -la", description: "", timeout: nil)), resultContent: "file1\nfile2")
        .padding()
}
