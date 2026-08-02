/// Contract for anything exposing Today/Week/Month period stats — both UsageData
/// (account-wide) and AccountPeriodStats (per-account) already have this shape.
protocol PeriodStatsProviding {
    var day: PeriodStats { get }
    var week: PeriodStats { get }
    var month: PeriodStats { get }
}

extension UsageData: PeriodStatsProviding {}
extension AccountPeriodStats: PeriodStatsProviding {}
