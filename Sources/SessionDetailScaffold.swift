import SwiftUI

/**
 solid-name: SessionDetailScaffold
 solid-category: view-component
 solid-stack: [swiftui]
 solid-description: Shared presentation shell for inspect-session screens. Owns the common back/header/open-file affordance and window-vs-popover layout so Claude and Codex detail screens only provide their content.
 */
struct SessionDetailScaffold<Content: View>: View {
    let title: String
    let settings: AppSettings
    let openFileHelp: String
    let onDismiss: () -> Void
    let onOpenFile: (() -> Void)?
    @ViewBuilder let content: () -> Content

    private var navFont: Font { settings.displayMode == .window ? .body : .caption }
    private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }

    var body: some View {
        if settings.displayMode == .window {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                ScrollView {
                    content()
                        .padding(16)
                }
                .scrollIndicators(.visible)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                content()
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { onDismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(navFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text(title)
                    .font(titleFont)
                    .lineLimit(1)

                Spacer()

                if let onOpenFile {
                    Button(action: onOpenFile) {
                        Image(systemName: "arrow.up.right.square")
                            .font(navFont)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .help(openFileHelp)
                }
            }
            .padding(.vertical, 8)

            Divider()
        }
    }
}

/**
 solid-name: SessionDetailView
 solid-category: screen
 solid-stack: [swiftui]
 solid-description: Generic inspect-session screen built from shared sections. Claude and Codex wrappers provide source-specific section content while reusing a single detail view surface.
 */
struct SessionDetailView<SummarySection: View, ChildSection: View, LogSection: View>: View {
    let title: String
    let settings: AppSettings
    let openFileHelp: String
    let onDismiss: () -> Void
    let onOpenFile: (() -> Void)?
    @ViewBuilder let summarySection: () -> SummarySection
    @ViewBuilder let childSection: () -> ChildSection
    @ViewBuilder let logSection: () -> LogSection

    var body: some View {
        SessionDetailScaffold(
            title: title,
            settings: settings,
            openFileHelp: openFileHelp,
            onDismiss: onDismiss,
            onOpenFile: onOpenFile
        ) {
            VStack(alignment: .leading, spacing: 12) {
                summarySection()
                childSection()
                Divider()
                logSection()
            }
        }
    }
}
