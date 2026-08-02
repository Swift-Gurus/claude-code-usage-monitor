import ClaudeUsageBarLib
import SwiftUI

/// Constructs and wires together the app's dependency graph. `AppDelegate` is
/// framework-instantiated with a no-argument init, so this is where dependency
/// construction happens instead.
struct AppAssembler {
    @MainActor
    func assemble() -> AppDependencies {
        let settings = AppSettings()
        StatuslineInstaller.installAll(accounts: settings.accounts)

        let logger = FileDebugLogger()
        logger.isEnabled = true
        let sessionManager = SessionManager(logger: logger)

        let dataStore = RefreshDataStore(
            usageData: UsageData(accounts: settings.accounts),
            agentTracker: AgentTracker(accounts: settings.accounts)
        )
        let refreshCoordinator = DataRefreshCoordinator(dataStore: dataStore) { onTick in
            UsageMonitor(accounts: settings.accounts, onChange: onTick)
        }

        let rootView = PopoverViewFactory.make(
            data: dataStore.usageData, agentTracker: dataStore.agentTracker,
            settings: settings, sessionManager: sessionManager
        )
        let openRefreshTrigger = OpenRefreshTrigger(settings: settings, refreshCoordinator: refreshCoordinator)
        let uiController: AnyStatusBarController
        if settings.displayMode == .window {
            let controller = StatusBarUIController(
                statusItem: MenuBarStatusItem(), openRefreshTrigger: openRefreshTrigger,
                rootView: rootView, presenter: WindowRootPresenter()
            )
            uiController = AnyStatusBarController(controller)
        } else {
            let controller = StatusBarUIController(
                statusItem: MenuBarStatusItem(), openRefreshTrigger: openRefreshTrigger,
                rootView: rootView, presenter: PopoverRootPresenter()
            )
            uiController = AnyStatusBarController(controller)
        }

        let refreshTitle = {
            uiController.updateTitle(
                StatusItemTitleFormatter(settings: settings, usageData: dataStore.usageData, agentTracker: dataStore.agentTracker).title
            )
        }
        let settingsObserver = SettingsObserver(
            periodObservation: RepeatingObservation(read: { settings.statusBarPeriod }, onChange: { _ in refreshTitle() }),
            accountsObservation: RepeatingObservation(read: { settings.accounts }, onChange: { accounts in
                refreshCoordinator.updateAccounts(accounts)
                refreshCoordinator.scheduleRefresh(completion: refreshTitle)
            })
        )

        return AppDependencies(
            settings: settings, refreshCoordinator: refreshCoordinator,
            uiController: uiController, settingsObserver: settingsObserver, refreshTitle: refreshTitle
        )
    }
}
