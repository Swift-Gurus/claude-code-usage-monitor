import SwiftUI

/**
 solid-name: LogContentComposedView
 solid-category: view-component
 solid-description: Combines log content display with a prompt overlay.
 */
struct LogContentComposedView<Header: View, TaskPanel: View, MessageScroll: View, InputFooter: View>: View {
    let showHeader: Bool
    @ViewBuilder let header: () -> Header
    let showTaskPanel: Bool
    @ViewBuilder let taskPanel: () -> TaskPanel
    @ViewBuilder let messageScroll: () -> MessageScroll
    @ViewBuilder let inputFooter: () -> InputFooter
    let pendingPrompt: LogToolCall?
    let bridge: TTYBridge?
    let canSendInput: Bool

    var body: some View {
        section
            .overlay { overlay }
    }

    private var section: some View {
        LogContentSection(
            showHeader: showHeader, header: header,
            showTaskPanel: showTaskPanel, taskPanel: taskPanel,
            messageScroll: messageScroll, inputFooter: inputFooter
        )
    }

    private var overlay: some View {
        PromptOverlaySection(pendingPrompt: pendingPrompt, bridge: bridge, canSendInput: canSendInput)
    }
}

#Preview {
    LogContentComposedView(
        showHeader: true, header: { Text("Header") },
        showTaskPanel: false, taskPanel: { EmptyView() },
        messageScroll: { Text("Messages") }, inputFooter: { EmptyView() },
        pendingPrompt: nil, bridge: nil, canSendInput: false
    )
}
