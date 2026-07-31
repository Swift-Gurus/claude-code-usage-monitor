import SwiftUI

/**
 solid-name: InputFieldView
 solid-category: view-component
 solid-description: Text input interface with controlled send action capability.
 */
struct InputFieldView: View {
    @Binding var inputText: String
    let canSendInput: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            textEditor
            sendButton
        }
    }

    private var textEditor: some View {
        InputTextEditor(inputText: $inputText)
    }

    private var sendButtonIcon: some View {
        Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(canSendInput && !inputText.isEmpty ? .blue : .gray)
    }

    private var sendButton: some View {
        Button(action: onSend) {
            sendButtonIcon
        }
        .buttonStyle(.plain)
        .disabled(!canSendInput || inputText.isEmpty)
        .keyboardShortcut(.return, modifiers: .command)
    }
}

#Preview {
    InputFieldView(inputText: .constant(""), canSendInput: true, onSend: {})
        .padding()
}
