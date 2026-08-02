import SwiftUI

/// Rate-limit banner (shown only when the caller has already confirmed the event is
/// still fresh) plus the 5h/weekly usage bars.
struct PopoverPlanUsageCardRateLimitSection: View {
    let freshRateLimitEvent: RateLimitEvent?
    let liveRateLimits: RateLimits?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            bannerIfNeeded
            barsIfNeeded
        }
    }

    @ViewBuilder
    private var bannerIfNeeded: some View {
        if let freshRateLimitEvent {
            PopoverRateLimitBanner(event: freshRateLimitEvent)
        }
    }

    @ViewBuilder
    private var barsIfNeeded: some View {
        if let liveRateLimits {
            PopoverRateLimitBars(rateLimits: liveRateLimits)
        }
    }
}

#Preview {
    PopoverPlanUsageCardRateLimitSection(freshRateLimitEvent: nil, liveRateLimits: nil)
}
