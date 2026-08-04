import Foundation

/**
 solid-name: StatsPageState
 solid-category: abstraction
 solid-description: Contract that defines access to statistics for multiple time periods.
 */
@MainActor
protocol StatsPageState: Observable {
    var day: SessionStats { get }
    var week: SessionStats { get }
    var month: SessionStats { get }
}
