import ClaudeUsageBarLib

/// Notifies its owner whenever the tracked settings (status-bar period, account list) change.
@MainActor
final class SettingsObserver {
    private let periodObservation: RepeatingObservation<StatusBarPeriod>
    private let accountsObservation: RepeatingObservation<[Account]>

    init(periodObservation: RepeatingObservation<StatusBarPeriod>, accountsObservation: RepeatingObservation<[Account]>) {
        self.periodObservation = periodObservation
        self.accountsObservation = accountsObservation
    }

    func start() {
        periodObservation.start()
        accountsObservation.start()
    }
}
