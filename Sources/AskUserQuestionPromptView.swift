import SwiftUI

/**
 solid-name: AskUserQuestionPromptView
 solid-category: view-component
 solid-description: Presents a question prompt with option selection and submission.
 */
struct AskUserQuestionPromptView: View {
    let data: AskUserQuestionToolData
    let toolID: String
    let bridge: TTYBridge?

    @State private var selectedOptionIdx: Int = 0
    @State private var promptToolID: String = ""

    private var question: ToolQuestion { data.questions[0] }
    private var effectiveSelection: Int { promptToolID == toolID ? selectedOptionIdx : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerIfPresent
            questionText
            optionsList
            submitButton
        }
        .padding(10)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var headerIfPresent: some View {
        if !question.header.isEmpty { headerLabel }
    }

    private var headerLabel: some View {
        Text(question.header)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    private var questionText: some View {
        Text(question.question)
            .font(.caption)
            .fontWeight(.medium)
    }

    private var optionsList: some View {
        QuestionOptionsListContent(options: question.options, selectedIndex: effectiveSelection) { idx in
            selectedOptionIdx = idx
            promptToolID = toolID
        }
    }

    private var submitButton: some View {
        PromptActionButton(title: "Submit", tint: .accentColor) {
            let idx = promptToolID == toolID ? selectedOptionIdx : 0
            for _ in 0..<idx { bridge?.sendRaw("\u{1b}[B") }
            bridge?.sendRaw("\r")
        }
    }
}

#Preview {
    AskUserQuestionPromptView(
        data: AskUserQuestionToolData(questions: [
            ToolQuestion(question: "Continue?", header: "Confirm", options: [
                ToolQuestionOption(label: "Yes", description: ""),
                ToolQuestionOption(label: "No", description: ""),
            ], multiSelect: false)
        ]),
        toolID: "1", bridge: nil
    )
    .padding()
}
