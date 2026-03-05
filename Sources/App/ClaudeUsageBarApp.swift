import AppKit
import ClaudeUsageBarLib
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let usageData = UsageData()
    private let agentTracker = AgentTracker()
    private let settings = AppSettings()
    private var monitor: UsageMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StatuslineInstaller.install()
        setupStatusItem()
        setupPopover()
        setupMonitor()
        updateStatusItemTitle()
        observeSettings()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Usage")
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(data: usageData, agentTracker: agentTracker, settings: settings)
        )
    }

    private func setupMonitor() {
        monitor = UsageMonitor { [weak self] in
            guard let self else { return }
            CommanderSupport.refreshFiles()
            self.usageData.reload()
            self.agentTracker.reload()
            self.updateStatusItemTitle()
        }
    }

    // MARK: - Status Item

    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }
        let period = settings.statusBarPeriod
        let stats: PeriodStats
        switch period {
        case .day: stats = usageData.day
        case .week: stats = usageData.week
        case .month: stats = usageData.month
        }
        button.title = "\(period.prefix): " + String(format: "$%.2f", stats.cost)
    }

    private func observeSettings() {
        withObservationTracking {
            _ = self.settings.statusBarPeriod
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusItemTitle()
                self?.observeSettings()
            }
        }
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // Show immediately with existing data, then refresh in background
            settings.isLoading = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                CommanderSupport.refreshFiles()
                DispatchQueue.main.async {
                    self.usageData.reload()
                    self.agentTracker.reload()
                    self.updateStatusItemTitle()
                    self.settings.isLoading = false
                }
            }
        }
    }
}

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {}
    }
}
