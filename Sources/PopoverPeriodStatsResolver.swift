import Foundation

/// Resolves the PeriodStats for a "Today"/"Week"/"Month" label, scoped to a single
/// filtered account when one is selected, otherwise across all accounts.
struct PopoverPeriodStatsResolver {
    let data: UsageData
    let filterAccountID: UUID?

    func stats(for label: String) -> PeriodStats {
        if let filterAccountID, let account = data.byAccount[filterAccountID] {
            return periodStats(from: account, label: label)
        }
        return periodStats(from: data, label: label)
    }

    private func periodStats(from source: PeriodStatsProviding, label: String) -> PeriodStats {
        switch label {
        case "Today": return source.day
        case "Week": return source.week
        case "Month": return source.month
        default: return source.day
        }
    }
}
