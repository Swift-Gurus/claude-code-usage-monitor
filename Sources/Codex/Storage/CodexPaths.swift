import Foundation

struct CodexPaths {
    let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) {
        self.homeDirectory = homeDirectory
    }

    var homePath: String { homeDirectory.path }
    var sessionsDirectory: URL { homeDirectory.appendingPathComponent("sessions") }
    var sessionIndexURL: URL { homeDirectory.appendingPathComponent("session_index.jsonl") }
    var stateDatabaseURL: URL { homeDirectory.appendingPathComponent("state_5.sqlite") }
}
