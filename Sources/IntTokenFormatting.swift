import Foundation

extension Int {
    /// Compact magnitude string for a token count, e.g. "1.2M", "340K", "512".
    var asTokenCountString: String {
        if self >= 1_000_000_000 { return String(format: "%.1fB", Double(self) / 1_000_000_000) }
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
