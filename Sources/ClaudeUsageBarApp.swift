import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StatuslineInstaller.install()
    }
}

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var usageData = UsageData()
    @State private var agentTracker = AgentTracker()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(data: usageData, agentTracker: agentTracker)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                Text(String(format: "$%.2f", usageData.day.cost))
                if !agentTracker.activeAgents.isEmpty {
                    Text("(\(agentTracker.activeAgents.count))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Wrapper view that owns the monitor lifecycle
struct PopoverContentView: View {
    var data: UsageData
    var agentTracker: AgentTracker
    @State private var monitor: UsageMonitor?

    var body: some View {
        PopoverView(data: data, agentTracker: agentTracker)
            .onAppear {
                data.reload()
                agentTracker.reload()
            }
            .task {
                monitor = UsageMonitor { [data, agentTracker] in
                    data.reload()
                    agentTracker.reload()
                }
            }
    }
}
