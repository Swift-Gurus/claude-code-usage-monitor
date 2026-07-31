import SwiftUI

/**
 solid-name: GeneralToolDetailContent
 solid-category: view-component
 solid-description: Renders detail view for non-file-operation tools.
 */
struct GeneralToolDetailContent: View {
    let data: ToolData
    let resultContent: String?

    var body: some View {
        taskAndAgentView
        webAndPlanView
        specialView
    }

    @ViewBuilder
    private var taskAndAgentView: some View {
        switch data {
        case .agent(let d): AgentDetailView(data: d)
        case .taskCreate(let d): TaskCreateDetailView(data: d)
        case .todoWrite(let d): TodoChecklistView(todos: d.todos)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var webAndPlanView: some View {
        switch data {
        case .skill(let d): SkillToolExpandedContent(data: d)
        case .webSearch(let d): MonoTextView(text: d.query)
        case .webFetch(let d): MonoTextView(text: d.url + (d.prompt.isEmpty ? "" : "\n\(d.prompt)"))
        case .askUserQuestion(let d): AskUserQuestionDetailView(data: d)
        case .exitPlanMode(let d): MonoTextView(text: String(d.plan.prefix(500)))
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var specialView: some View {
        switch data {
        case .hook(let d): HookDetailView(data: d)
        case .mcp(let d): MCPDetailView(data: d, resultContent: resultContent)
        case .other(let raw): OtherToolDetailView(raw: raw, resultContent: resultContent)
        default: EmptyView()
        }
    }
}

#Preview {
    GeneralToolDetailContent(data: .webSearch(WebSearchToolData(query: "swift concurrency")), resultContent: nil)
        .padding()
}
