/// Picks one of three period-scoped values by StatusBarPeriod, so call sites that need
/// day/week/month selection don't each repeat the same switch.
func selectByPeriod<T>(_ period: StatusBarPeriod, day: T, week: T, month: T) -> T {
    switch period {
    case .day: return day
    case .week: return week
    case .month: return month
    }
}
