# AgentTracker Specification

## Overview

`AgentTracker.swift` discovers and maintains the list of currently active Claude Code sessions visible to the menu bar app. It reads `.agent.json` files from today's usage directories, checks whether each session's process is still alive, and enriches each entry with live CPU usage. It also scans for subagent data and writes the files that `UsageData` and `SubagentDetailView` read.

`AgentTracker` is `@Observable` — `activeAgents`, `subagentDetails`, and `parentToolCounts` changes trigger re-renders in views that observe them.

---

## Storage Paths

```swift
let usageDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/usage")
```

Two directories are scanned on each `reload()`:

| Directory | Source |
|-----------|--------|
| `~/.claude/usage/YYYY-MM-DD/` | `.cli` — CLI (statusline) sessions |
| `~/.claude/usage/commander/YYYY-MM-DD/` | `.commander` — Commander sessions |

The date used is always today's date formatted as `"yyyy-MM-dd"` in the local calendar.

---

## Observable Properties

In addition to `activeAgents`, `AgentTracker` exposes two more `@Observable` properties that drive reactive UI in `SubagentDetailView` and `PopoverView`:

### subagentDetails: [Int: [SubagentInfo]]

```swift
public var subagentDetails: [Int: [SubagentInfo]] = [:]
```

Keyed by agent PID. Contains the parsed per-subagent detail records for each session that has subagents. Updated in `writeSubagentFiles` whenever the subagents directory mtime changes (same trigger as the `.subagent-details.json` file write). The array is sorted by cost descending (done by `JSONLParser.parseSubagentDetails`).

Consumers: `SubagentDetailView` reads this via `agentTracker.subagentDetails` but currently uses the file-based polling path (`loadFromFile()`) as the primary data source rather than this property directly. The property is maintained for future reactive binding use.

### parentToolCounts: [Int: [String: Int]]

```swift
public var parentToolCounts: [Int: [String: Int]] = [:]
```

Keyed by agent PID. Contains `[toolName: count]` for every `tool_use` entry in the parent session's JSONL file. Populated from the parent JSONL via `JSONLParser.parseParentTools` inside `writeSubagentFiles`. Used directly by `SubagentDetailView` to render the "Tools Used" chip section.

### parentToolCache: [String: (mtime: Date, counts: [String: Int])]

```swift
private var parentToolCache: [String: (mtime: Date, counts: [String: Int])] = [:]
```

Keyed by `sessionID`. Stores the last-seen modification date of the parent JSONL and the corresponding tool counts. Before re-parsing the parent JSONL, `writeSubagentFiles` checks whether the file's current `modificationDate` matches the cached `mtime`. If they match, the cached `counts` are used without re-reading the file. If the mtime has changed, `parseParentTools` is called and the cache is updated.

This cache operates independently of `subagentCache` (which tracks the subagents directory mtime). Both caches key on `sessionID`.

---

## reload() Flow

```
AgentTracker.reload()
  ├── For each source directory (CLI today dir, Commander today dir):
  │   ├── List files in directory
  │   └── For each file ending in ".agent.json":
  │       ├── Decode AgentFileData from file
  │       ├── kill(pid32, 0) — check PID liveness
  │       │   ├── ALIVE: read CPU usage via `ps`
  │       │   └── DEAD:  removeItem(at: file), skip
  │       └── Append AgentInfo to agents[] (isIdle = true initially)
  ├── Build activeWorkDirs = Set of workingDir for agents with cpuUsage >= 1.0
  ├── Check JSONL activity for each agent with sessionID:
  │   ├── Check parent JSONL mtime (< 60s → active)
  │   └── If not: check max subagent JSONL mtime (< 60s → active)
  │   └── Build jsonlActivePIDs set
  ├── Re-evaluate each agent's idle status
  │   └── idle = (cpu < 1.0) AND (not recently updated within 60s)
  │         AND (workDir not in activeWorkDirs) AND (pid not in jsonlActivePIDs)
  ├── Sort result by pid ascending
  └── writeSubagentFiles(agents:todayStr:)
```

---

## PID Liveness Check

```swift
let pid32 = Int32(json.pid)
guard kill(pid32, 0) == 0 else {
    try? fm.removeItem(at: file)
    continue
}
```

`kill(pid, 0)` does not send a signal. It returns:
- `0` — process exists and is accessible
- `-1` with `ESRCH` — process does not exist
- `-1` with `EPERM` — process exists but belongs to another user (not expected here)

When a process is dead, the `.agent.json` file is deleted from the usage directory. The corresponding `.dat` file is **not** deleted (it contributes to historical cost totals in `UsageData`).

---

## CPU Usage

```swift
private static func cpuUsage(for pid: Int) -> Double {
    // Runs: ps -p {pid} -o %cpu=
    // Returns: Double parsed from stdout, or 0 on failure
}
```

- Executes `/bin/ps` with `-p {pid} -o %cpu=` (the `=` suppresses the header)
- Output is a single floating-point number, e.g. `"45.3"`
- Parsed as `Double`, defaults to `0` on failure
- Called once per live agent per `reload()`

---

## Idle Detection

An agent is considered idle when **all four** conditions are true:
1. `cpuUsage < 1.0` — less than 1% CPU
2. `Date().timeIntervalSince1970 - agent.updatedAt >= 60` — not updated in the last 60 seconds
3. `!activeWorkDirs.contains(agent.workingDir)` — no other agent in the same working directory is actively consuming CPU
4. `!jsonlActivePIDs.contains(agent.pid)` — no JSONL file activity within the last 60 seconds

### Project-Level Active State

If an agent has CPU >= 1.0, all agents with the same `workingDir` are considered non-idle — even if their own CPU is below 1%. This handles cases where:
- A supervisor agent spawns subagents and waits (0% CPU while subagent is active)
- Multiple Claude Code windows are open in the same project

```swift
let activeWorkDirs = Set(
    agents.filter { $0.cpuUsage >= 1.0 }.map(\.workingDir)
)
```

### JSONL Activity Check

Before idle evaluation, `reload()` checks JSONL file modification times for each agent with a non-empty `sessionID`:

1. **Parent JSONL mtime**: Checks `~/.claude/projects/{encoded}/{sessionID}.jsonl`. If modified within the last 60 seconds, the agent's PID is added to `jsonlActivePIDs`.
2. **Subagent JSONL mtimes**: If the parent JSONL is not recent, checks all files in `~/.claude/projects/{encoded}/{sessionID}/subagents/`. If the maximum mtime across all subagent JSONL files is within the last 60 seconds, the agent's PID is added to `jsonlActivePIDs`.

This catches cases where Claude Code is actively working (writing to JSONL) but has low CPU usage momentarily, or where subagents are actively running even though the parent agent shows low CPU.

The 60-second threshold (reduced from the previous 5-minute `updatedAt` threshold) provides faster idle/active transitions.

### Initial Value

All agents are initially created with `isIdle = true` (placeholder). The idle state is recalculated immediately in the map pass and a new `AgentInfo` is created with the correct value. If the recalculated `idle` matches the initial `true`, no new struct is created (guarded with `guard idle != agent.isIdle`).

---

## AgentInfo Construction

Each `.agent.json` file decoded into `AgentFileData` produces an `AgentInfo` with:

| AgentInfo field | Source |
|-----------------|--------|
| `pid` | `json.pid` |
| `model` | `json.model` |
| `agentName` | `json.agentName` |
| `contextPercent` | `json.contextPercent` |
| `contextWindow` | `json.contextWindow ?? 0` |
| `cost` | `json.cost` |
| `linesAdded` | `json.linesAdded` |
| `linesRemoved` | `json.linesRemoved` |
| `workingDir` | `json.workingDir` |
| `sessionID` | `json.sessionID` |
| `durationMs` | `json.durationMs ?? 0` |
| `apiDurationMs` | `json.apiDurationMs ?? 0` |
| `updatedAt` | `json.updatedAt` |
| `cpuUsage` | `Self.cpuUsage(for: json.pid)` |
| `isIdle` | Recalculated after all agents are loaded |
| `source` | From directory being scanned (`.cli` or `.commander`) |

---

## Sort Order of activeAgents

After idle recalculation, `activeAgents` is sorted by `pid` ascending:

```swift
.sorted { $0.pid < $1.pid }
```

This is the **storage sort order** — it determines the iteration order for `writeSubagentFiles`. The **display sort order** is applied separately in `PopoverView.sortAgents(_:)` based on `AppSettings.agentSortOrder`.

---

## Subagent File Writing

After the agent list is finalized, `writeSubagentFiles(agents:todayStr:)` runs for all agents in `activeAgents` (including idle ones) that have a non-empty `sessionID`.

### Directory Discovery

For each qualifying agent:
```
encodedPath = SessionScanner.encodeProjectPath(agent.workingDir)
subagentsDir = ~/.claude/projects/{encodedPath}/{agent.sessionID}/subagents/
```

### Mtime Cache

```swift
private var subagentCache: [String: (mtime: Date, stats: [String: SourceModelStats])] = [:]
```

Before rescanning:
1. Get directory attributes: `fm.attributesOfItem(atPath: subagentsDir.path)`
2. Extract `modificationDate` as `mtime`
3. If `subagentCache[agent.sessionID]?.mtime == mtime` → skip (no new files)
4. Otherwise: rescan and update cache

This prevents the JSONL parsing cost from being incurred on every 5-second poll when no new subagent files have been written.

### Data Written

Two files are written per agent with subagents:

**`{pid}.subagents.json`** — `[String: SourceModelStats]`
- Key: model display name (e.g. `"Opus 4.6"`)
- Value: cumulative cost + lines for that model across all subagents
- Written to today's CLI or Commander directory based on `agent.source`
- Used by `UsageData.collectEntries` to populate `SourceStats.subagentsByModel`

**`{pid}.subagent-details.json`** — `[SubagentInfo]`
- One entry per subagent JSONL file
- Sorted by cost descending (done by `JSONLParser.parseSubagentDetails`)
- Written only if the list is non-empty
- Used by `SubagentDetailView.loadFromFile()`
- Now includes `description`, `subagentType`, and `lastModified` fields per subagent, populated via `JSONLParser.parseSubagentMeta()` which is called before `parseSubagentDetails(in:meta:)`

Both files are written atomically with `options: .atomic`.

After writing both files, `writeSubagentFiles` also updates `subagentDetails[agent.pid]` in-memory with the freshly parsed details.

### Subagent Meta Parsing

Before calling `parseSubagentDetails`, `writeSubagentFiles` calls `JSONLParser.parseSubagentMeta(sessionID:workingDir:)` to build a map of `agentID -> SubagentMeta`. This map is passed as the `meta` parameter to `parseSubagentDetails(in:meta:)`, which uses it to populate the `description` and `subagentType` fields on each `SubagentInfo`.

### Parent Session Tool Count Parsing

After handling subagent files, `writeSubagentFiles` parses the parent session's JSONL to populate tool counts:

```
jsonlURL = ~/.claude/projects/{encodedPath}/{sessionID}.jsonl
```

**Flow:**
1. Get `modificationDate` of the parent JSONL via `fm.attributesOfItem(atPath: jsonlURL.path)`
2. Compare to `parentToolCache[agent.sessionID]?.mtime`
3. If mtime is unchanged → use cached counts (skip file read)
4. If mtime changed → call `JSONLParser.parseParentTools(sessionID:workingDir:)`, store result in `parentToolCache[agent.sessionID]`
5. If `parentToolCache[agent.sessionID]?.counts` is non-empty → assign to `parentToolCounts[agent.pid]`

This runs for every agent in `activeAgents` with a non-empty `sessionID`, regardless of whether the subagents directory exists (a parent session may have tool calls even with no subagents).

### Correct Usage Directory by Source

```swift
let todayDir: URL
switch agent.source {
case .cli:
    todayDir = usageDir.appendingPathComponent(todayStr)
case .commander:
    todayDir = CommanderSupport.baseDir.appendingPathComponent(todayStr)
}
```

This ensures subagent files for Commander agents land in the Commander subdirectory, matching the path used by `SubagentDetailView` when reading.

---

## AgentFileData Format (JSON)

`AgentFileData` is the Codable bridge between the on-disk JSON and the in-memory representation:

```json
{
  "pid": 12345,
  "model": "Opus 4.6",
  "agent_name": "My Agent",
  "context_pct": 45,
  "context_window": 200000,
  "cost": 1.234567,
  "lines_added": 850,
  "lines_removed": 320,
  "working_dir": "/Users/alice/myproject",
  "session_id": "abc123-def456",
  "duration_ms": 180000.0,
  "api_duration_ms": 12000.0,
  "updated_at": 1741234567.0
}
```

CodingKeys mapping:
| Swift property | JSON key |
|----------------|----------|
| `agentName` | `agent_name` |
| `contextPercent` | `context_pct` |
| `contextWindow` | `context_window` |
| `linesAdded` | `lines_added` |
| `linesRemoved` | `lines_removed` |
| `workingDir` | `working_dir` |
| `sessionID` | `session_id` |
| `durationMs` | `duration_ms` |
| `apiDurationMs` | `api_duration_ms` |
| `updatedAt` | `updated_at` |

`contextWindow`, `durationMs`, and `apiDurationMs` are optional (`Int?` / `Double?`) for backward compatibility with `.agent.json` files written before these fields were added.

---

## Computed Properties on AgentInfo

| Property | Formula | Example |
|----------|---------|---------|
| `displayName` | `agentName.isEmpty ? model : agentName` | `"My Agent"` or `"Opus 4.6"` |
| `shortDir` | `(workingDir as NSString).lastPathComponent` | `"myproject"` |
| `updatedAtDate` | `Date(timeIntervalSince1970: updatedAt)` | — |
| `idleDuration` | `Date().timeIntervalSince(updatedAtDate)` | `TimeInterval` |
| `idleText` | Based on `idleDuration` in minutes | `"5m idle"`, `"1h 30m idle"` |
| `durationText` | `formatMs(durationMs)` — `"Nm Ns"` or `"NhNm"` | `"3m 15s"` |
| `apiDurationText` | `formatMs(apiDurationMs)` | `"0m 12s"` |
| `contextWindowText` | Converts tokens to `"NM"` format | `"200K"` → shown as `"0.2M"` ← Actually: `200000/1000000 = 0.2`, displayed as `"0.2M"` |

### contextWindowText precision

```swift
let millions = Double(contextWindow) / 1_000_000.0
if millions == Double(Int(millions)) {
    return "\(Int(millions))M"  // e.g. 1.0 → "1M"
}
return String(format: "%.1fM", millions)  // e.g. 0.2 → "0.2M"
```

---

## Error Handling

- File read failures: `guard let data = try? Data(contentsOf: file)` — silently skips the file
- JSON decode failures: `guard let json = try? decoder.decode(AgentFileData.self, from: data)` — silently skips
- CPU fetch failure: returns `0.0` — agent treated as having 0% CPU (likely idle)
- Subagent directory missing: `guard let attrs = try? ...` — skips subagent scan for this agent
- Subagent JSON write failure: `try?` — silently ignored; next `reload()` will retry if mtime changes

---

## Edge Cases

### Agent with no sessionID
Sessions that don't report a `session_id` (empty string) are skipped for subagent scanning:
```swift
for agent in agents where !agent.sessionID.isEmpty
```
They still appear in `activeAgents` for the main view, but the SubagentDetailView will show "No subagents recorded".

### Rapid reload cycles
The 5-second poll means `reload()` is called frequently. The mtime cache prevents JSONL rescanning on most calls. CPU queries via `ps` are still issued every reload for each live agent — potentially 1+ `ps` process launch per agent per 5 seconds. This is considered acceptable for typical usage (1–3 agents).

### Multiple agents in same project
Two agents in the same `workingDir` each have their own `sessionID` and write to separate subagent JSONL files under `~/.claude/projects/{encoded}/{sessionID}/subagents/`. Their subagent data is tracked independently.

### AgentTracker vs CommanderSupport ordering
`CommanderSupport.refreshFiles()` MUST run before `AgentTracker.reload()` to ensure Commander `.agent.json` files are present in today's commander directory when AgentTracker scans it. This ordering is enforced in `AppDelegate.setupMonitor()` and `AppDelegate.togglePopover()`.
