import SwiftUI
import AppKit

/**
 solid-name: LogViewerView
 solid-category: screen
 solid-stack: [swiftui]
 solid-description: Displays Claude Code session logs and enables interaction with the active session.
 */
struct LogViewerView<VM: LogViewerState & LogViewerActions>: View {
    let agent: AgentInfo
    let target: LogTarget
    let settings: AppSettings
    var sessionManager: SessionManager?
    var stickyHeader: Bool = false
    var onStop: (() -> Void)?
    var urlOpener: URLOpening = WorkspaceURLOpener()
    @State var vm: VM
    let onDismiss: () -> Void

    @State private var showTaskPanel = true
    @State private var showStatsPanel = false
    @State private var inputText = ""

    private var sidePanel: LogViewerSidePanel {
        LogViewerSidePanel(
            showTaskPanel: showTaskPanel, taskList: vm.taskList, completedTaskCount: vm.completedTaskCount,
            showStatsPanel: showStatsPanel, sessionStats: vm.sessionStats
        )
    }

    private var bridge: TTYBridge? {
        sessionManager?.bridge(for: agent.pid)
    }

    private var canSendInput: Bool {
        target.isParent && (bridge?.isAttached ?? false)
    }

    private var title: String {
        target.displayTitle(agentName: agent.displayName)
    }

    private var scrollHeight: CGFloat? {
        if settings.displayMode == .window { return nil }
        return CGFloat(settings.maxVisibleLogMessages) * 60
    }

    private var navFont: Font { settings.displayMode == .window ? .body : .caption }
    private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }

    var body: some View {
        if stickyHeader {
            stickyHeaderLayout
        } else {
            inlineLayout
        }
    }

    private var stickyHeaderLayout: some View {
        StickyHeaderLayout(
            showTaskPanel: sidePanel.isVisible,
            header: { headerSection }, logContent: { logContent }, taskPanel: { sidePanel }
        )
    }

    private var inlineLayout: some View {
        logContent
    }

    private var headerSection: some View {
        LogViewerHeaderSubview(
            title: title, isConnected: canSendInput, showTaskPanel: $showTaskPanel,
            hasTasks: !vm.taskList.isEmpty, showStatsPanel: $showStatsPanel, hasStats: sidePanel.hasStats,
            canStop: canSendInput, navFont: navFont, titleFont: titleFont,
            onDismiss: onDismiss,
            onStop: { bridge?.detach(); sessionManager?.sessions.removeValue(forKey: agent.pid); onStop?() },
            onOpenFile: { urlOpener.open(vm.fileURL) }
        )
    }

    private var messageScrollSection: some View {
        LogViewerMessageScrollSubview(
            isLoading: vm.isLoading, messages: vm.messages, displayedMessages: vm.displayedMessages,
            roleLabel: vm.roleLabel, expandThinking: settings.expandThinking, expandTools: settings.expandTools,
            toolResultLookup: vm.toolResultLookup, scrollHeight: scrollHeight
        )
    }

    private var inputFooterSection: some View {
        LogViewerInputFooterSubview(inputText: $inputText, canSendInput: canSendInput, pendingPrompt: vm.pendingPrompt, onSend: sendInput)
    }

    private var logContent: some View {
        LogViewerContentLayout(
            showHeader: !stickyHeader, header: { headerSection },
            showSidePanel: !stickyHeader && sidePanel.isVisible,
            sidePanel: { sidePanel }, messageScroll: { messageScrollSection }, inputFooter: { inputFooterSection },
            pendingPrompt: vm.pendingPrompt, bridge: bridge, canSendInput: canSendInput,
            onAppearLifecycle: { await vm.startViewLifecycle(bridge: bridge) }
        )
    }

    private func sendInput() {
        vm.send(inputText, via: bridge)
        inputText = ""
    }
}

#Preview {
    LogViewerView(
        agent: AgentInfo(
            pid: 1, model: "Sonnet", agentName: "Preview Session", contextPercent: 0, contextWindow: 200_000,
            cost: 0, linesAdded: 0, linesRemoved: 0, workingDir: "/tmp", sessionID: "preview",
            durationMs: 0, apiDurationMs: 0, updatedAt: 0, cpuUsage: 0, isIdle: false, source: .cli
        ),
        target: .parent,
        settings: AppSettings(),
        vm: PreviewLogViewerVM(),
        onDismiss: {}
    )
}