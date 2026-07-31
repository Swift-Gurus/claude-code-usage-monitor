import SwiftUI

/**
 solid-name: OtherToolDetailView
 solid-category: view-component
 solid-description: Fallback detail view for unrecognized tool calls.
 */
struct OtherToolDetailView: View {
    let raw: [String: String]
    let resultContent: String?

    var body: some View {
        InputAndResultView(input: raw.formattedKeyValuePairs(), resultContent: resultContent)
    }
}

#Preview {
    OtherToolDetailView(raw: ["foo": "bar"], resultContent: nil)
        .padding()
}
