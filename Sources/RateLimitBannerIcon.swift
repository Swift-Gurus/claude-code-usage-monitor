import SwiftUI

/// Warning icon for a rate-limit banner.
struct RateLimitBannerIcon: View {
    let isRecent: Bool

    var body: some View {
        Image(systemName: isRecent ? "exclamationmark.octagon.fill" : "clock.badge.exclamationmark")
            .foregroundStyle(rateLimitBannerColor(isRecent: isRecent))
            .font(.caption)
    }
}

#Preview {
    RateLimitBannerIcon(isRecent: true)
}
