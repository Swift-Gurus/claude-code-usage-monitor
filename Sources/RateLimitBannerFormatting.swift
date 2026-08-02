import Foundation

/// Pure derived display values for a rate-limit warning banner.
struct RateLimitBannerFormatting {
    let event: RateLimitEvent
    let durationFormatter: DurationFormatting
    let now: Date

    var elapsed: TimeInterval { now.timeIntervalSince(event.timestamp) }
    var isRecent: Bool { elapsed < 3600 }
    var hitTime: String { Self.timeFormatter.string(from: event.timestamp) }

    var resetText: String? {
        if let resetsAt = event.resetsAt, resetsAt > 0 {
            let remaining = resetsAt - now.timeIntervalSince1970
            return remaining > 0 ? "Resets in \(durationFormatter.format(remaining))" : nil
        }
        let remaining = 18_000 - elapsed
        return remaining > 0 ? "Resets in ~\(durationFormatter.format(remaining))" : nil
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
