import SwiftUI

/**
 solid-name: EnumeratedListContent
 solid-category: view-component
 solid-description: Renders each item in a collection using a provided view template.
 */
struct EnumeratedListContent<Item, RowContent: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> RowContent

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            row(item)
        }
    }
}

#Preview {
    EnumeratedListContent(items: ["One", "Two"]) { Text($0) }
}
