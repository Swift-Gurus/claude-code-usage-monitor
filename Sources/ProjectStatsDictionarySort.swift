extension Dictionary where Value == ProjectStats {
    /// Entries sorted by combined (main + subagents) cost, descending.
    var sortedByDescendingCost: [(key: Key, value: ProjectStats)] {
        sorted { $0.value.total.cost > $1.value.total.cost }
    }
}
