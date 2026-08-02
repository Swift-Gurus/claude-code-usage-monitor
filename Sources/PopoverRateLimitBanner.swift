import SwiftUI

/// Warning banner for a recent (or still-cooling-down) rate-limit hit.
struct PopoverRateLimitBanner: View {
    let event: RateLimitEvent
    var durationFormatter: DurationFormatting = DefaultDurationFormatter()

    private var formatting: RateLimitBannerFormatting {
        RateLimitBannerFormatting(event: event, durationFormatter: durationFormatter, now: Date())
    }

    var body: some View {
        RateLimitBannerContent(isRecent: formatting.isRecent, hitTime: formatting.hitTime, resetText: formatting.resetText)
    }
}

#Preview {
    PopoverRateLimitBanner(event: RateLimitEvent(timestamp: Date(), message: "You've hit your limit", sessionID: "preview", resetsAt: nil))
}
