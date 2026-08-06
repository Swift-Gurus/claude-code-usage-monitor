import Foundation

/**
 solid-name: CodexRolloutPayload
 solid-category: model
 solid-description: Represents conversational, tool, status, and usage information carried by a Codex rollout event.
 */
struct CodexRolloutPayload: Decodable {
    let source: String?
    let cwd: String?
    let model: String?
    let title: String?
    let timestamp: String?
    let type: String?
    let role: String?
    let phase: String?
    let status: String?
    let info: CodexTokenInfo?
    let rateLimits: CodexRateLimitInfo?
    let content: [CodexMessageContent]?
    let summary: [CodexMessageContent]?
    let text: String?
    let message: String?
    let name: String?
    let namespace: String?
    let arguments: String?
    let input: String?
    let callID: String?
    let output: CodexTextContent?
    let stdout: String?
    let stderr: String?
    let aggregatedOutput: String?
    let success: Bool?
    let invocation: CodexMCPInvocation?
    let duration: CodexEventDuration?
    let result: CodexMCPResultEnvelope?

    private enum CodingKeys: String, CodingKey {
        case source
        case cwd
        case model
        case title
        case timestamp
        case type
        case role
        case phase
        case status
        case info
        case rateLimits = "rate_limits"
        case content
        case summary
        case text
        case message
        case name
        case namespace
        case arguments
        case input
        case callID = "call_id"
        case output
        case stdout
        case stderr
        case aggregatedOutput = "aggregated_output"
        case success
        case invocation
        case duration
        case result
    }
}
