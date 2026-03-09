# Error Handling Specification

## Overview

ClaudeUsageBar uses a uniform error handling strategy: **silent failure with graceful fallback**. There is no centralized error reporter, no user-visible error dialogs (except for the statusline install failure), and no error logging. Every operation that can fail uses `try?` or `guard let ... else { continue/return }` to discard errors silently. Missing data produces a zero contribution to stats rather than an error state.

This design choice prioritizes stability and simplicity: the worst outcome of any failure is that some usage data is temporarily missing from the display, which self-corrects on the next reload.

---

## Global Strategy

- `try?` is used everywhere a `throws` function is called. The `?` converts a thrown error into `nil`, which is then handled by optional chaining or a default value.
- `guard let ... else { continue }` is the standard pattern inside loops — a failure on one file/entry skips that entry without aborting the loop.
- `guard let ... else { return [:] / return nil / return [] }` is used in function bodies where a precondition fails.
- No `catch` blocks exist anywhere in the codebase. There is no error propagation chain.
- No crash reporting framework. No `os_log` error logging. All failures are completely silent.

---

## File I/O Failures

### .dat File Read Failure

Location: `UsageData.collectEntries(under:source:since:)`

```swift
guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
```

A `.dat` file that cannot be read (permissions error, I/O error, file deleted between listing and reading) is silently skipped. It produces zero contribution to the period stats for that PID. On the next `reload()`, if the file reappears, it will be picked up normally.

### Directory Listing Failure

Location: `UsageData.collectEntries`, `AgentTracker.reload`, `CommanderSupport.cleanupDeadPIDs`

```swift
guard let dateDirs = try? fm.contentsOfDirectory(at: root, ...) else { return }
guard let files = try? fm.contentsOfDirectory(at: dateDir, ...) else { continue }
```

If the root usage directory or a date subdirectory cannot be listed (directory does not exist, permissions), the function returns early with no entries. The app shows zero stats, which is correct for a freshly installed system with no usage history.

### Subagents Directory Missing

Location: `AgentTracker.writeSubagentFiles`, `JSONLParser.parseSubagents(in:)`, `JSONLParser.parseSubagentDetails(in:)`

```swift
guard let attrs = try? fm.attributesOfItem(atPath: subagentsDir.path),
      let mtime = attrs[.modificationDate] as? Date else { continue }
```

```swift
guard let files = try? fm.contentsOfDirectory(at: dir, ...) else { return [:] }
guard let files = try? fm.contentsOfDirectory(at: dir, ...) else { return [] }
```

If the subagents directory does not exist (agent has no subagents, or session is new), the functions return empty collections. `AgentTracker` skips subagent scanning for that agent. `SubagentDetailView` loads nothing and shows "No subagents recorded".

### File Write Failure

Location: `AgentTracker.writeSubagentFiles`, `CommanderSupport.writeAgentData`

```swift
try? data.write(to: ..., options: .atomic)
try? datContent.write(to: ..., atomically: true, encoding: .utf8)
```

If a file write fails (disk full, permissions), the failure is silently ignored. The next `reload()` cycle will retry writing. Missing `.subagents.json` means subagent costs are not included in the stats for that reload; missing `.dat` means Commander session cost is not reflected.

---

## JSON Decode Failures

### .agent.json Decode Failure

Location: `AgentTracker.reload()`

```swift
guard let data = try? Data(contentsOf: file),
      let json = try? decoder.decode(AgentFileData.self, from: data)
else { continue }
```

A malformed or partially-written `.agent.json` file is silently skipped. The PID is not tracked in `activeAgents`. On the next `reload()`, if the file is valid (e.g., a concurrent write completed), it will be decoded successfully.

### .subagents.json Decode Failure

Location: `UsageData.collectEntries`

```swift
if let subData = try? Data(contentsOf: subagentsFile),
   let subMap = try? JSONDecoder().decode([String: SourceModelStats].self, from: subData),
   !subMap.isEmpty {
    subagents["\(pid)\t\(source.rawValue)"] = subMap
}
```

A malformed `.subagents.json` produces no entry in the `subagentStats` map. The parent session's cost still appears correctly; only the subagent model breakdown is missing.

### JSONL Line Decode Failure

Location: `JSONLParser.parseSession`, `JSONLParser.parseSubagents`, `JSONLParser.parseSubagentDetails`

```swift
guard let lineData = line.data(using: .utf8),
      let entry = try? decoder.decode(JSONLEntry.self, from: lineData)
else { continue }
```

Individual malformed JSONL lines are skipped via `guard/continue`. The session still produces partial results from the lines that were parsed successfully. This handles truncated lines at the end of a file being written incrementally.

---

## Process Spawn Failures

### runCommand / ps / lsof Failures

Location: `SessionScanner.findActiveSessions()` (via `CommanderSupport.refreshFiles()`)

The `runCommand` helper used by `SessionScanner` returns `nil` if the process cannot be launched or its output cannot be decoded:

```swift
guard let psOutput = runCommand("/bin/ps", ["-e", "-o", "pid,ppid,comm"]) else { return [:] }
guard let lsofOutput = runCommand("/usr/sbin/lsof", ...) else { ... }
```

If `ps` fails to execute, `findActiveSessions()` returns an empty dictionary — no Commander sessions are discovered, and the app shows no Commander agents. This is the correct fallback: the ps failure is transient, and the next 5-second poll will retry.

If `lsof` fails, working directories cannot be determined for the discovered PIDs, so those sessions are skipped individually.

### CPU Usage ps Failure

Location: `AgentTracker.cpuUsage(for:)`

```swift
do {
    try process.run()
    process.waitUntilExit()
    ...
    return Double(output) ?? 0
} catch {
    return 0
}
```

If the `ps` invocation for CPU usage throws (binary not found, launch failure) or returns unparseable output, `cpuUsage(for:)` returns `0.0`. The agent is treated as having 0% CPU, which makes it eligible for idle classification. This is a safe fallback: a live agent temporarily showing as idle is less problematic than a crash.

---

## JSONL Parse Failures

### Malformed Lines

Individual JSONL lines that fail UTF-8 encoding or JSON decoding are skipped via `guard/continue` (see JSON Decode Failures above). The session produces results from the remaining valid lines.

### guard totalOutput > 0

Location: `JSONLParser.parseSession`

```swift
guard totalOutput > 0 else { return nil }
```

If no assistant messages with output token counts were found (e.g., the file contains only user messages, or every line failed to decode), `parseSession` returns `nil`. `CommanderSupport.writeAgentData` skips sessions where parsing returns `nil`. This prevents phantom zero-cost sessions from appearing in the UI.

### guard !usageByMsgID.isEmpty

Location: `JSONLParser.parseSubagentDetails`

```swift
guard !usageByMsgID.isEmpty else { continue }
```

Subagent files with no valid assistant messages are skipped entirely. They do not appear in the `SubagentDetailView` list.

---

## verifyClaudePIDs Failure

Location: `AgentTracker.verifyClaudePIDs(_:)`

```swift
private static func verifyClaudePIDs(_ pids: [Int]) -> Set<Int> {
    guard !pids.isEmpty else { return [] }
    let pidArg = pids.map(String.init).joined(separator: ",")
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-p", pidArg, "-o", "pid=,comm="]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // ... parse output, return PIDs whose comm contains "claude"
        return result
    } catch {
        // If ps fails, assume all PIDs are valid (fail open)
        return Set(pids)
    }
}
```

This function runs a single `/bin/ps` call to verify that candidate PIDs are actually `claude` processes (guards against PID reuse by non-claude processes). If the `ps` invocation fails for any reason (`Process.run()` throws, `/bin/ps` not found, etc.), the function **fails open** — it returns the full set of input PIDs, treating all candidates as valid. This means that in the rare event of a `ps` failure, a PID that has been reused by a non-claude process would not be cleaned up, but the app would not crash or lose track of legitimate agents.

---

## PID Liveness (kill(pid, 0))

Location: `AgentTracker.reload()`, `CommanderSupport.cleanupDeadPIDs`

```swift
guard kill(pid32, 0) == 0 else {
    try? fm.removeItem(at: file)
    continue
}
```

`kill(pid, 0)` failing (returning non-zero) means the process is dead (ESRCH) or inaccessible. The `.agent.json` file is removed to prevent it from reappearing in future reloads. The removal itself uses `try?` — if the removal fails (e.g., the file was already removed by another cleanup cycle), the error is silently ignored.

`.dat` files are intentionally NOT removed when a PID is found dead — they preserve the historical cost record.

---

## Missing Subagents Directory

Location: `AgentTracker.writeSubagentFiles`

```swift
guard let attrs = try? fm.attributesOfItem(atPath: subagentsDir.path),
      let mtime = attrs[.modificationDate] as? Date else { continue }
```

If the subagents directory does not exist (agent has not spawned any subagents), `attributesOfItem` throws `NSFileNoSuchFile`, which becomes `nil` via `try?`. The agent is skipped in the subagent scanning loop and no `.subagents.json` is written for it. `SubagentDetailView.loadFromFile()` finds no data and the view shows "No subagents recorded".

---

## Missing .subagent-details.json

Location: `SubagentDetailView.loadFromFile()`

The `loadFromFile()` function attempts to read and decode the `.subagent-details.json` file:

```swift
guard let data = try? Data(contentsOf: detailsURL),
      let decoded = try? JSONDecoder().decode([SubagentInfo].self, from: data)
else { /* leave subagents array empty */ return }
```

If the file does not exist or fails to decode, the `subagents` array remains empty. The `SubagentDetailView` shows "No subagents recorded" in this case — an empty state, not an error state.

---

## StatuslineInstaller Failure

Location: `StatuslineInstaller.install()`, called from `AppDelegate.applicationDidFinishLaunching`

```swift
@discardableResult
public static func install() -> Bool {
    // Returns false on failure
}
```

`install()` returns `Bool` — `false` indicates that installation could not be completed. The most common cause is `jq` not being installed (the shell scripts depend on `jq` for JSON parsing).

When `install()` returns `false`:
- `AppDelegate` sets `settings.installError = true`
- `PopoverView` displays `"Install failed — check jq is installed"` in a warning banner
- The app remains fully functional for Commander sessions; only CLI (statusline) tracking is affected
- No crash, no alert dialog, no termination

If `jq` is later installed and the user manually triggers reinstall, `install()` will succeed and `installError` will be cleared.

---

## UserDefaults Invalid Value

Location: `AppSettings` property observers

```swift
var statusBarPeriod: StatusBarPeriod {
    get { StatusBarPeriod(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .day }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
}
```

If `UserDefaults` returns a string that does not correspond to a valid enum rawValue (e.g., the stored value was written by a previous version), the `?? .default` fallback provides the default enum case. This pattern is used uniformly across all enum-backed settings: `StatusBarPeriod` (default `.day`), `AgentSortOrder` (default `.recentlyUpdated`), `SubagentContextBudget` (default `.m1`), `SubagentSortOrder` (default `.cost`), `DisplayMode` (default `.popover`), and `AppearanceMode` (default `.system`). For Bool settings (`expandThinking`, `expandTools`), `UserDefaults.standard.object(forKey:) as? Bool ?? false` provides the fallback. The invalid stored value is left in `UserDefaults` until the user changes the setting and writes a valid value.

---

## Context Window Division by Zero

Location: `JSONLParser.parseSession`

```swift
let contextPct = resolved.contextWindowSize > 0
    ? min(100, Int(Double(lastInputTokens) / Double(resolved.contextWindowSize) * 100))
    : 0
```

The `> 0` guard prevents division by zero. In practice, all `ClaudeModel` cases have a non-zero `contextWindowSize`, so this guard is purely defensive.

---

## Negative Cost / Line Deltas

Location: `UsageData.incrementalEntry`

```swift
func incrementalEntry(latest: DatEntry, previous: DatEntry) -> DatEntry {
    DatEntry(
        cost:        max(0, latest.cost - previous.cost),
        linesAdded:  max(0, latest.linesAdded - previous.linesAdded),
        linesRemoved: max(0, latest.linesRemoved - previous.linesRemoved),
        ...
    )
}
```

If a later `.dat` file has lower values than an earlier one (possible due to file corruption, time zone shifts, or manual edits), the `max(0, ...)` clamp prevents negative stats from appearing in the UI. Negative deltas are treated as zero — the period shows no cost/lines for that segment rather than corrupting the total.

The same pattern appears in `modelBreakdown()`:

```swift
let dc  = max(0, nextCost - current.cost)
let dla = max(0, nextLA - current.la)
let dlr = max(0, nextLR - current.lr)
```

---

## Summary Table

| Failure scenario | Location | Handling | User-visible effect |
|-----------------|----------|----------|---------------------|
| `.dat` file unreadable | `UsageData.collectEntries` | `guard ... else { continue }` | Session missing from stats |
| `.agent.json` unreadable | `AgentTracker.reload` | `guard ... else { continue }` | Agent missing from list |
| `.agent.json` malformed JSON | `AgentTracker.reload` | `try? decoder.decode` → `nil` → skip | Agent missing from list |
| `.subagents.json` malformed | `UsageData.collectEntries` | `try? decoder.decode` → `nil` → skip | Subagent model breakdown missing |
| JSONL line malformed | `JSONLParser.*` | `guard ... else { continue }` | Partial session data |
| JSONL no output tokens | `JSONLParser.parseSession` | `guard totalOutput > 0 else { return nil }` | Commander session not shown |
| `ps` launch failure (Commander) | `SessionScanner` | `guard let ... else { return [:] }` | No Commander agents shown |
| `ps` CPU query failure | `AgentTracker.cpuUsage` | `catch { return 0 }` | Agent may show as idle |
| `ps` PID verification failure | `AgentTracker.verifyClaudePIDs` | `catch { return Set(pids) }` | Non-claude PIDs not cleaned up |
| `lsof` failure | `SessionScanner` | skip affected PIDs | Those Commander sessions not shown |
| `kill(pid, 0)` failure | `AgentTracker.reload`, `cleanupDeadPIDs` | remove `.agent.json`, skip | Agent removed from list |
| Subagents dir missing | `AgentTracker.writeSubagentFiles` | `guard ... else { continue }` | "No subagents recorded" |
| `.subagent-details.json` missing | `SubagentDetailView.loadFromFile` | `guard ... else { return }` | "No subagents recorded" |
| JSONL file for log viewer | `LogParser.parseMessages` | `guard ... else { return [] }` | "No messages found" |
| JSONL mtime check failure | `LogViewerView.loadMessages` | `try?` on attributesOfItem | Skips mtime cache, re-parses |
| File write failure | `AgentTracker`, `CommanderSupport` | `try? data.write(...)` | Missing until next reload |
| `jq` not installed / install fail | `StatuslineInstaller.install` | returns `false` | Warning banner in popover |
| UserDefaults invalid value | `AppSettings` | `?? .defaultCase` fallback | Default setting used |
| Context window = 0 | `JSONLParser.parseSession` | `guard > 0 else { 0 }` | Context % shows 0 |
| Negative cost/line delta | `UsageData.incrementalEntry` | `max(0, ...)` | Delta treated as 0 |
