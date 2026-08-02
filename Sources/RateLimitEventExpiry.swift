import Foundation

/// Whether a rate-limit event is stale enough to stop showing its warning banner.
struct RateLimitEventExpiry {
    let event: RateLimitEvent
    let now: Date

    var isExpired: Bool {
        if let resetsAt = event.resetsAt, resetsAt > 0 {
            return now.timeIntervalSince1970 > resetsAt
        }
        return now.timeIntervalSince(event.timestamp) > 18_000
    }
}
