import SwiftUI

/**
 solid-name: SideBySideTaskPanelLayout
 solid-category: view-component
 solid-description: Arranges two views side by side in a horizontal layout.
 */
struct SideBySideTaskPanelLayout<LogContent: View, TaskPanel: View>: View {
    @ViewBuilder let logContent: () -> LogContent
    @ViewBuilder let taskPanel: () -> TaskPanel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            logContent()
            Divider()
            sizedTaskPanel
        }
    }

    private var sizedTaskPanel: some View {
        taskPanel()
            .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
    }
}

#Preview {
    SideBySideTaskPanelLayout(
        logContent: { Text("Log content") },
        taskPanel: { Text("Tasks") }
    )
}
