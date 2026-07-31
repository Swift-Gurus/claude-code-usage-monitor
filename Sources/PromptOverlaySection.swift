import SwiftUI

/**
 solid-name: PromptOverlaySection
 solid-category: view-component
 solid-description: Displays a prompt interface when a tool call is pending and user input can be sent.
 */
struct PromptOverlaySection: View {
    let pendingPrompt: LogToolCall?
    let bridge: TTYBridge?
    let canSendInput: Bool

    var body: some View {
        if canSendInput, let pending = pendingPrompt {
            PromptCardView(tc: pending, bridge: bridge)
                .dimmedOverlay()
        }
    }
}

#Preview {
    PromptOverlaySection(pendingPrompt: nil, bridge: nil, canSendInput: false)
}
