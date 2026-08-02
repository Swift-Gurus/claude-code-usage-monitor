import Foundation

/// Installs the statusline script into an account's `.claude` directory.
protocol StatuslineInstalling {
    func install(claudeDir: String) -> Bool
}

struct DefaultStatuslineInstaller: StatuslineInstalling {
    func install(claudeDir: String) -> Bool {
        StatuslineInstaller.install(claudeDir: claudeDir)
    }
}
