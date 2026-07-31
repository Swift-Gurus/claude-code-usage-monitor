import SwiftUI

/**
 solid-name: LogContentSection
 solid-category: view-component
 solid-description: Composes four view sections vertically with conditional visibility for the first two.
 */
struct LogContentSection<Header: View, TaskPanel: View, MessageScroll: View, InputFooter: View>: View {
    let showHeader: Bool
    @ViewBuilder let header: () -> Header
    let showTaskPanel: Bool
    @ViewBuilder let taskPanel: () -> TaskPanel
    @ViewBuilder let messageScroll: () -> MessageScroll
    @ViewBuilder let inputFooter: () -> InputFooter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerIfShown
            taskPanelIfShown
            messageScroll()
            inputFooter()
        }
    }

    @ViewBuilder
    private var headerIfShown: some View {
        if showHeader { header() }
    }

    @ViewBuilder
    private var taskPanelIfShown: some View {
        if showTaskPanel {
            taskPanel()
            Divider()
        }
    }
}

#Preview {
    LogContentSection(
        showHeader: true, header: { Text("Header") },
        showTaskPanel: false, taskPanel: { EmptyView() },
        messageScroll: { Text("Messages") }, inputFooter: { EmptyView() }
    )
}