public struct HookToolData {
    public let hookEvent: String       // "PreToolUse", "PostToolUse", "Stop", "SubagentStart", ...
    public let hookName: String        // "PostToolUse:Grep", "Stop", "SubagentStart", ...
    public let command: String         // shell command (hook_progress / stop_hook_summary)
    public let toolUseID: String
    public let durationMs: Int?
    public let errorMessage: String?
    public let context: String?        // injected content for hook_additional_context / hook_system_message
    public let stdout: String?
    public let stderr: String?
    public let exitCode: Int?
    public let status: HookStatus?
}
