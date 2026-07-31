import SwiftUI

/**
 solid-name: OptionLabelText
 solid-category: view-component
 solid-description: Displays a label for a question option.
 */
struct OptionLabelText: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    OptionLabelText(label: "Option A")
}
