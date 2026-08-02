import SwiftUI

/// Title + optional reset countdown for a rate-limit banner.
struct RateLimitBannerText: View {
    let isRecent: Bool
    let hitTime: String
    let resetText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            titleText
            resetTextIfNeeded
        }
    }

    private var titleText: some View {
        Text("Rate limit hit at \(hitTime)").font(.caption).fontWeight(.medium).foregroundStyle(rateLimitBannerColor(isRecent: isRecent))
    }

    @ViewBuilder
    private var resetTextIfNeeded: some View {
        if let resetText {
            Text(resetText).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RateLimitBannerText(isRecent: true, hitTime: "12:48 PM", resetText: "Resets in 2h 15m")
}
