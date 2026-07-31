import SwiftUI

/**
 solid-name: QuestionOptionsListContent
 solid-category: view-component
 solid-description: Displays question options and enables selection.
 */
struct QuestionOptionsListContent: View {
    let options: [ToolQuestionOption]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
            QuestionOptionButton(option: option, isSelected: selectedIndex == idx) {
                onSelect(idx)
            }
        }
    }
}

#Preview {
    QuestionOptionsListContent(
        options: [ToolQuestionOption(label: "Yes", description: ""), ToolQuestionOption(label: "No", description: "")],
        selectedIndex: 0, onSelect: { _ in }
    )
}
