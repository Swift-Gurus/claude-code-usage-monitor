import SwiftUI

/// Shared color rule for rate-limit banner elements: red when the hit is recent, orange otherwise.
func rateLimitBannerColor(isRecent: Bool) -> Color {
    isRecent ? .red : .orange
}
