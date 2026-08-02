import AppKit

/// Prompts for a project directory and spawns a Claude session in it.
struct PopoverProjectOpener {
    let sessionManager: SessionManager

    func openProject() -> AgentInfo? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory to open with Claude"
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bridge = sessionManager.spawn(workingDir: url.path) else { return nil }

        return AgentInfo(
            pid: bridge.childPID, model: "Starting...", agentName: "",
            contextPercent: 0, contextWindow: 0, cost: 0,
            linesAdded: 0, linesRemoved: 0,
            workingDir: url.path, sessionID: "",
            durationMs: 0, apiDurationMs: 0,
            updatedAt: Date().timeIntervalSince1970, cpuUsage: 0,
            isIdle: false, source: .cli
        )
    }
}
