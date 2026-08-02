import Foundation

public extension Double {
    /// Formats as USD with 2 decimal places, e.g. "$12.34".
    var asCostString: String {
        String(format: "$%.2f", self)
    }
}
