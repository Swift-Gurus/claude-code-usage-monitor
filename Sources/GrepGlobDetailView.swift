import SwiftUI

/**
 solid-name: GrepGlobDetailView
 solid-category: view-component
 solid-description: Displays input parameters alongside their execution results.
 */
struct GrepGlobDetailView: View {
    let pattern: String
    let path: String
    let resultContent: String?

    var body: some View {
        InputAndResultView(
            input: "pattern: \(pattern)" + (path.isEmpty ? "" : "\npath: \(path)"),
            resultContent: resultContent
        )
    }
}

#Preview {
    GrepGlobDetailView(pattern: "func test", path: "Sources/", resultContent: nil)
        .padding()
}
