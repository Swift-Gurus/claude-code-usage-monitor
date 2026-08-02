import ClaudeUsageBarLib

/// The app's fully-wired dependency graph, produced by `AppAssembler`.
@MainActor
struct AppDependencies {
    let settings: AppSettings
    let refreshCoordinator: DataRefreshCoordinator
    let uiController: AnyStatusBarController
    let settingsObserver: SettingsObserver
    let refreshTitle: () -> Void
}
