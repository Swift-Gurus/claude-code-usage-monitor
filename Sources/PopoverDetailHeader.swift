import SwiftUI

/// Back button + title for the period cost breakdown detail screen.
struct PopoverDetailHeader: View {
    let label: String
    let navFont: Font
    let titleFont: Font
    let onBack: () -> Void

    var body: some View {
        HStack {
            BackButton(font: navFont, action: onBack)
            Spacer()
            titleText
        }
    }

    private var titleText: some View {
        Text("\(label) Breakdown").font(titleFont)
    }
}

#Preview {
    PopoverDetailHeader(label: "Today", navFont: .caption, titleFont: .headline, onBack: {})
}
