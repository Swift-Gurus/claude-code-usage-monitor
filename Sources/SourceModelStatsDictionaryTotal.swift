extension Dictionary where Value == SourceModelStats {
    /// Sums cost/lines-added/lines-removed across all values.
    var totalStats: SourceModelStats {
        SourceModelStats(
            cost: values.reduce(0.0) { $0 + $1.cost },
            linesAdded: values.reduce(0) { $0 + $1.linesAdded },
            linesRemoved: values.reduce(0) { $0 + $1.linesRemoved }
        )
    }

    /// Entries sorted by cost, descending.
    var sortedByDescendingCost: [(key: Key, value: SourceModelStats)] {
        sorted { $0.value.cost > $1.value.cost }
    }
}
