import SwiftUI

private enum LayoutTokens {
    static let contextBarHeight: CGFloat = 6
}

/**
 solid-name: ContextProgressBar
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Displays context window usage percentage.
 */
struct ContextProgressBar: View {
    let contextPercent: Int
    let label: String
    var barHeight: CGFloat = LayoutTokens.contextBarHeight
    /// Bar width — the caller decides based on its own layout context. `nil` fills
    /// whatever width the parent offers (the previous unconditional behavior).
    var barWidth: CGFloat?

    private var ctxColor: Color {
        contextPercent >= 90 ? .red : contextPercent >= 70 ? .yellow : .green
    }

    var body: some View {
        HStack(spacing: 8) {
            FilledProgressBar(percent: contextPercent, color: ctxColor, height: barHeight, width: barWidth)
            percentLabel
        }
    }

    private var percentLabel: some View {
        Text("\(contextPercent)%\(label.isEmpty ? "" : " \(label)")")
            .font(.caption2).foregroundStyle(ctxColor)
    }
}

#Preview("Low context") {
    ContextProgressBar(contextPercent: 30, label: "of 200K")
        .padding()
}

#Preview("Medium context") {
    ContextProgressBar(contextPercent: 75, label: "of 200K")
        .padding()
}

#Preview("High context") {
    ContextProgressBar(contextPercent: 95, label: "of 200K")
        .padding()
}
