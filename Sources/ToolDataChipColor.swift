import SwiftUI

extension ToolData {
    /// Chip color used in the log viewer, grouped by tool family.
    var chipColor: Color {
        switch self {
        case .bash: return .orange
        case .edit, .write: return .green
        case .read, .grep, .glob: return .blue
        case .agent: return .purple
        case .taskCreate, .taskUpdate, .todoWrite: return .mint
        case .skill, .webSearch, .webFetch: return .indigo
        case .askUserQuestion, .exitPlanMode: return .pink
        case .hook: return .orange
        case .mcp: return .cyan
        case .other: return .secondary
        }
    }
}
