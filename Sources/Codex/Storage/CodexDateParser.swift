import Foundation

struct CodexDateParser {
    private let preciseFormatter: ISO8601DateFormatter
    private let fallbackFormatter: ISO8601DateFormatter

    init() {
        let preciseFormatter = ISO8601DateFormatter()
        preciseFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.preciseFormatter = preciseFormatter
        self.fallbackFormatter = ISO8601DateFormatter()
    }

    func parse(_ raw: String) -> Date? {
        preciseFormatter.date(from: raw) ?? fallbackFormatter.date(from: raw)
    }
}
