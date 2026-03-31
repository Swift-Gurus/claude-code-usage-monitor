import SwiftUI

public struct SettingsView: View {
    @Bindable var settings: AppSettings
    var onDismiss: () -> Void
    @State private var editingAccountID: UUID?
    @State private var editingName: String = ""

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

            // Accounts
            VStack(alignment: .leading, spacing: 6) {
                Text("Accounts")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Add .claude directories from different accounts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(settings.accounts) { account in
                    accountRow(account)
                }

                // Detected accounts suggestion
                let detected = detectClaudeDirs()
                let existing = Set(settings.accounts.map(\.claudeDir))
                let suggestions = detected.filter { !existing.contains($0) }
                if !suggestions.isEmpty {
                    Text("Detected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(suggestions, id: \.self) { path in
                        HStack(spacing: 6) {
                            Text(path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Add") {
                                let name = (path as NSString).lastPathComponent == ".claude"
                                    ? ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
                                    : (path as NSString).lastPathComponent
                                settings.accounts.append(Account(name: name, claudeDir: path))
                            }
                            .font(.caption2)
                        }
                    }
                }

                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.message = "Select a .claude directory"
                    panel.prompt = "Add"
                    if panel.runModal() == .OK, let url = panel.url {
                        let name = url.lastPathComponent == ".claude"
                            ? url.deletingLastPathComponent().lastPathComponent
                            : url.lastPathComponent
                        settings.accounts.append(Account(name: name, claudeDir: url.path))
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Add Custom...")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Divider()

            // Status Bar Account (only shown with multiple accounts)
            if settings.accounts.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status Bar Account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: Binding(
                        get: { settings.statusBarAccountID?.uuidString ?? "all" },
                        set: { newVal in
                            settings.statusBarAccountID = newVal == "all" ? nil : UUID(uuidString: newVal)
                        }
                    )) {
                        Text("All Combined").tag("all")
                        ForEach(settings.accounts) { account in
                            Text(account.name).tag(account.id.uuidString)
                        }
                    }
                    .labelsHidden()
                }

                Divider()
            }

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

                // Max visible agents
                VStack(alignment: .leading, spacing: 6) {
                    Text("Visible Agents Before Scroll")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $settings.maxVisibleAgents) {
                        ForEach([2, 3, 5, 8, 10], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

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
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            accountRowHeader(account)
            // Alias field
            if let idx = settings.accounts.firstIndex(where: { $0.id == account.id }) {
                HStack(spacing: 4) {
                    Text("Alias:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TextField("e.g. 🏢 Work", text: $settings.accounts[idx].alias)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption2)
                        .frame(maxWidth: 140)
                    if !account.alias.isEmpty {
                        Text("→ \(account.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(account.claudeDir)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            accountRowControls(account)
        }
        .padding(6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func accountRowHeader(_ account: Account) -> some View {
        HStack(spacing: 6) {
            if editingAccountID == account.id {
                TextField("Name", text: $editingName, onCommit: {
                    if let idx = settings.accounts.firstIndex(where: { $0.id == account.id }) {
                        settings.accounts[idx].name = editingName
                    }
                    editingAccountID = nil
                })
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 80)
            } else {
                Text(account.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .onTapGesture {
                        editingAccountID = account.id
                        editingName = account.name
                    }
            }
            let badgeColor: Color = account.accountType == .enterprise ? .blue : .orange
            Text(account.accountType.label)
                .font(.system(size: 9))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(badgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            Spacer()
            if settings.accounts.count > 1 {
                Button {
                    settings.accounts.removeAll { $0.id == account.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func accountRowControls(_ account: Account) -> some View {
        if let idx = settings.accounts.firstIndex(where: { $0.id == account.id }) {
            Picker("Plan", selection: $settings.accounts[idx].accountType) {
                ForEach(AccountType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            .labelsHidden()
            .font(.caption)

            if account.accountType.hasRateLimits {
                Text("Rolling window rate limits · shared with Claude web")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Detect .claude directories in common locations.
    private func detectClaudeDirs() -> [String] {
        let fm = FileManager.default
        var dirs: [String] = []

        // Default home directory
        let homeDir = fm.homeDirectoryForCurrentUser
        let defaultPath = homeDir.appendingPathComponent(".claude").path
        if fm.fileExists(atPath: defaultPath) {
            dirs.append(defaultPath)
        }

        // Check /Users/* for other user directories that have .claude
        if let users = try? fm.contentsOfDirectory(atPath: "/Users") {
            for user in users where user != "." && user != ".." && user != "Shared" {
                let path = "/Users/\(user)/.claude"
                if fm.fileExists(atPath: path) && !dirs.contains(path) {
                    dirs.append(path)
                }
            }
        }

        return dirs
    }
}
