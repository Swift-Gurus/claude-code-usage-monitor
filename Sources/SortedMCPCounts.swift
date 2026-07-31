/// Flattens a nested `[outerKey: [innerKey: count]]`-shaped structure into labeled
/// counts and sorts by count, descending. Shared by anything that needs to flatten a
/// two-level count breakdown into a single sorted list (currently just MCP server/tool
/// counts, but the flattening step itself is data-shape-agnostic).
func sortedNestedCounts<Value>(
    _ nested: [String: Value],
    counts: (Value) -> [String: Int],
    label: (String, String) -> String
) -> [(label: String, count: Int)] {
    let flattened = nested.flatMap { outerKey, value in
        counts(value).map { innerKey, count in (label: label(outerKey, innerKey), count: count) }
    }
    return sortedByCountDescending(flattened)
}

/// Flattened, sorted "server · tool" call counts, descending by count.
struct SortedMCPCounts {
    let byServer: [String: MCPCallStats.ServerStats]

    var entries: [(label: String, count: Int)] {
        sortedNestedCounts(byServer, counts: \.countsByTool, label: { "\($0) · \($1)" })
    }
}
