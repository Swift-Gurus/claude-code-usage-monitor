import SwiftUI

/// Per-model input/output token breakdown, already sorted by the caller.
struct PopoverModelUsageSection: View {
    let sortedModelUsage: [StatsCache.ModelUsage]

    var body: some View {
        EnumeratedListContent(items: sortedModelUsage) { model in
            PopoverModelUsageRow(
                modelID: model.modelID,
                inputTokens: model.inputTokens + model.cacheReadInputTokens,
                outputTokens: model.outputTokens
            )
        }
    }
}

#Preview {
    PopoverModelUsageSection(sortedModelUsage: [])
}
