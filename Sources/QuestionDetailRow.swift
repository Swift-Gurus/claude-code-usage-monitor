import SwiftUI

/**
 solid-name: QuestionDetailRow
 solid-category: view-component
 solid-description: Displays a question with options for user interaction.
 */
struct QuestionDetailRow: View {
    let question: ToolQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerIfPresent
            questionText
            optionsList
        }
    }

    @ViewBuilder
    private var headerIfPresent: some View {
        if !question.header.isEmpty {
            headerText
        }
    }

    private var headerText: some View {
        Text(question.header).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
    }

    private var questionText: some View {
        Text(question.question).font(.system(size: 10))
    }

    private var optionsList: some View {
        EnumeratedListContent(items: question.options) { option in
            OptionLabelText(label: option.label)
        }
    }
}

#Preview {
    QuestionDetailRow(question: ToolQuestion(
        question: "Pick one", header: "Choice",
        options: [ToolQuestionOption(label: "A", description: "First")], multiSelect: false
    ))
}
