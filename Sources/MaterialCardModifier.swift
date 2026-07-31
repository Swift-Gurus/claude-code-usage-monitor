import SwiftUI

/**
 solid-name: MaterialCardModifier
 solid-category: view-component
 solid-description: Applies a floating card appearance to content.
 */
struct MaterialCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(radius: shadowRadius)
            .padding(16)
    }
}

extension View {
    func materialCard(cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 8) -> some View {
        modifier(MaterialCardModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}