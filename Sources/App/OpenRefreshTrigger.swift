import ClaudeUsageBarLib

/// Marks the UI as loading and runs an immediate data refresh when the UI is opened.
@MainActor
struct OpenRefreshTrigger {
    let settings: AppSettings
    let refreshCoordinator: DataRefreshCoordinator

    func fire() {
        settings.isLoading = true
        refreshCoordinator.refreshNow {
            settings.isLoading = false
        }
    }
}
