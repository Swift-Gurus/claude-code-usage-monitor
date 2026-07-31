import SwiftUI

/**
 solid-name: DimmedOverlayModifier
 solid-category: view-component
 solid-description: Applies a dimmed overlay effect with adjustable opacity to a view.
 */
struct DimmedOverlayModifier: ViewModifier {
    var opacity: Double = 0.3

    func body(content: Content) -> some View {
        ZStack {
            backdrop
            content
        }
    }

    private var backdrop: some View {
        Color.black.opacity(opacity)
            .ignoresSafeArea()
    }
}

extension View {
    func dimmedOverlay(opacity: Double = 0.3) -> some View {
        modifier(DimmedOverlayModifier(opacity: opacity))
    }
}
