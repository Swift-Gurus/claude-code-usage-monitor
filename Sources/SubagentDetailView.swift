import SwiftUI

/// Custom vertical layout for subagent rows.
/// Reports the TOTAL height of all rows (enabling ScrollView scrolling)
/// while placing them correctly with spacing.
private struct SubagentRowsLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        let total = heights.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for subview in subviews {
            let h = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: h)
            )
            y += h + spacing
        }
    }
}

/// Collects each row's actual rendered height by index for precise N-row viewport sizing.
private struct RowHeightsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

public struct SubagentDetailView: View {
    let agent: AgentInfo
    let agentTracker: AgentTracker
    let settings: AppSettings
    let onDismiss: () -> Void

    @State private var subagents: [SubagentInfo] = []
    @State private var rowHeights: [Int: CGFloat] = [:]

    private let rowSpacing: CGFloat = 6

    private var usageDir: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage")
        switch agent.source {
        case .cli: return base
        case .commander: return base.appendingPathComponent("commander")
        }
    }

    private func loadFromFile() async {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let file = usageDir
            .appendingPathComponent(today)
            .appendingPathComponent("\(agent.pid).subagent-details.json")
        let details = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: file),
                  let decoded = try? JSONDecoder().decode([SubagentInfo].self, from: data)
            else { return [SubagentInfo]() }
            return decoded
        }.value
        if !details.isEmpty { subagents = details }
    }

    /// Sum of the first N rows' actual heights — precise regardless of variable row heights.
    private var viewportHeight: CGFloat? {
        let n = min(subagents.count, settings.maxVisibleSubagents)
        guard rowHeights.count >= n else { return nil }
        let h = (0..<n).compactMap { rowHeights[$0] }.reduce(0, +)
        return h + rowSpacing * CGFloat(max(0, n - 1))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Button { onDismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                Spacer()
                Text(agent.displayName).font(.headline)
            }

            Divider()

            // Agent summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.shortDir).font(.caption).foregroundStyle(.secondary)
                    Text(agent.durationText).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Text(String(format: "$%.2f", agent.cost))
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
            }

            Divider()

            HStack {
                Text("Subagents").font(.subheadline).fontWeight(.medium)
                if !subagents.isEmpty {
                    Text("\(subagents.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                Spacer()
                Text("Budget: \(settings.subagentContextBudget.label)")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if subagents.isEmpty {
                Text("No subagents recorded for this session")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: rowSpacing) {
                        ForEach(Array(subagents.enumerated()), id: \.element.id) { idx, sub in
                            subagentRow(sub)
                                .background(GeometryReader { geo in
                                    Color.clear.preference(
                                        key: RowHeightsKey.self,
                                        value: [idx: geo.size.height]
                                    )
                                })
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(height: viewportHeight)
                .onPreferenceChange(RowHeightsKey.self) { heights in
                    rowHeights = heights
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .task {
            await loadFromFile()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await loadFromFile()
            }
        }
    }

    private func subagentRow(_ sub: SubagentInfo) -> some View {
        let contextPct = min(100, Int(Double(sub.lastInputTokens) / Double(settings.subagentContextBudget.tokens) * 100))
        let color: Color = contextPct >= 90 ? .red : contextPct >= 70 ? .yellow : .green

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sub.model).font(.caption).fontWeight(.medium).lineLimit(1)
                Spacer(minLength: 4)
                Text("+\(sub.linesAdded)").font(.caption2).foregroundStyle(.green)
                    .frame(minWidth: 36, alignment: .trailing)
                Text("-\(sub.linesRemoved)").font(.caption2).foregroundStyle(.red)
                    .frame(minWidth: 32, alignment: .trailing)
                Text(String(format: "$%.2f", sub.cost))
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                    .frame(minWidth: 48, alignment: .trailing)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2).fill(color)
                            .frame(width: geo.size.width * CGFloat(contextPct) / 100)
                    }
                }
                .frame(width: 80, height: 6)
                Text("\(contextPct)% of \(settings.subagentContextBudget.label)")
                    .font(.caption2).foregroundStyle(color)
            }

            if !sub.toolCounts.isEmpty {
                let sorted = sub.toolCounts.sorted { $0.value > $1.value }
                FlowLayout(spacing: 4, maxLines: 5) {
                    ForEach(sorted, id: \.key) { tool, count in
                        Text(count > 1 ? "\(tool) (\(count))" : tool)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
}
