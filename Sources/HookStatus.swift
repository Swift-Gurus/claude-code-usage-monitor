import SwiftUI

public enum HookStatus {
    case progress, success, blockingError, systemMessage, cancelled

    /// Short badge label, or nil for statuses that don't show a badge (systemMessage).
    var badgeLabel: String? {
        switch self {
        case .progress: return "STARTED"
        case .success: return "DONE"
        case .blockingError: return "BLOCKED"
        case .cancelled: return "CANCELLED"
        case .systemMessage: return "SYSTEM"
        }
    }

    /// Badge tint color used in hook detail views.
    var badgeColor: Color {
        switch self {
        case .blockingError: return .red
        case .cancelled: return .gray
        case .progress: return .secondary
        case .success, .systemMessage: return .orange
        }
    }
}
