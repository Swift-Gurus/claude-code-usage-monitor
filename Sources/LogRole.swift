import SwiftUI

public enum LogRole {
    case user, assistant, system

    /// Indicator-dot color used in the log viewer's message headers.
    var dotColor: Color {
        switch self {
        case .user: return .green
        case .assistant: return .blue
        case .system: return .orange
        }
    }
}
