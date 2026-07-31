import Foundation

/**
 solid-name: StopHookSummaryHandling
 solid-category: abstraction
 solid-description: Contract for processing nested tool completion summaries and integrating them into a message stream.
 */
protocol StopHookSummaryHandling {
    func handle(raw: [String: Any], timestamp: Date?, result: inout [LogMessage], hookAttacher: inout HookAttaching)
}

/**
 solid-name: StopHookSummaryHandler
 solid-category: service
 solid-description: Service that processes nested tool completion summaries and integrates them into a message stream.
 */
struct StopHookSummaryHandler: StopHookSummaryHandling {
    private let constructor: HookMessageConstructing

    init(constructor: HookMessageConstructing = HookMessageConstructor()) {
        self.constructor = constructor
    }

    func handle(raw: [String: Any], timestamp: Date?, result: inout [LogMessage], hookAttacher: inout HookAttaching) {
        let toolUseID = raw["toolUseID"] as? String ?? ""
        let hookInfos = raw["hookInfos"] as? [[String: Any]] ?? []
        let hookErrors = raw["hookErrors"] as? [String] ?? []
        let uuid = raw["uuid"] as? String

        if let ref = hookAttacher.existingRef(for: toolUseID),
           ref.toolCallIdx < result[ref.messageIdx].toolCalls.count,
           let priorHookData = result[ref.messageIdx].toolCalls[ref.toolCallIdx].data.hookData {
            result[ref.messageIdx] = constructor.enrichedMessage(
                from: result[ref.messageIdx], priorHookData: priorHookData,
                hookInfos: hookInfos, hookErrors: hookErrors, uuid: uuid, hookAttacher: hookAttacher
            )
            return
        }

        guard !hookInfos.isEmpty else { return }
        result.append(constructor.standaloneMessage(
            toolUseID: toolUseID, hookInfos: hookInfos, hookErrors: hookErrors,
            uuid: uuid, resultIndex: result.count, timestamp: timestamp
        ))
    }
}
