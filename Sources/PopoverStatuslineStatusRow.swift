import SwiftUI

/// One account's statusline install status, with an "Install" button when missing.
struct PopoverStatuslineStatusRow: View {
    let account: Account
    let isInstalled: Bool
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            statusText
            installButtonIfNeeded
        }
    }

    private var statusIcon: some View {
        Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(isInstalled ? .green : .red)
    }

    private var statusText: some View {
        Text(statusMessage).font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }

    private var statusMessage: String {
        isInstalled
            ? "\(account.displayName) statusline active"
            : "\(account.displayName) statusline not configured"
    }

    @ViewBuilder
    private var installButtonIfNeeded: some View {
        if !isInstalled {
            Spacer()
            installButton
        }
    }

    private var installButton: some View {
        Button("Install", action: onInstall).font(.caption)
    }
}

#Preview {
    PopoverStatuslineStatusRow(account: .default, isInstalled: false, onInstall: {})
}
