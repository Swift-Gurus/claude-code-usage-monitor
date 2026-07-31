import SwiftUI

/**
 solid-name: InputTextEditor
 solid-category: view-component
 solid-description: Auto-sizing multiline text editor with placeholder text.
 */
struct InputTextEditor: View {
    @Binding var inputText: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            sizingGhostText
            editor
            placeholder
        }
        .frame(minHeight: 36, maxHeight: 120)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
    }

    private var sizingGhostText: some View {
        Text(inputText.isEmpty ? " " : inputText)
            .font(.system(size: 12))
            .padding(8)
            .opacity(0)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editor: some View {
        TextEditor(text: $inputText)
            .font(.system(size: 12))
            .scrollContentBackground(.hidden)
            .padding(4)
    }

    @ViewBuilder
    private var placeholder: some View {
        if inputText.isEmpty {
            placeholderText
        }
    }

    private var placeholderText: some View {
        Text("Type a message...")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .allowsHitTesting(false)
    }
}

#Preview {
    InputTextEditor(inputText: .constant(""))
        .padding()
}