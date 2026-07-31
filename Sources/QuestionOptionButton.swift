import SwiftUI

/**
 solid-name: QuestionOptionButton
 solid-category: view-component
 solid-description: Enables selection of a question option.
 */
struct QuestionOptionButton: View {
    let option: ToolQuestionOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 6) {
            radioIcon
            OptionTextColumn(label: option.label, description: option.description)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var radioIcon: some View {
        Image(systemName: isSelected ? "circle.fill" : "circle")
            .font(.system(size: 10))
            .foregroundStyle(isSelected ? .blue : .secondary)
    }
}

#Preview {
    QuestionOptionButton(option: ToolQuestionOption(label: "Yes", description: "Confirm"), isSelected: true, onTap: {})
}
