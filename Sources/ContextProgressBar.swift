import SwiftUI

private enum LayoutTokens {
    static let contextBarHeight: CGFloat = 6
}

/**
 solid-name: ContextProgressBar
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Reusable progress bar displaying context window usage as a colored bar with percentage label. Color thresholds: red at 90%+, yellow at 70%+, green otherwise. Used in popover, subagent row, and subagent detail views.
 */
struct ContextProgressBar: View {
    let contextPercent: Int
    let label: String
    var barHeight: CGFloat = LayoutTokens.contextBarHeight

    private var ctxColor: Color {
        contextPercent >= 90 ? .red : contextPercent >= 70 ? .yellow : .green
    }

    var body: some View {
        HStack(spacing: 8) {
            progressBar
            percentLabel
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(ctxColor.opacity(0.2))
                RoundedRectangle(cornerRadius: 2).fill(ctxColor)
                    .frame(width: geo.size.width * CGFloat(contextPercent) / 100)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
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
