import SwiftUI

/**
 solid-name: InputSection
 solid-category: view-component
 solid-description: Displays a text input interface when input is enabled and no modal prompt is pending.
 */
struct InputSection: View {
    @Binding var inputText: String
    let canSendInput: Bool
    let pendingPrompt: LogToolCall?
    let onSend: () -> Void

    var body: some View {
        if canSendInput && pendingPrompt == nil {
            VStack(spacing: 0) {
                Divider()
                InputFieldView(inputText: $inputText, canSendInput: canSendInput, onSend: onSend)
            }
        }
    }
}

#Preview {
    InputSection(inputText: .constant(""), canSendInput: true, pendingPrompt: nil, onSend: {})
}
