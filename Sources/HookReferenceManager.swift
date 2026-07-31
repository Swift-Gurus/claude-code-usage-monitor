/**
 solid-name: HookReferenceTracking
 solid-category: abstraction
 solid-description: Contract that defines storage and retrieval of hook attachment references indexed by tool use identifier.
 */
protocol HookReferenceTracking {
    mutating func setRef(_ ref: (messageIdx: Int, toolCallIdx: Int), for toolUseID: String)
    func ref(for toolUseID: String) -> (messageIdx: Int, toolCallIdx: Int)?
}

/**
 solid-name: HookReferenceManager
 solid-category: service
 solid-description: Service for storing and retrieving hook attachment references indexed by tool use identifier.
 */
struct HookReferenceManager: HookReferenceTracking {
    private var hookRefByToolUseID: [String: (messageIdx: Int, toolCallIdx: Int)] = [:]

    mutating func setRef(_ ref: (messageIdx: Int, toolCallIdx: Int), for toolUseID: String) {
        hookRefByToolUseID[toolUseID] = ref
    }

    func ref(for toolUseID: String) -> (messageIdx: Int, toolCallIdx: Int)? {
        hookRefByToolUseID[toolUseID]
    }
}
