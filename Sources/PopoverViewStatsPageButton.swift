import SwiftUI

/// Entry point from the cost breakdown screen into the Stats page.
struct PopoverViewStatsPageButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        HStack(spacing: 6) {
            icon
            label
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: some View {
        Image(systemName: "chart.bar.fill").foregroundStyle(.blue)
    }

    private var label: some View {
        Text("View Tool & Token Stats").font(.caption).fontWeight(.medium)
    }
}

#Preview {
    PopoverViewStatsPageButton(action: {})
}
