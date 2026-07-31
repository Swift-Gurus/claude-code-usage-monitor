import SwiftUI

/**
 solid-name: FileOperationDetailContent
 solid-category: view-component
 solid-description: Displays tool execution details and results with formatting appropriate to the operation type.
 */
struct FileOperationDetailContent: View {
    let data: ToolData
    let resultContent: String?

    var body: some View {
        fileEditView
        bashView
        searchView
    }

    @ViewBuilder
    private var fileEditView: some View {
        switch data {
        case .edit(let d): DiffContentView(filePath: d.filePath, oldText: d.oldString, newText: d.newString)
        case .write(let d): DiffContentView(filePath: d.filePath, oldText: "", newText: d.content)
        case .read(let d): InputAndResultView(input: d.filePath + (d.lineRange.map { " (\($0))" } ?? ""), resultContent: resultContent)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var bashView: some View {
        if case .bash(let d) = data {
            InputAndResultView(input: d.command + (d.timeout.map { " (timeout: \($0 / 1000)s)" } ?? ""), resultContent: resultContent)
        }
    }

    @ViewBuilder
    private var searchView: some View {
        switch data {
        case .grep(let d): GrepGlobDetailView(pattern: d.pattern, path: d.path, resultContent: resultContent)
        case .glob(let d): GrepGlobDetailView(pattern: d.pattern, path: d.path, resultContent: resultContent)
        default: EmptyView()
        }
    }
}

#Preview {
    FileOperationDetailContent(data: .bash(BashToolData(command: "ls -la", description: "", timeout: nil)), resultContent: "file1\nfile2")
        .padding()
}