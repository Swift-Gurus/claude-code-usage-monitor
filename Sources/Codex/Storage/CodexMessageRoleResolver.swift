import Foundation

/**
 solid-name: CodexMessageRoleResolver
 solid-category: service
 solid-description: Resolves Codex payload roles and hook prompts into log-message roles.
 */
struct CodexMessageRoleResolver: CodexMessageRoleResolving {
    func role(rawRole: String?, textContent: [String]) -> LogMessage.Role {
        switch rawRole {
        case "assistant":
            return .assistant
        case "developer":
            return .system
        default:
            let containsHookPrompt = textContent.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<hook_prompt")
            }
            return containsHookPrompt ? .system : .user
        }
    }
}
