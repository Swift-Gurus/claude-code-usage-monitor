/**
 solid-name: ToolUseIndexing
 solid-category: abstraction
 solid-description: Contract for mapping tool use IDs to message indices.
 */
protocol ToolUseIndexing {
    mutating func record(messageIdx: Int, forToolUseID toolUseID: String)
    func messageIndex(forToolUseID toolUseID: String) -> Int?
}

/**
 solid-name: ToolUseIndex
 solid-category: service
 solid-description: Maps tool use IDs to message indices.
 */
struct ToolUseIndex: ToolUseIndexing {
    private var indexByToolUseID: [String: Int] = [:]

    mutating func record(messageIdx: Int, forToolUseID toolUseID: String) {
        indexByToolUseID[toolUseID] = messageIdx
    }

    func messageIndex(forToolUseID toolUseID: String) -> Int? {
        indexByToolUseID[toolUseID]
    }
}
