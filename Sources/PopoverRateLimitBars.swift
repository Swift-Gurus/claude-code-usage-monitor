import SwiftUI

/// 5-hour + weekly rate-limit usage rows, when either window has usage data.
struct PopoverRateLimitBars: View {
    let rateLimits: RateLimits

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            rowIfAvailable(RateLimitRowDisplay(window: rateLimits.fiveHour, label: "5h window"))
            rowIfAvailable(RateLimitRowDisplay(window: rateLimits.sevenDay, label: "Weekly"))
        }
    }

    @ViewBuilder
    private func rowIfAvailable(_ display: RateLimitRowDisplay?) -> some View {
        if let display {
            PopoverRateLimitRow(label: display.label, percent: display.percent, resetsInLabel: display.resetsInLabel)
        }
    }
}

#Preview {
    PopoverRateLimitBars(rateLimits: RateLimits(
        fiveHour: RateLimitWindow(usedPercentage: 62, resetsAt: nil),
        sevenDay: RateLimitWindow(usedPercentage: 30, resetsAt: nil)
    ))
}
