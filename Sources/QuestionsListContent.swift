import SwiftUI

/**
 solid-name: QuestionsListContent
 solid-category: view-component
 solid-description: Displays a list of questions.
 */
struct QuestionsListContent: View {
    let questions: [ToolQuestion]

    var body: some View {
        EnumeratedListContent(items: questions) { q in
            QuestionDetailRow(question: q)
        }
    }
}

#Preview {
    QuestionsListContent(questions: [
        ToolQuestion(question: "Pick one", header: "Choice", options: [], multiSelect: false)
    ])
}