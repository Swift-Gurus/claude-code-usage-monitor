/// Sorts labeled counts by count, descending. Shared by anything that flattens a
/// tool/server breakdown into a single sorted list, so no call site repeats the
/// dict-to-tuples-to-sort pipeline.
func sortedByCountDescending(_ entries: [(label: String, count: Int)]) -> [(label: String, count: Int)] {
    entries.sorted { $0.count > $1.count }
}

/// Convenience overload for a flat `[name: count]` breakdown (e.g. built-in tool calls).
func sortedByCountDescending(_ counts: [String: Int]) -> [(label: String, count: Int)] {
    sortedByCountDescending(counts.map { (label: $0.key, count: $0.value) })
}
