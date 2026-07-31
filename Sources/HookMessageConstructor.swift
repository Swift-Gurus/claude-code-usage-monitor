import Foundation

/**
 solid-name: HookMessageConstructing
 solid-category: abstraction
 solid-description: Contract for constructing LogMessage objects from hook information.
 */
protocol HookMessageConstructing {
    func enrichedMessage(
        from message: LogMessage, priorHookData: HookToolData,
        hookInfos: [[String: Any]], hookErrors: [String], uuid: String?, hookAttacher: HookAttaching
    ) -> LogMessage

    func standaloneMessage(
        toolUseID: String, hookInfos: [[String: Any]], hookErrors: [String],
        uuid: String?, resultIndex: Int, timestamp: Date?
    ) -> LogMessage
}

/**
 solid-name: HookMessageConstructor
 solid-category: service
 solid-description: Constructs LogMessage objects from hook information in two forms.
 */
struct HookMessageConstructor: HookMessageConstructing {
    private let hookChipBuilder: HookChipBuilding
    private let hookCallFactory: HookCallFactoring
    private let messageFactory: MessageFactory

    init(
        hookChipBuilder: HookChipBuilding = HookChipBuilder(),
        hookCallFactory: HookCallFactoring = HookCallFactory(),
        messageFactory: MessageFactory = DefaultMessageFactory()
    ) {
        self.hookChipBuilder = hookChipBuilder
        self.hookCallFactory = hookCallFactory
        self.messageFactory = messageFactory
    }

    func enrichedMessage(
        from message: LogMessage, priorHookData: HookToolData,
        hookInfos: [[String: Any]], hookErrors: [String], uuid: String?, hookAttacher: HookAttaching
    ) -> LogMessage {
        let completion = hookChipBuilder.completionHookData(from: priorHookData, hookInfos: hookInfos, hookErrors: hookErrors)
        let completionCall = hookCallFactory.make(completion, uuid: uuid, suffix: "-complete")
        return hookAttacher.appendingToolCall(completionCall, to: message)
    }

    func standaloneMessage(
        toolUseID: String, hookInfos: [[String: Any]], hookErrors: [String],
        uuid: String?, resultIndex: Int, timestamp: Date?
    ) -> LogMessage {
        let baseUUID = uuid ?? UUID().uuidString
        let calls = hookChipBuilder.stopHookDataList(toolUseID: toolUseID, hookInfos: hookInfos, hookErrors: hookErrors)
            .enumerated()
            .map { i, hookData in LogToolCall(id: "hook-\(baseUUID)-\(i)", name: "Hook", data: .hook(hookData)) }
        return messageFactory.makeSystemMessage(id: "system-\(resultIndex)", timestamp: timestamp, toolCalls: calls)
    }
}
