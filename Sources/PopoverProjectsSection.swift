import SwiftUI

/// "Projects" header plus one row per project, already sorted by the caller.
struct PopoverProjectsSection: View {
    let projects: [(key: String, value: ProjectStats)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerText
            PopoverProjectsList(projects: projects)
        }
    }

    private var headerText: some View {
        Text("Projects").font(.caption).fontWeight(.medium).foregroundStyle(.secondary).padding(.top, 4)
    }
}

#Preview {
    PopoverProjectsSection(projects: [("my-app", ProjectStats(main: SourceModelStats(cost: 5, linesAdded: 100, linesRemoved: 20)))])
}
