import SwiftUI

/**
 solid-name: LogViewerContentContainer
 solid-category: view-component
 solid-description: Renders a logging interface with customizable header, task panel, message, and input sections.
 */
struct LogViewerContentContainer<Header: View, TaskPanel: View, MessageScroll: View, InputFooter: View>: View {
    let showHeader: Bool
    @ViewBuilder let header: () -> Header
    let showTaskPanel: Bool
    @ViewBuilder let taskPanel: () -> TaskPanel
    @ViewBuilder let messageScroll: () -> MessageScroll
    @ViewBuilder let inputFooter: () -> InputFooter
    let pendingPrompt: LogToolCall?
    let bridge: TTYBridge?
    let canSendInput: Bool
    let onAppearLifecycle: () async -> Void

    var body: some View {
        LogContentContainer(
            showHeader: showHeader, header: header,
            showTaskPanel: showTaskPanel, taskPanel: taskPanel,
            messageScroll: messageScroll, inputFooter: inputFooter,
            pendingPrompt: pendingPrompt, bridge: bridge, canSendInput: canSendInput,
            onAppearLifecycle: onAppearLifecycle, onDisappearLifecycle: {}
        )
    }
}

#Preview {
    LogViewerContentContainer(
        showHeader: true, header: { Text("Header") },
        showTaskPanel: false, taskPanel: { EmptyView() },
        messageScroll: { Text("Messages") }, inputFooter: { EmptyView() },
        pendingPrompt: nil, bridge: nil, canSendInput: false, onAppearLifecycle: {}
    )
}
