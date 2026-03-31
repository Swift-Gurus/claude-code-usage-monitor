import Foundation

public enum StatuslineInstaller {
    private static let defaultClaudeDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
    private static let claudeDir = defaultClaudeDir
    private static let settingsURL = claudeDir.appendingPathComponent("settings.json")
    private static let defaultScriptURL = claudeDir.appendingPathComponent("statusline-command.sh")

    private static let trackingVersion = "v2"  // bump when snippet changes
    private static let trackingMarker = "# --- ClaudeUsageBar tracking v2 ---"
    private static let trackingEndMarker = "# --- end ClaudeUsageBar tracking ---"
    private static let legacyMarker = "# --- ClaudeUsageBar tracking ---"  // v1 marker for upgrade detection

    private static let trackingSnippet = #"""
    # --- ClaudeUsageBar tracking v2 ---
    _CUB_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    _CUB_LA=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
    _CUB_LR=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
    _CUB_MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
    _CUB_AGENT=$(echo "$input" | jq -r '.agent.name // ""')
    _CUB_CTX=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
    _CUB_CTXWIN=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
    _CUB_WDIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')
    _CUB_SID=$(echo "$input" | jq -r '.session_id // ""')
    _CUB_DUR=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
    _CUB_ADUR=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
    _CUB_RL5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
    _CUB_RL5R=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
    _CUB_RL7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
    _CUB_RL7R=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
    _CUB_DIR="$HOME/.claude/usage"
    _CUB_TODAY=$(date +%Y-%m-%d)
    mkdir -p "$_CUB_DIR/$_CUB_TODAY"
    echo "$_CUB_COST $_CUB_LA $_CUB_LR $_CUB_MODEL" > "$_CUB_DIR/$_CUB_TODAY/$PPID.dat"
    _CUB_MF="$_CUB_DIR/$_CUB_TODAY/$PPID.models"
    _CUB_PREV=""; [ -f "$_CUB_MF" ] && _CUB_PREV=$(tail -1 "$_CUB_MF" | cut -f4-)
    [ "$_CUB_PREV" != "$_CUB_MODEL" ] && printf '%s\t%s\t%s\t%s\n' "$_CUB_COST" "$_CUB_LA" "$_CUB_LR" "$_CUB_MODEL" >> "$_CUB_MF"
    _CUB_RL=""
    [ -n "$_CUB_RL5H" ] && _CUB_RL="\"five_hour\":{\"used_pct\":$_CUB_RL5H,\"resets_at\":${_CUB_RL5R:-0}}"
    [ -n "$_CUB_RL7D" ] && { [ -n "$_CUB_RL" ] && _CUB_RL="$_CUB_RL,"; _CUB_RL="${_CUB_RL}\"seven_day\":{\"used_pct\":$_CUB_RL7D,\"resets_at\":${_CUB_RL7R:-0}}"; }
    [ -n "$_CUB_RL" ] && _CUB_RL=",\"rate_limits\":{$_CUB_RL}"
    cat > "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json.tmp" <<_CUB_EOF
    {"pid":$PPID,"model":"$_CUB_MODEL","agent_name":"$_CUB_AGENT","context_pct":$_CUB_CTX,"context_window":$_CUB_CTXWIN,"cost":$_CUB_COST,"lines_added":$_CUB_LA,"lines_removed":$_CUB_LR,"working_dir":"$_CUB_WDIR","session_id":"$_CUB_SID","duration_ms":$_CUB_DUR,"api_duration_ms":$_CUB_ADUR,"updated_at":$(date +%s)$_CUB_RL}
    _CUB_EOF
    mv "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json.tmp" "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json"
    # --- end ClaudeUsageBar tracking ---
    """#

    public static var isInstalled: Bool {
        isInstalled(claudeDir: claudeDir.path)
    }

    /// True when an older tracking version exists and needs replacing.
    public static var needsUpgrade: Bool {
        needsUpgrade(claudeDir: claudeDir.path)
    }

    private static func needsUpgrade(claudeDir: String) -> Bool {
        guard let scriptPath = scriptPath(forClaudeDir: claudeDir),
              let content = try? String(contentsOfFile: scriptPath, encoding: .utf8)
        else { return false }
        // Has old marker but not current version marker
        return content.contains(legacyMarker) && !content.contains(trackingMarker)
    }

    @discardableResult
    public static func install() -> Bool {
        install(claudeDir: claudeDir.path)
    }

    // MARK: - Private

    /// Install the full bundled script and configure settings.json
    private static func installFreshScript() -> Bool {
        installFreshScript(claudeDir: claudeDir.path)
    }

    private static func installFreshScript(claudeDir: String) -> Bool {
        let fm = FileManager.default
        let claudeURL = URL(fileURLWithPath: claudeDir)
        let scriptURL = claudeURL.appendingPathComponent("statusline-command.sh")
        let settingsURL = claudeURL.appendingPathComponent("settings.json")

        guard let bundledURL = Bundle.module.url(
            forResource: "statusline-command", withExtension: "sh"
        ) else {
            print("Bundled statusline-command.sh not found")
            return false
        }

        do {
            try fm.createDirectory(at: claudeURL, withIntermediateDirectories: true)
            if fm.fileExists(atPath: scriptURL.path) {
                try fm.removeItem(at: scriptURL)
            }
            // Read bundled script and replace the usage dir path
            var scriptContent = try String(contentsOf: bundledURL, encoding: .utf8)
            // Replace hardcoded $HOME/.claude/usage with the account's usage dir
            let usageDirPath = claudeURL.appendingPathComponent("usage").path
            scriptContent = scriptContent.replacingOccurrences(
                of: "$HOME/.claude/usage",
                with: usageDirPath
            )
            try scriptContent.write(toFile: scriptURL.path, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
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
                "command": "sh \(scriptURL.path)"
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

    // MARK: - Multi-Account Support

    /// Check if statusline is installed for a specific account with current snippet version.
    public static func isInstalled(claudeDir: String) -> Bool {
        guard let scriptPath = scriptPath(forClaudeDir: claudeDir),
              let content = try? String(contentsOfFile: scriptPath, encoding: .utf8)
        else { return false }
        return content.contains(trackingMarker)
    }

    /// Resolve the script path from a claude dir's settings.json.
    private static func scriptPath(forClaudeDir claudeDir: String) -> String? {
        let settingsURL = URL(fileURLWithPath: claudeDir).appendingPathComponent("settings.json")
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

    /// Install statusline for a specific account's .claude directory.
    @discardableResult
    public static func install(claudeDir: String) -> Bool {
        guard !isInstalled(claudeDir: claudeDir) else { return true }

        let claudeURL = URL(fileURLWithPath: claudeDir)
        let usageDir = claudeURL.appendingPathComponent("usage").path

        // Check if we need to upgrade an existing script
        if needsUpgrade(claudeDir: claudeDir),
           let path = scriptPath(forClaudeDir: claudeDir) {
            return upgradeTracking(in: path, usageDir: usageDir)
        }

        // Check if there's already a custom script without any tracking
        if let path = scriptPath(forClaudeDir: claudeDir),
           FileManager.default.fileExists(atPath: path) {
            return injectTracking(into: path, usageDir: usageDir)
        }

        // No existing script — install fresh
        return installFreshScript(claudeDir: claudeDir)
    }

    /// Replace old tracking block with current version.
    private static func upgradeTracking(in path: String, usageDir: String) -> Bool {
        do {
            var content = try String(contentsOfFile: path, encoding: .utf8)

            // Remove old tracking block (between legacy/current marker and end marker)
            for marker in [legacyMarker, trackingMarker] {
                if let startRange = content.range(of: marker),
                   let endRange = content.range(of: trackingEndMarker) {
                    var endIdx = endRange.upperBound
                    if endIdx < content.endIndex && content[endIdx] == "\n" {
                        endIdx = content.index(after: endIdx)
                    }
                    content.removeSubrange(startRange.lowerBound..<endIdx)
                    break
                }
            }

            // Inject current version
            let customSnippet = trackingSnippet.replacingOccurrences(
                of: "$HOME/.claude/usage",
                with: usageDir
            )

            if let range = content.range(of: "input=$(cat)") {
                let insertionPoint = content[range.upperBound...].hasPrefix("\n")
                    ? content.index(range.upperBound, offsetBy: 1)
                    : range.upperBound
                content.insert(contentsOf: "\n" + customSnippet + "\n", at: insertionPoint)
            } else {
                content += "\n" + customSnippet + "\n"
            }

            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to upgrade tracking in \(path): \(error)")
            return false
        }
    }

    /// Install statusline for all configured accounts.
    @discardableResult
    public static func installAll(accounts: [Account]) -> Bool {
        var allSuccess = true
        for account in accounts {
            if !isInstalled(claudeDir: account.claudeDir) {
                let success = install(claudeDir: account.claudeDir)
                if !success { allSuccess = false }
            }
        }
        return allSuccess
    }

    /// Inject tracking snippet with a custom usage directory path.
    private static func injectTracking(into path: String, usageDir: String) -> Bool {
        do {
            var content = try String(contentsOfFile: path, encoding: .utf8)
            guard !content.contains(trackingMarker) else { return true }

            // Build a customized tracking snippet with the right usage dir
            let customSnippet = trackingSnippet.replacingOccurrences(
                of: "$HOME/.claude/usage",
                with: usageDir
            )

            if let range = content.range(of: "input=$(cat)") {
                let insertionPoint = content[range.upperBound...].hasPrefix("\n")
                    ? content.index(range.upperBound, offsetBy: 1)
                    : range.upperBound
                content.insert(contentsOf: "\n" + customSnippet + "\n", at: insertionPoint)
            } else {
                let preamble = """
                input=$(cat)
                \(customSnippet)
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
}
