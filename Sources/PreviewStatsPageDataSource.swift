import Foundation

/// Preview-only mock data source for StatsPageView. Lives at file scope since
/// @Observable cannot attach to a type declared locally inside a #Preview closure.
@Observable
@MainActor
final class PreviewStatsPageDataSource: StatsPageState, StatsPageActions {
    var day = SessionStats(tools: ToolCallStats(countsByName: ["Bash": 3]))
    var week = SessionStats(tools: ToolCallStats(countsByName: ["Bash": 10, "Read": 4]))
    var month = SessionStats(tools: ToolCallStats(countsByName: ["Bash": 40, "Read": 20]))

    func reload() {}
}
