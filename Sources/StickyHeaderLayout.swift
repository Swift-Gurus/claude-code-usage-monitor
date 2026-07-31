import SwiftUI

/// Thin wrapper isolating StickyHeaderContainer's @ViewBuilder parameter list from LogViewerView's body.
struct StickyHeaderLayout<Header: View, LogContent: View, TaskPanel: View>: View {
    let showTaskPanel: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let logContent: () -> LogContent
    @ViewBuilder let taskPanel: () -> TaskPanel

    var body: some View {
        StickyHeaderContainer(showTaskPanel: showTaskPanel, header: header, logContent: logContent, taskPanel: taskPanel)
    }
}

#Preview {
    StickyHeaderLayout(
        showTaskPanel: true,
        header: { Text("Header") }, logContent: { Text("Log") }, taskPanel: { Text("Tasks") }
    )
}
