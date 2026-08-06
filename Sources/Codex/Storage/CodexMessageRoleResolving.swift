import Foundation

/**
 solid-name: CodexMessageRoleResolving
 solid-category: abstraction
 solid-description: Contract for resolving Codex payload roles and hook prompts into log-message roles.
 */
protocol CodexMessageRoleResolving {
    func role(rawRole: String?, textContent: [String]) -> LogMessage.Role
}
