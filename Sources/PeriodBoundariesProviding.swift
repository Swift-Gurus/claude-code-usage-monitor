import Foundation

/**
 solid-name: PeriodBoundariesProviding
 solid-category: abstraction
 solid-description: Contract for computing period boundaries at a specified moment.
 */
protocol PeriodBoundariesProviding {
    func boundaries(now: Date) -> PeriodBoundaries
}

/**
 solid-name: DefaultPeriodBoundariesProvider
 solid-category: service
 solid-description: Computes period boundaries for a given moment.
 */
struct DefaultPeriodBoundariesProvider: PeriodBoundariesProviding {
    func boundaries(now: Date) -> PeriodBoundaries {
        PeriodBoundaries(now: now)
    }
}
