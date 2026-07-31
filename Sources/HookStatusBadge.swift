import SwiftUI

/**
 solid-name: HookStatusBadge
 solid-category: view-component
 solid-description: Renders a label styled as a colored badge.
 */
struct HookStatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 2))
    }
}

#Preview {
    HookStatusBadge(label: "DONE", color: .orange)
}
