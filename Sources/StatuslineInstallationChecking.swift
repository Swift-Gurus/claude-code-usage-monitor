/**
 solid-name: StatuslineInstallationChecking
 solid-category: abstraction
 solid-description: Contract for checking whether the statusline is installed for an account.
 */
protocol StatuslineInstallationChecking {
    func isInstalled(claudeDir: String) -> Bool
}

/**
 solid-name: DefaultStatuslineInstallationChecker
 solid-category: service
 solid-description: Checks whether the statusline is installed for an account.
 */
struct DefaultStatuslineInstallationChecker: StatuslineInstallationChecking {
    func isInstalled(claudeDir: String) -> Bool {
        StatuslineInstaller.isInstalled(claudeDir: claudeDir)
    }
}