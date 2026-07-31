import SwiftUI

/**
 solid-name: StatusDot
 solid-category: view-component
 solid-description: Displays a visual status indicator.
 */
struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle().fill(color)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusDot(color: .green).frame(width: 6, height: 6)
        StatusDot(color: .blue).frame(width: 6, height: 6)
        StatusDot(color: .orange).frame(width: 6, height: 6)
        StatusDot(color: .gray).frame(width: 6, height: 6)
    }
    .padding()
}
