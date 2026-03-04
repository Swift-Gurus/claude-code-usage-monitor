import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !StatuslineInstaller.isInstalled {
            StatuslineInstaller.install()
        }
    }
}

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var usageData = UsageData()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(data: usageData)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                Text(String(format: "$%.2f", usageData.day.cost))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Wrapper view that owns the monitor lifecycle
struct PopoverContentView: View {
    var data: UsageData
    @State private var monitor: UsageMonitor?

    var body: some View {
        PopoverView(data: data)
            .task {
                monitor = UsageMonitor { [data] in
                    data.reload()
                }
            }
    }
}
