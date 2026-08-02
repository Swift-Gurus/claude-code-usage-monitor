import SwiftUI

/// One rate-limit window's usage bar with percent and reset countdown, reusing
/// ContextProgressBar for the bar/percent rendering.
struct PopoverRateLimitRow: View {
    let label: String
    let percent: Double
    /// Fully-formatted trailing label, e.g. "· resets in 2h" — empty if no reset info.
    let resetsInLabel: String

    var body: some View {
        HStack(spacing: 6) {
            windowLabel
            ContextProgressBar(contextPercent: Int(percent.rounded()), label: resetsInLabel, barHeight: 8)
        }
    }

    private var windowLabel: some View {
        Text(label).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: 60, alignment: .leading)
    }
}

#Preview {
    PopoverRateLimitRow(label: "5h window", percent: 62, resetsInLabel: "· resets in 2h")
}
