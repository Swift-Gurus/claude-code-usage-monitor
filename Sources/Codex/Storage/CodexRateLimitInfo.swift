import Foundation

/**
 solid-name: CodexRateLimitInfo
 solid-category: model
 solid-description: Represents the primary and secondary usage limits reported for a Codex session.
 */
struct CodexRateLimitInfo: Decodable {
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
}
