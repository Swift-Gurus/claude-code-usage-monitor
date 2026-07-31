/**
 solid-name: HookChipBuilding
 solid-category: abstraction
 solid-description: Contract for constructing hook tool data from raw event information.
 */
protocol HookChipBuilding {
    func progressHookData(from raw: [String: Any]) -> HookToolData
    func additionalContextHookData(from att: [String: Any]) -> HookToolData
    func completionHookData(from prior: HookToolData, hookInfos: [[String: Any]], hookErrors: [String]) -> HookToolData
    func stopHookDataList(toolUseID: String, hookInfos: [[String: Any]], hookErrors: [String]) -> [HookToolData]
}

/**
 solid-name: HookChipBuilder
 solid-category: service
 solid-description: Constructs hook tool data from raw event information.
 */
struct HookChipBuilder: HookChipBuilding {
    func progressHookData(from raw: [String: Any]) -> HookToolData {
        let data = raw["data"] as? [String: Any] ?? [:]
        return HookToolData(
            hookEvent: data["hookEvent"] as? String ?? "",
            hookName: data["hookName"] as? String ?? "",
            command: data["command"] as? String ?? "",
            toolUseID: raw["toolUseID"] as? String ?? "",
            durationMs: nil, errorMessage: nil, context: nil,
            stdout: nil, stderr: nil, exitCode: nil,
            status: .progress
        )
    }

    func additionalContextHookData(from att: [String: Any]) -> HookToolData {
        let hookEvent = att["hookEvent"] as? String ?? ""
        let hookName = att["hookName"] as? String ?? hookEvent
        let toolUseID = att["toolUseID"] as? String ?? ""
        let joinedContext: String
        if let arr = att["content"] as? [String] {
            joinedContext = arr.joined(separator: "\n")
        } else if let s = att["content"] as? String {
            joinedContext = s
        } else {
            joinedContext = ""
        }
        return HookToolData(
            hookEvent: hookEvent, hookName: hookName,
            command: "", toolUseID: toolUseID,
            durationMs: nil, errorMessage: nil,
            context: joinedContext.isEmpty ? nil : joinedContext,
            stdout: nil, stderr: nil, exitCode: nil,
            status: .systemMessage
        )
    }

    func completionHookData(from prior: HookToolData, hookInfos: [[String: Any]], hookErrors: [String]) -> HookToolData {
        let duration = hookInfos.first?["durationMs"] as? Int
        return HookToolData(
            hookEvent: prior.hookEvent, hookName: prior.hookName,
            command: prior.command, toolUseID: prior.toolUseID,
            durationMs: duration, errorMessage: hookErrors.first,
            context: prior.context,
            stdout: prior.stdout, stderr: prior.stderr, exitCode: prior.exitCode,
            status: hookErrors.first != nil ? .blockingError : .success
        )
    }

    func stopHookDataList(toolUseID: String, hookInfos: [[String: Any]], hookErrors: [String]) -> [HookToolData] {
        hookInfos.enumerated().map { i, info in
            let cmd = info["command"] as? String ?? ""
            let duration = info["durationMs"] as? Int
            let err = i < hookErrors.count ? hookErrors[i] : nil
            return HookToolData(
                hookEvent: "Stop", hookName: "Stop",
                command: cmd, toolUseID: toolUseID,
                durationMs: duration, errorMessage: err,
                context: nil, stdout: nil, stderr: nil, exitCode: nil,
                status: err != nil ? .blockingError : .success
            )
        }
    }
}
