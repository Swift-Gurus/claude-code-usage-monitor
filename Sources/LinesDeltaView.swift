import SwiftUI

/// Compact "+added / -removed" line-count display, colored per the caller's theme.
struct LinesDeltaView: View {
    let added: Int
    let removed: Int
    let addedColor: Color
    let removedColor: Color
    var spacing: CGFloat = 6
    var addedMinWidth: CGFloat?
    var removedMinWidth: CGFloat?

    var body: some View {
        HStack(spacing: spacing) {
            addedText
            removedText
        }
        .font(.caption2)
    }

    private var addedText: some View {
        Text("+\(added.formatted(.number.notation(.compactName)))")
            .foregroundStyle(addedColor)
            .frame(minWidth: addedMinWidth, alignment: .trailing)
    }

    private var removedText: some View {
        Text("-\(removed.formatted(.number.notation(.compactName)))")
            .foregroundStyle(removedColor)
            .frame(minWidth: removedMinWidth, alignment: .trailing)
    }
}

#Preview {
    LinesDeltaView(added: 120, removed: 40, addedColor: .green, removedColor: .red)
}
