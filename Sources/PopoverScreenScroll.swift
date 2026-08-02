import SwiftUI

/// Wraps a popover screen's content in a `ScrollView` for standalone-window mode,
/// or applies flat padding for the compact popover presentation.
struct PopoverScreenScroll<Content: View>: View {
    let displayMode: DisplayMode
    @ViewBuilder let content: () -> Content

    var body: some View {
        if displayMode == .window {
            WindowScroll(content: content)
        } else {
            CompactContent(content: content)
        }
    }
}

private struct WindowScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content().padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CompactContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().padding(16)
    }
}

#Preview {
    PopoverScreenScroll(displayMode: .popover) {
        Text("Content")
    }
}
