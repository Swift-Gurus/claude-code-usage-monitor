import SwiftUI

/// Pure rendering of a rate-limit banner from already-formatted display values.
struct RateLimitBannerContent: View {
    let isRecent: Bool
    let hitTime: String
    let resetText: String?

    var body: some View {
        HStack(spacing: 6) {
            RateLimitBannerIcon(isRecent: isRecent)
            RateLimitBannerText(isRecent: isRecent, hitTime: hitTime, resetText: resetText)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rateLimitBannerColor(isRecent: isRecent).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    RateLimitBannerContent(isRecent: true, hitTime: "12:48 PM", resetText: "Resets in 2h 15m")
}
