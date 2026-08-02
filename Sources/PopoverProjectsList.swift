import SwiftUI

/// One row per project, already sorted by the caller.
struct PopoverProjectsList: View {
    let projects: [(key: String, value: ProjectStats)]

    var body: some View {
        ForEach(projects, id: \.key) { project, stats in
            PopoverProjectRow(projectName: project, stats: stats)
        }
    }
}

#Preview {
    PopoverProjectsList(projects: [("my-app", ProjectStats(main: SourceModelStats(cost: 5, linesAdded: 100, linesRemoved: 20)))])
}
