import SwiftUI

/**
 solid-name: OptionTextColumn
 solid-category: view-component
 solid-description: Displays a label with optional description text for question options.
 */
struct OptionTextColumn: View {
    let label: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            labelText
            descriptionIfPresent
        }
    }

    private var labelText: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var descriptionIfPresent: some View {
        if !description.isEmpty { descriptionText }
    }

    private var descriptionText: some View {
        Text(description)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
}

#Preview {
    OptionTextColumn(label: "Yes", description: "Confirm the action")
}