import SwiftUI

public struct SettingsView: View {
    @Bindable var settings: AppSettings
    var onDismiss: () -> Void

    public init(settings: AppSettings, onDismiss: @escaping () -> Void) {
        self.settings = settings
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                Text("Settings")
                    .font(.headline)
            }

            Divider()

            // Status Bar Period
            VStack(alignment: .leading, spacing: 6) {
                Text("Status Bar Cost")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("", selection: $settings.statusBarPeriod) {
                    ForEach(StatusBarPeriod.allCases, id: \.self) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Agent Sort Order
            VStack(alignment: .leading, spacing: 6) {
                Text("Agent Sort Order")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("", selection: $settings.agentSortOrder) {
                    ForEach(AgentSortOrder.allCases, id: \.self) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Subagent Context Budget
            VStack(alignment: .leading, spacing: 6) {
                Text("Subagent Context Budget")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Used to calculate context % in subagent drill-down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.subagentContextBudget) {
                    ForEach(SubagentContextBudget.allCases, id: \.self) { budget in
                        Text(budget.label).tag(budget)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
