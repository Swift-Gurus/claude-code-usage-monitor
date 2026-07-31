import Foundation

/**
 solid-name: HookLineHandling
 solid-category: abstraction
 solid-description: Contract for processing hook-shaped log lines and indicating whether they were successfully handled.
 */
protocol HookLineHandling {
    mutating func handle(type: String, raw: [String: Any], timestamp: Date?, result: inout [LogMessage], assistantIdxByToolUseID: ToolUseIndexing) -> Bool
}

/**
 solid-name: HookLineHandler
 solid-category: service
 solid-description: Orchestrates the handling of hook-shaped log lines.
 */
struct HookLineHandler: HookLineHandling {
    private let recognizer: HookLineRecognizing
    private let hookChipBuilder: HookChipBuilding
    private let hookDataParser: HookDataParsing
    private let hookCallFactory: HookCallFactoring
    private let stopHookSummaryHandler: StopHookSummaryHandling
    private var hookAttacher: HookAttaching

    init(
        recognizer: HookLineRecognizing = HookLineRecognizer(),
        hookChipBuilder: HookChipBuilding = HookChipBuilder(),
        hookDataParser: HookDataParsing = HookDataParser(),
        hookCallFactory: HookCallFactoring = HookCallFactory(),
        stopHookSummaryHandler: StopHookSummaryHandling = StopHookSummaryHandler(),
        hookAttacher: HookAttaching = HookAttacher()
    ) {
        self.recognizer = recognizer
        self.hookChipBuilder = hookChipBuilder
        self.hookDataParser = hookDataParser
        self.hookCallFactory = hookCallFactory
        self.stopHookSummaryHandler = stopHookSummaryHandler
        self.hookAttacher = hookAttacher
    }

    mutating func handle(type: String, raw: [String: Any], timestamp: Date?, result: inout [LogMessage], assistantIdxByToolUseID: ToolUseIndexing) -> Bool {
        guard let kind = recognizer.recognize(type: type, raw: raw) else { return false }

        switch kind {
        case .progress:
            let hookData = hookChipBuilder.progressHookData(from: raw)
            attach(hookData, uuid: raw["uuid"] as? String, into: &result, assistantIdxByToolUseID: assistantIdxByToolUseID, timestamp: timestamp)
        case .stopHookSummary:
            stopHookSummaryHandler.handle(raw: raw, timestamp: timestamp, result: &result, hookAttacher: &hookAttacher)
        case .additionalContext:
            let att = raw["attachment"] as? [String: Any] ?? [:]
            let hookData = hookChipBuilder.additionalContextHookData(from: att)
            attach(hookData, uuid: raw["uuid"] as? String, into: &result, assistantIdxByToolUseID: assistantIdxByToolUseID, timestamp: timestamp)
        case .attachment(let attType, let att):
            if let hookData = hookDataParser.parse(attType: attType, att: att) {
                attach(hookData, uuid: raw["uuid"] as? String, into: &result, assistantIdxByToolUseID: assistantIdxByToolUseID, timestamp: timestamp)
            }
        }
        return true
    }

    private mutating func attach(
        _ hookData: HookToolData, uuid: String?, into result: inout [LogMessage],
        assistantIdxByToolUseID: ToolUseIndexing, timestamp: Date?
    ) {
        let hookCall = hookCallFactory.make(hookData, uuid: uuid, suffix: "")
        hookAttacher.attach(hookCall, toolUseID: hookData.toolUseID, timestamp: timestamp, into: &result, assistantIdxByToolUseID: assistantIdxByToolUseID)
    }
}
