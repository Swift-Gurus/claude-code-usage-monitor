import SwiftUI

/**
 solid-name: StickyHeaderContainer
 solid-category: view-component
 solid-description: Container that arranges a fixed header with flexible content below.
 */
struct StickyHeaderContainer<Header: View, LogContent: View, TaskPanel: View>: View {
    let showTaskPanel: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let logContent: () -> LogContent
    @ViewBuilder let taskPanel: () -> TaskPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if showTaskPanel {
            SideBySideTaskPanelLayout(logContent: logContent, taskPanel: taskPanel)
        } else {
            logContent()
        }
    }
}

#Preview {
    StickyHeaderContainer(
        showTaskPanel: true,
        header: { Text("Header").padding() },
        logContent: { Text("Log content") },
        taskPanel: { Text("Tasks") }
    )
}
