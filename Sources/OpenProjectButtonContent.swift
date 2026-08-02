import SwiftUI

/// Icon + label content for the "Open Project" button.
struct OpenProjectButtonContent: View {
    var body: some View {
        HStack(spacing: 6) {
            icon
            label
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: some View {
        Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
    }

    private var label: some View {
        Text("Open Project").font(.caption).fontWeight(.medium)
    }
}

#Preview {
    OpenProjectButtonContent()
}
