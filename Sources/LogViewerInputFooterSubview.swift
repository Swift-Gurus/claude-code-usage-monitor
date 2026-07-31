import SwiftUI

/// Thin wrapper isolating InputSection from LogViewerView's body.
struct LogViewerInputFooterSubview: View {
    @Binding var inputText: String
    let canSendInput: Bool
    let pendingPrompt: LogToolCall?
    let onSend: () -> Void

    var body: some View {
        InputSection(inputText: $inputText, canSendInput: canSendInput, pendingPrompt: pendingPrompt, onSend: onSend)
    }
}

#Preview {
    LogViewerInputFooterSubview(inputText: .constant(""), canSendInput: true, pendingPrompt: nil, onSend: {})
}
