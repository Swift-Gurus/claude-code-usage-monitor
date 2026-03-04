import Foundation

enum StatuslineInstaller {
    private static let claudeDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
    private static let settingsURL = claudeDir.appendingPathComponent("settings.json")
    private static let defaultScriptURL = claudeDir.appendingPathComponent("statusline-command.sh")

    private static let trackingMarker = "# --- ClaudeUsageBar tracking ---"
    private static let trackingEndMarker = "# --- end ClaudeUsageBar tracking ---"

    private static let trackingSnippet = #"""
    # --- ClaudeUsageBar tracking ---
    _CUB_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    _CUB_LA=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    _CUB_LR=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    _CUB_MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
    _CUB_AGENT=$(echo "$input" | jq -r '.agent.name // ""')
    _CUB_CTX=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
    _CUB_WDIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')
    _CUB_SID=$(echo "$input" | jq -r '.session_id // ""')
    _CUB_DIR="$HOME/.claude/usage"
    _CUB_TODAY=$(date +%Y-%m-%d)
    mkdir -p "$_CUB_DIR/$_CUB_TODAY"
    echo "$_CUB_COST $_CUB_LA $_CUB_LR" > "$_CUB_DIR/$_CUB_TODAY/$PPID.dat"
    cat > "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json.tmp" <<_CUB_EOF
    {"pid":$PPID,"model":"$_CUB_MODEL","agent_name":"$_CUB_AGENT","context_pct":$_CUB_CTX,"cost":$_CUB_COST,"lines_added":$_CUB_LA,"lines_removed":$_CUB_LR,"working_dir":"$_CUB_WDIR","session_id":"$_CUB_SID","updated_at":$(date +%s)}
    _CUB_EOF
    mv "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json.tmp" "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json"
    # --- end ClaudeUsageBar tracking ---
    """#

    /// True when the configured statusline script contains the tracking snippet with agent support
    static var isInstalled: Bool {
        guard let scriptPath = currentScriptPath(),
              let content = try? String(contentsOfFile: scriptPath, encoding: .utf8)
        else { return false }
        return content.contains(trackingMarker) && content.contains(".agent.json")
    }

    /// True when old tracking exists but lacks agent.json support
    static var needsUpgrade: Bool {
        guard let scriptPath = currentScriptPath(),
              let content = try? String(contentsOfFile: scriptPath, encoding: .utf8)
        else { return false }
        return content.contains(trackingMarker) && !content.contains(".agent.json")
    }

    @discardableResult
    static func install() -> Bool {
        guard !isInstalled else { return true }

        let fm = FileManager.default
        try? fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        if needsUpgrade {
            return upgrade()
        }

        if let existingPath = currentScriptPath(),
           fm.fileExists(atPath: existingPath) {
            return injectTracking(into: existingPath)
        } else {
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

        let parts = command.split(separator: " ", maxSplits: 10).map(String.init)
        for part in parts.reversed() {
            let expanded = NSString(string: part).expandingTildeInPath
            if expanded.hasSuffix(".sh") {
                return expanded
            }
        }
        return nil
    }

    /// Replace old tracking block with new one that includes .agent.json
    private static func upgrade() -> Bool {
        guard let scriptPath = currentScriptPath(),
              var content = try? String(contentsOfFile: scriptPath, encoding: .utf8)
        else { return false }

        // Remove old tracking block
        if let startRange = content.range(of: trackingMarker),
           let endRange = content.range(of: trackingEndMarker) {
            // Include the trailing newline if present
            var endIdx = endRange.upperBound
            if endIdx < content.endIndex && content[endIdx] == "\n" {
                endIdx = content.index(after: endIdx)
            }
            content.removeSubrange(startRange.lowerBound..<endIdx)
        }

        // Inject new snippet at the same location
        do {
            if let range = content.range(of: "input=$(cat)") {
                let insertionPoint = content[range.upperBound...].hasPrefix("\n")
                    ? content.index(range.upperBound, offsetBy: 1)
                    : range.upperBound
                content.insert(contentsOf: "\n" + trackingSnippet + "\n", at: insertionPoint)
            } else {
                content += "\n" + trackingSnippet + "\n"
            }
            try content.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to upgrade tracking in \(scriptPath): \(error)")
            return false
        }
    }

    /// Inject just the tracking snippet into an existing script
    private static func injectTracking(into path: String) -> Bool {
        do {
            var content = try String(contentsOfFile: path, encoding: .utf8)
            guard !content.contains(trackingMarker) else { return true }

            if let range = content.range(of: "input=$(cat)") {
                let insertionPoint = content[range.upperBound...].hasPrefix("\n")
                    ? content.index(range.upperBound, offsetBy: 1)
                    : range.upperBound
                content.insert(contentsOf: "\n" + trackingSnippet + "\n", at: insertionPoint)
            } else {
                let preamble = """
                input=$(cat)
                \(trackingSnippet)
                """
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
