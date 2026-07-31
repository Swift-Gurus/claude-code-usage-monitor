import SwiftUI

/**
 solid-name: AskUserQuestionDetailView
 solid-category: view-component
 solid-description: Displays structured questions and their options for user selection.
 */
struct AskUserQuestionDetailView: View {
    let data: AskUserQuestionToolData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            QuestionsListContent(questions: data.questions)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    AskUserQuestionDetailView(data: AskUserQuestionToolData(questions: [
        ToolQuestion(question: "Pick one", header: "Choice", options: [
            ToolQuestionOption(label: "A", description: "First"),
            ToolQuestionOption(label: "B", description: "Second"),
        ], multiSelect: false)
    ]))
}