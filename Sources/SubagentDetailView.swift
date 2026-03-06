import SwiftUI

public struct SubagentDetailView: View {
    let agent: AgentInfo
    let settings: AppSettings
    let onDismiss: () -> Void

    @State private var subagents: [SubagentInfo] = []

    private var usageDir: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/usage")
        switch agent.source {
        case .cli: return base
        case .commander: return base.appendingPathComponent("commander")
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text(agent.displayName)
                    .font(.headline)
            }

            Divider()

            // Agent summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.shortDir)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(agent.durationText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(String(format: "$%.2f", agent.cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Subagents header
            HStack {
                Text("Subagents")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Budget: \(settings.subagentContextBudget.label)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if subagents.isEmpty {
                Text("No subagents recorded for this session")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                List(subagents) { sub in
                    subagentRow(sub)
                        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .frame(maxHeight: 240)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { load() }
    }

    private func load() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let file = usageDir
            .appendingPathComponent(today)
            .appendingPathComponent("\(agent.pid).subagent-details.json")
        guard let data = try? Data(contentsOf: file),
              let details = try? JSONDecoder().decode([SubagentInfo].self, from: data)
        else { return }
        subagents = details
    }

    private func subagentRow(_ sub: SubagentInfo) -> some View {
        let contextPct = min(100, Int(Double(sub.lastInputTokens) / Double(settings.subagentContextBudget.tokens) * 100))
        let color: Color = contextPct >= 90 ? .red : contextPct >= 70 ? .yellow : .green

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sub.model)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", sub.cost))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(contextPct) / 100)
                    }
                }
                .frame(width: 80, height: 6)

                Text("\(contextPct)% of \(settings.subagentContextBudget.label)")
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
}
