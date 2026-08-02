import Foundation

/**
 solid-name: DurationFormatting
 solid-category: abstraction
 solid-description: Contract for formatting a time interval into a duration string.
 */
protocol DurationFormatting {
    func format(_ seconds: TimeInterval) -> String
}

/**
 solid-name: DefaultDurationFormatter
 solid-category: service
 solid-description: Formats a time interval into a duration string.
 */
struct DefaultDurationFormatter: DurationFormatting {
    func format(_ seconds: TimeInterval) -> String {
        Self.formatter.string(from: seconds) ?? "\(Int(seconds / 60))m"
    }

    private static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f
    }()
}
