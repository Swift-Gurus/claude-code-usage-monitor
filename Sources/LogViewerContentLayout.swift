import SwiftUI

/// Thin wrapper isolating LogViewerContentContainer's parameter list from LogViewerView's body.
struct LogViewerContentLayout<Header: View, SidePanel: View, MessageScroll: View, InputFooter: View>: View {
    let showHeader: Bool
    @ViewBuilder let header: () -> Header
    let showSidePanel: Bool
    @ViewBuilder let sidePanel: () -> SidePanel
    @ViewBuilder let messageScroll: () -> MessageScroll
    @ViewBuilder let inputFooter: () -> InputFooter
    let pendingPrompt: LogToolCall?
    let bridge: TTYBridge?
    let canSendInput: Bool
    let onAppearLifecycle: () async -> Void

    var body: some View {
        LogViewerContentContainer(
            showHeader: showHeader, header: header,
            showTaskPanel: showSidePanel, taskPanel: sidePanel,
            messageScroll: messageScroll, inputFooter: inputFooter,
            pendingPrompt: pendingPrompt, bridge: bridge, canSendInput: canSendInput,
            onAppearLifecycle: onAppearLifecycle
        )
    }
}

#Preview {
    LogViewerContentLayout(
        showHeader: true, header: { Text("Header") },
        showSidePanel: false, sidePanel: { EmptyView() },
        messageScroll: { Text("Messages") }, inputFooter: { EmptyView() },
        pendingPrompt: nil, bridge: nil, canSendInput: false,
        onAppearLifecycle: {}
    )
}
