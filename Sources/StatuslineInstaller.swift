import Foundation

enum StatuslineInstaller {
    private static let claudeDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
    private static let settingsURL = claudeDir.appendingPathComponent("settings.json")
    private static let defaultScriptURL = claudeDir.appendingPathComponent("statusline-command.sh")

    private static let trackingMarker = "# --- ClaudeUsageBar tracking ---"

    private static let trackingSnippet = """
    # --- ClaudeUsageBar tracking ---
    _CUB_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    _CUB_LA=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    _CUB_LR=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    _CUB_DIR="$HOME/.claude/usage"
    _CUB_TODAY=$(date +%Y-%m-%d)
    mkdir -p "$_CUB_DIR/$_CUB_TODAY"
    echo "$_CUB_COST $_CUB_LA $_CUB_LR" > "$_CUB_DIR/$_CUB_TODAY/$PPID.dat"
    # --- end ClaudeUsageBar tracking ---
    """

    /// True when any configured statusline script contains the tracking snippet
    static var isInstalled: Bool {
        guard let scriptPath = currentScriptPath(),
              let content = try? String(contentsOfFile: scriptPath, encoding: .utf8)
        else { return false }
        return content.contains(trackingMarker)
    }

    @discardableResult
    static func install() -> Bool {
        guard !isInstalled else { return true }

        let fm = FileManager.default
        try? fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        if let existingPath = currentScriptPath(),
           fm.fileExists(atPath: existingPath) {
            // Existing script — inject tracking snippet only
            return injectTracking(into: existingPath)
        } else {
            // No statusline at all — install full script + configure settings
            return installFreshScript()
        }
    }

    // MARK: - Private

    /// Read settings.json and resolve the script file path from statusLine.command
    private static func currentScriptPath() -> String? {
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusLine = json["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String
        else { return nil }

        // Extract file path from command like "sh /path/to/script.sh" or just "/path/to/script.sh"
        let parts = command.split(separator: " ", maxSplits: 10).map(String.init)
        for part in parts.reversed() {
            let expanded = NSString(string: part).expandingTildeInPath
            if expanded.hasSuffix(".sh") {
                return expanded
            }
        }
        return nil
    }

    /// Inject just the tracking snippet into an existing script
    private static func injectTracking(into path: String) -> Bool {
        do {
            var content = try String(contentsOfFile: path, encoding: .utf8)
            guard !content.contains(trackingMarker) else { return true }

            // Inject after `input=$(cat)` if present, otherwise append at end
            if let range = content.range(of: "input=$(cat)") {
                let insertionPoint = content[range.upperBound...].hasPrefix("\n")
                    ? content.index(range.upperBound, offsetBy: 1)
                    : range.upperBound
                content.insert(contentsOf: "\n" + trackingSnippet + "\n", at: insertionPoint)
            } else {
                // Script doesn't read stdin with input=$(cat) — prepend reading + tracking
                let preamble = """
                input=$(cat)
                \(trackingSnippet)
                """
                // Insert after shebang line if present
                if content.hasPrefix("#!") {
                    if let newline = content.firstIndex(of: "\n") {
                        let next = content.index(after: newline)
                        content.insert(contentsOf: "\n" + preamble + "\n", at: next)
                    }
                } else {
                    content = preamble + "\n" + content
                }
            }

            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to inject tracking into \(path): \(error)")
            return false
        }
    }

    /// Install the full bundled script and configure settings.json
    private static func installFreshScript() -> Bool {
        let fm = FileManager.default

        guard let bundledURL = Bundle.module.url(
            forResource: "statusline-command", withExtension: "sh"
        ) else {
            print("Bundled statusline-command.sh not found")
            return false
        }

        do {
            if fm.fileExists(atPath: defaultScriptURL.path) {
                try fm.removeItem(at: defaultScriptURL)
            }
            try fm.copyItem(at: bundledURL, to: defaultScriptURL)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: defaultScriptURL.path)
        } catch {
            print("Failed to install statusline script: \(error)")
            return false
        }

        // Add statusLine to settings.json
        do {
            var json: [String: Any] = [:]
            if fm.fileExists(atPath: settingsURL.path),
               let data = try? Data(contentsOf: settingsURL),
               let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = existing
            }

            json["statusLine"] = [
                "type": "command",
                "command": "sh \(defaultScriptURL.path)"
            ] as [String: String]

            let data = try JSONSerialization.data(
                withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("Failed to update settings.json: \(error)")
            return false
        }

        return true
    }
}