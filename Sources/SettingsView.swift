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
                    .font(settings.displayMode == .window ? .body : .caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text("Settings")
                    .font(settings.displayMode == .window ? .title3 : .headline)
            }

            Divider()

            // Display Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("Display Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Button {
                    AppSettings.relaunch()
                } label: {
                    Text("Apply & Restart")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!settings.displayModeChanged)
            }

            Divider()

            // Appearance
            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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

            // Subagent Sort Order
            VStack(alignment: .leading, spacing: 6) {
                Text("Subagent Sort Order")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("", selection: $settings.subagentSortOrder) {
                    ForEach(SubagentSortOrder.allCases, id: \.self) { order in
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

            if settings.displayMode == .popover {
                Divider()

                // Max visible subagents
                VStack(alignment: .leading, spacing: 6) {
                    Text("Visible Subagents Before Scroll")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $settings.maxVisibleSubagents) {
                        ForEach([3, 5, 8, 10, 15], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                // Max visible log messages
                VStack(alignment: .leading, spacing: 6) {
                    Text("Visible Log Messages Before Scroll")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $settings.maxVisibleLogMessages) {
                        ForEach([5, 8, 12, 20, 50], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            Divider()

            // Log viewer expand defaults
            VStack(alignment: .leading, spacing: 6) {
                Text("Log Viewer Defaults")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Toggle("Always expand thinking", isOn: $settings.expandThinking)
                    .font(.caption)
                Toggle("Always expand tools", isOn: $settings.expandTools)
                    .font(.caption)
            }
        }
        .padding(16)
    }
}
