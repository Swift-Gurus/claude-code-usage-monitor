import Foundation

/// Loads the most recent rate-limit event recorded for an account's `.claude` directory.
protocol RateLimitEventLoading {
    func lastEvent(claudeDir: String) -> RateLimitEvent?
}

struct DefaultRateLimitEventLoader: RateLimitEventLoading {
    func lastEvent(claudeDir: String) -> RateLimitEvent? {
        RateLimitScanner.lastRateLimitEvent(claudeDir: claudeDir)
    }
}
