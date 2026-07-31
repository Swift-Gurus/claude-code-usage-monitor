import SwiftUI

/**
 solid-name: AutoScrollingMessageList
 solid-category: view-component
 solid-description: Automatically keeps the newest message visible.
 */
struct AutoScrollingMessageList: View {
    let displayedMessages: [LogMessage]
    let roleLabel: (LogMessage) -> String
    let expandThinking: Bool
    let expandTools: Bool
    let toolResultLookup: [String: String]
    let scrollHeight: CGFloat?

    var body: some View {
        ScrollViewReader { proxy in
            scrollView
                .onChange(of: displayedMessages.count) { _, _ in scrollToBottom(proxy) }
                .onAppear { scrollToBottom(proxy) }
        }
    }

    private var scrollView: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.visible)
        .frame(height: scrollHeight, alignment: .top)
    }

    private var content: some View {
        MessageListContent(
            displayedMessages: displayedMessages, roleLabel: roleLabel, expandThinking: expandThinking,
            expandTools: expandTools, toolResultLookup: toolResultLookup
        )
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = displayedMessages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

#Preview {
    AutoScrollingMessageList(
        displayedMessages: [], roleLabel: { _ in "" }, expandThinking: false,
        expandTools: false, toolResultLookup: [:], scrollHeight: 300
    )
}
