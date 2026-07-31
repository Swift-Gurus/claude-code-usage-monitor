import SwiftUI

/**
 solid-name: PermissionButtonsRow
 solid-category: view-component
 solid-description: Provides interactive response options for permission prompts.
 */
struct PermissionButtonsRow: View {
    let bridge: TTYBridge?

    var body: some View {
        HStack(spacing: 8) {
            PromptActionButton(title: "Allow", tint: .green) { bridge?.sendRaw("\r") }
            PromptActionButton(title: "Always", tint: .blue) {
                bridge?.sendRaw("\u{1b}[B")
                bridge?.sendRaw("\r")
            }
            PromptActionButton(title: "Deny", tint: .red) { bridge?.sendRaw("\u{1b}") }
        }
    }
}

#Preview {
    PermissionButtonsRow(bridge: nil)
}
