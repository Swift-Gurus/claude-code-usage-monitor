/**
 solid-name: StatusRowDisplayable
 solid-category: abstraction
 solid-description: Contract for types providing content and status information for display.
 */
protocol StatusRowDisplayable {
    var content: String { get }
    var status: String { get }
}
