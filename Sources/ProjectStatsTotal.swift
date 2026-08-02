extension ProjectStats {
    /// Combined main + subagent cost/lines for this project.
    var total: SourceModelStats {
        SourceModelStats(
            cost: main.cost + subagents.cost,
            linesAdded: main.linesAdded + subagents.linesAdded,
            linesRemoved: main.linesRemoved + subagents.linesRemoved
        )
    }
}
