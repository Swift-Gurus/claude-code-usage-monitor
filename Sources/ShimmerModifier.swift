import SwiftUI

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        GeometryReader { geo in
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: Color(NSColor.windowBackgroundColor).opacity(0.5), location: 0.4),
                                    .init(color: Color(NSColor.windowBackgroundColor).opacity(0.7), location: 0.5),
                                    .init(color: Color(NSColor.windowBackgroundColor).opacity(0.5), location: 0.6),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .init(x: phase, y: 0),
                                endPoint: .init(x: phase + 1, y: 0)
                            )
                        }
                    }
                }
            )
            .onChange(of: isActive) { _, active in
                if active {
                    phase = -1
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
    }
}

extension View {
    func shimmer(when isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}
