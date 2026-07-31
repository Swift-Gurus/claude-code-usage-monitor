import SwiftUI

/**
 solid-name: LogViewerHeaderTrailingButtons
 solid-category: view-component
 solid-description: Provides controls for toggling panel visibility and triggering session actions.
 */
struct LogViewerHeaderTrailingButtons: View {
    @Binding var showTaskPanel: Bool
    let hasTasks: Bool
    @Binding var showStatsPanel: Bool
    let hasStats: Bool
    let canStop: Bool
    let navFont: Font
    let onStop: () -> Void
    let onOpenFile: () -> Void

    var body: some View {
        HStack {
            if hasTasks { taskPanelToggle }
            if hasStats { statsPanelToggle }
            if canStop { stopButton }
            openFileButton
        }
    }

    private var taskPanelToggle: some View {
        IconButton(
            systemName: showTaskPanel ? "checklist.checked" : "checklist",
            color: showTaskPanel ? .blue : .secondary,
            font: navFont,
            help: showTaskPanel ? "Hide tasks" : "Show tasks",
            action: { showTaskPanel.toggle() }
        )
    }

    private var statsPanelToggle: some View {
        IconButton(
            systemName: showStatsPanel ? "chart.bar.fill" : "chart.bar",
            color: showStatsPanel ? .blue : .secondary,
            font: navFont,
            help: showStatsPanel ? "Hide stats" : "Show stats",
            action: { showStatsPanel.toggle() }
        )
    }

    private var stopButton: some View {
        IconButton(systemName: "stop.circle.fill", color: .red, font: navFont, help: "Stop session", action: onStop)
    }

    private var openFileButton: some View {
        IconButton(systemName: "arrow.up.right.square", color: .blue, font: navFont, help: "Open in default editor", action: onOpenFile)
    }
}

#Preview {
    LogViewerHeaderTrailingButtons(
        showTaskPanel: .constant(true), hasTasks: true,
        showStatsPanel: .constant(false), hasStats: true,
        canStop: true, navFont: .caption,
        onStop: {}, onOpenFile: {}
    )
}
