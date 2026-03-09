import AppKit
import ClaudeUsageBarLib
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private var window: NSWindow?
    private let usageData = UsageData()
    private let agentTracker = AgentTracker()
    private let settings = AppSettings()
    private let sessionManager = SessionManager()
    private var monitor: UsageMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StatuslineInstaller.install()
        setupStatusItem()

        if settings.displayMode == .window {
            setupWindow()
        } else {
            setupPopover()
        }

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
        button.action = #selector(toggleUI)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(
            rootView: PopoverView(data: usageData, agentTracker: agentTracker, settings: settings, sessionManager: sessionManager)
        )
    }

    private func setupWindow() {
        let hostingView = NSHostingController(
            rootView: PopoverView(data: usageData, agentTracker: agentTracker, settings: settings, sessionManager: sessionManager)
        )
        // Prevent SwiftUI from trying to auto-resize the window (causes re-entrant layout crash)
        hostingView.sizingOptions = []

        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = hostingView
        win.title = "Claude Usage"
        win.isFloatingPanel = true
        win.level = .floating
        win.isMovableByWindowBackground = true
        win.hidesOnDeactivate = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.setFrameAutosaveName("ClaudeUsageBarWindow")
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 320, height: 300)

        window = win
    }

    private let refreshQueue = DispatchQueue(label: "com.swiftgurus.refresh", qos: .userInitiated)
    private var refreshInFlight = false

    private func setupMonitor() {
        monitor = UsageMonitor { [weak self] in
            self?.scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        refreshQueue.async { [weak self] in
            guard let self else { return }
            CommanderSupport.refreshFiles()
            DispatchQueue.main.async {
                self.usageData.reload()
                self.agentTracker.reload()
                self.updateStatusItemTitle()
                self.refreshInFlight = false
            }
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

    // MARK: - Toggle UI

    @objc private func toggleUI() {
        if settings.displayMode == .window {
            toggleWindow()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
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

    private func toggleWindow() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            settings.isLoading = true
            window.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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

extension AppDelegate: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        popover?.contentViewController?.view.window?.makeKey()
    }
}

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {}
    }
}
