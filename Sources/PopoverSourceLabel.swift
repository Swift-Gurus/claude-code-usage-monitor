import SwiftUI

/// Label text and color for an agent's source (CLI/Commander/Desktop/Codex), rendered
/// via the shared HookStatusBadge component.
struct PopoverSourceLabel: Equatable {
    let source: AgentSource

    var text: String {
        switch source {
        case .cli: return "CLI"
        case .commander: return "Commander"
        case .desktop: return "Desktop"
        case .codex: return "Codex"
        }
    }

    var color: Color {
        switch source {
        case .cli: return .blue
        case .commander: return .secondary
        case .desktop: return .purple
        case .codex: return .teal
        }
    }
}
