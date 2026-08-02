import SwiftUI

/// The filled track for `ContextProgressBar`, separated so its GeometryReader-driven
/// fill calculation doesn't add nesting to the parent's own body.
struct FilledProgressBar: View {
    let percent: Int
    let color: Color
    let height: CGFloat
    let width: CGFloat?

    var body: some View {
        sizedTrack
    }

    private var sizedTrack: some View {
        ProgressTrackContainer(percent: percent, color: color)
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
    }
}

private struct ProgressTrackContainer: View {
    let percent: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                backgroundTrack
                filledPortion(trackWidth: geo.size.width)
            }
        }
    }

    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.2))
    }

    private func filledPortion(trackWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: trackWidth * CGFloat(percent) / 100)
    }
}

#Preview {
    FilledProgressBar(percent: 65, color: .green, height: 6, width: 60)
        .padding()
}

#Preview("Track only") {
    ProgressTrackContainer(percent: 65, color: .green)
        .frame(width: 60, height: 6)
        .padding()
}
