/// Represents the user's response to an interactive prompt, extracted from `toolUseResult`.
public enum ToolResponse {
    /// User answered questions: maps question text → selected answer
    case answered([String: String])
    /// User approved (e.g. ExitPlanMode)
    case approved
    /// User rejected/clarified with feedback
    case rejected(feedback: String)
}
