import SwiftUI

struct PopoverView: View {
    var data: UsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude Usage")
                .font(.headline)

            Divider()

            periodRow("Today", stats: data.day)
            periodRow("This Week", stats: data.week)
            periodRow("This Month", stats: data.month)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: StatuslineInstaller.isInstalled
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(StatuslineInstaller.isInstalled ? .green : .red)
                Text(StatuslineInstaller.isInstalled
                     ? "Statusline active" : "Statusline not configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !StatuslineInstaller.isInstalled {
                    Spacer()
                    Button("Install") {
                        StatuslineInstaller.install()
                    }
                    .font(.caption)
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(16)
        .frame(width: 240)
    }

    private func periodRow(_ label: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "$%.2f", stats.cost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                Label("+\(stats.linesAdded)", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
                Label("-\(stats.linesRemoved)", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
    }
}
