import SwiftUI

/**
 solid-name: LogContentContainer
 solid-category: view-component
 solid-description: Manages async initialization and finalization lifecycle for a log content display.
 */
struct LogContentContainer<Header: View, TaskPanel: View, MessageScroll: View, InputFooter: View>: View {
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
    let onDisappearLifecycle: () -> Void

    var body: some View {
        composedView
            .padding(16)
            .task { await onAppearLifecycle() }
            .onDisappear { onDisappearLifecycle() }
    }

    private var composedView: some View {
        LogContentComposedView(
            showHeader: showHeader, header: header,
            showTaskPanel: showTaskPanel, taskPanel: taskPanel,
            messageScroll: messageScroll, inputFooter: inputFooter,
            pendingPrompt: pendingPrompt, bridge: bridge, canSendInput: canSendInput
        )
    }
}

#Preview("No pending prompt") {
    LogContentContainer(
        showHeader: true, header: { Text("Header") },
        showTaskPanel: false, taskPanel: { EmptyView() },
        messageScroll: { Text("Messages") }, inputFooter: { EmptyView() },
        pendingPrompt: nil, bridge: nil, canSendInput: false,
        onAppearLifecycle: {}, onDisappearLifecycle: {}
    )
}
