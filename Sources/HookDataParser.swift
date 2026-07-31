/**
 solid-name: HookDataParsing
 solid-category: abstraction
 solid-description: Contract for decoding hook attachment payloads into HookToolData.
 */
protocol HookDataParsing {
    func parse(attType: String, att: [String: Any]) -> HookToolData?
}

/**
 solid-name: HookDataParser
 solid-category: service
 solid-description: Decodes hook attachment dictionaries into HookToolData, returning nil for unrecognized types.
 */
struct HookDataParser: HookDataParsing {
    func parse(attType: String, att: [String: Any]) -> HookToolData? {
        let hookEvent = att["hookEvent"] as? String ?? ""
        let hookName = att["hookName"] as? String ?? hookEvent
        let toolUseID = att["toolUseID"] as? String ?? ""

        let status: HookStatus
        let command: String
        let errorMessage: String?
        let context: String?
        let stdout: String?
        let stderr: String?
        let exitCode: Int?
        let durationMs: Int?

        switch attType {
        case "hook_success":
            status = .success
            command = att["command"] as? String ?? ""
            let out = att["stdout"] as? String
            let errOut = att["stderr"] as? String
            stdout = (out?.isEmpty ?? true) ? nil : out
            stderr = (errOut?.isEmpty ?? true) ? nil : errOut
            exitCode = att["exitCode"] as? Int
            durationMs = att["durationMs"] as? Int
            errorMessage = nil
            let content = att["content"] as? String
            context = (content?.isEmpty ?? true) ? nil : content
        case "hook_blocking_error":
            status = .blockingError
            let be = att["blockingError"] as? [String: Any] ?? [:]
            command = be["command"] as? String ?? att["command"] as? String ?? ""
            errorMessage = be["blockingError"] as? String
            stdout = nil
            stderr = nil
            exitCode = be["exitCode"] as? Int
            durationMs = att["durationMs"] as? Int
            context = nil
        case "hook_system_message":
            status = .systemMessage
            command = att["command"] as? String ?? ""
            let content = att["content"] as? String
            context = (content?.isEmpty ?? true) ? nil : content
            stdout = nil
            stderr = nil
            exitCode = nil
            durationMs = nil
            errorMessage = nil
        case "hook_cancelled":
            status = .cancelled
            command = att["command"] as? String ?? ""
            errorMessage = "Cancelled"
            context = nil
            stdout = nil
            stderr = nil
            exitCode = nil
            durationMs = att["durationMs"] as? Int
        default:
            return nil
        }

        return HookToolData(
            hookEvent: hookEvent, hookName: hookName,
            command: command, toolUseID: toolUseID,
            durationMs: durationMs, errorMessage: errorMessage,
            context: context,
            stdout: stdout, stderr: stderr, exitCode: exitCode,
            status: status
        )
    }
}
