/// Pure derived display values for the plan usage tokens card.
struct PopoverPlanUsageTokensDisplay {
    let stats: StatsCache

    var avgMessagesPerDay: Double { stats.monthlyAvgMessages() }
    var totalOutputTokens: Int { stats.monthlyDailyTokens().values.reduce(0, +) }
    var totalSessions: Int { stats.totalSessions }
    var sortedModelUsage: [StatsCache.ModelUsage] { stats.modelUsage.sorted { $0.outputTokens > $1.outputTokens } }
}
