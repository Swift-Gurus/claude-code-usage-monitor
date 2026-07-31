import SwiftUI

/**
 solid-name: PromptCardView
 solid-category: view-component
 solid-description: Styled card presentation of prompt information.
 */
struct PromptCardView: View {
    let tc: LogToolCall
    let bridge: TTYBridge?

    var body: some View {
        styledContent
    }

    private var styledContent: some View {
        PromptView(tc: tc, bridge: bridge)
            .materialCard()
    }
}
