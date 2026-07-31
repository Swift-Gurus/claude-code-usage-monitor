import SwiftUI

/**
 solid-name: MonoTextView
 solid-category: view-component
 solid-description: Displays selectable monospaced text with optional background styling.
 */
struct MonoTextView: View {
    let text: String
    var color: Color = .secondary
    var boxed: Bool = true

    var body: some View {
        if boxed {
            boxedText
        } else {
            plainText
        }
    }

    private var plainText: some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(color)
            .textSelection(.enabled)
    }

    private var boxedText: some View {
        plainText
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    MonoTextView(text: "sample/path.swift")
        .padding()
}
