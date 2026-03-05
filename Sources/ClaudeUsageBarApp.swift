import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let usageData = UsageData()
    private let agentTracker = AgentTracker()
    private var monitor: UsageMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StatuslineInstaller.install()
        setupStatusItem()
        setupPopover()
        setupMonitor()
        updateStatusItemTitle()
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
            rootView: PopoverView(data: usageData, agentTracker: agentTracker)
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
        button.title = String(format: "$%.2f", usageData.day.cost)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            CommanderSupport.refreshFiles()
            usageData.reload()
            agentTracker.reload()
            updateStatusItemTitle()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
