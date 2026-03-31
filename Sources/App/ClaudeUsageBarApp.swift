import AppKit
import ClaudeUsageBarLib
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private var window: NSWindow?
    private let settings = AppSettings()
    private lazy var usageData = UsageData(accounts: settings.accounts)
    private lazy var agentTracker = AgentTracker(accounts: settings.accounts)
    private let sessionManager: SessionManager = {
        let logger = FileDebugLogger()
        logger.isEnabled = true
        return SessionManager(logger: logger)
    }()
    private var monitor: UsageMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        StatuslineInstaller.installAll(accounts: settings.accounts)
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
        monitor = UsageMonitor(accounts: settings.accounts) { [weak self] in
            self?.scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        let currentAccounts = settings.accounts
        refreshQueue.async { [weak self] in
            guard let self else { return }
            CommanderSupport.refreshFiles(accounts: currentAccounts)
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
        if let accountID = settings.statusBarAccountID,
           let accountStats = usageData.byAccount[accountID] {
            switch period {
            case .day: stats = accountStats.day
            case .week: stats = accountStats.week
            case .month: stats = accountStats.month
            }
        } else {
            switch period {
            case .day: stats = usageData.day
            case .week: stats = usageData.week
            case .month: stats = usageData.month
            }
        }

        // Show account name prefix when filtering to a specific account and multiple exist
        let accountPrefix: String
        if settings.accounts.count > 1,
           let accountID = settings.statusBarAccountID,
           let account = settings.accounts.first(where: { $0.id == accountID }) {
            accountPrefix = "\(account.displayName) "
        } else {
            accountPrefix = ""
        }

        // For Pro/Max accounts with rate limit data, show rate limit % instead of cost
        if let accountID = settings.statusBarAccountID,
           let rl = agentTracker.activeAgents
               .first(where: { $0.accountID == accountID && $0.rateLimits?.hasData == true })?
               .rateLimits,
           let fiveH = rl.fiveHour?.usedPercentage {
            let weekPct = rl.sevenDay?.usedPercentage.map { String(format: " W:%.0f%%", $0) } ?? ""
            button.title = "\(accountPrefix)5h:\(String(format: "%.0f", fiveH))%\(weekPct)"
        } else {
            button.title = "\(accountPrefix)\(period.prefix): " + String(format: "$%.2f", stats.cost)
        }
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
        observeAccounts()
    }

    private func observeAccounts() {
        withObservationTracking {
            _ = self.settings.accounts
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.usageData.accounts = self.settings.accounts
                self.agentTracker.accounts = self.settings.accounts
                self.monitor?.updateAccounts(self.settings.accounts)
                self.scheduleRefresh()
                self.observeAccounts()
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
            let currentAccounts = settings.accounts
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                CommanderSupport.refreshFiles(accounts: currentAccounts)
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
            let currentAccounts = settings.accounts
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                CommanderSupport.refreshFiles(accounts: currentAccounts)
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
