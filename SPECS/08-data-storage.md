# Data Storage Specification

## Overview

`UsageData.swift` reads the file system state under `~/.claude/usage/` and produces three `PeriodStats` values (day, week, month). It is an `@Observable` class — SwiftUI views that read its properties are automatically re-rendered when `reload()` is called.

---

## File Layout

```
~/.claude/usage/
├── .last_cleanup                  ← Date string "YYYY-MM-DD", prevents daily cleanup re-run
├── YYYY-MM-DD/                    ← CLI source (written by statusline-command.sh)
│   ├── {PPID}.dat                 ← "cost linesAdded linesRemoved model\n"
│   ├── {PPID}.models              ← TSV: cost\tla\tlr\tmodel (one row per model switch)
│   ├── {PPID}.agent.json          ← AgentFileData JSON (written by statusline, read by AgentTracker)
│   ├── {PPID}.subagents.json      ← [String: SourceModelStats] (written by AgentTracker)
│   ├── {PPID}.subagent-details.json ← [SubagentInfo] (written by AgentTracker)
│   ├── {PPID}.parent-tools.json   ← [String: Int] tool counts (written by AgentTracker)
│   └── {PPID}.project             ← Project root path string (written by AgentTracker)
└── commander/
    ├── .last_cleanup
    └── YYYY-MM-DD/                ← Commander source (written by CommanderSupport)
        ├── {pid}.dat
        ├── {pid}.agent.json
        ├── {pid}.subagents.json
        ├── {pid}.subagent-details.json
        ├── {pid}.parent-tools.json
        └── {pid}.project
```

`UsageData` reads `.dat`, `.models`, `.subagents.json`, and `.project` files. The `.agent.json` and `.subagent-details.json` files are read by `AgentTracker` and `SubagentDetailView` respectively. The `.parent-tools.json` file is read by `SubagentDetailView`.

---

## Data Structures

### DatEntry (internal)

```swift
struct DatEntry {
    let pid: String          // PID string (filename stem)
    let day: Date            // Start of day for the folder containing this file
    let cost: Double         // Period-specific cost (may be incremental after dedup)
    let absoluteCost: Double // Always the raw cumulative .dat value
    let linesAdded: Int
    let linesRemoved: Int
    let model: String        // Last model reported in .dat file
    let source: AgentSource  // .cli or .commander
    let project: String      // Short project name from {pid}.project file, empty if unknown
}
```

### PeriodStats (public)

```swift
struct PeriodStats {
    var cost: Double         // Combined cost across all sources
    var linesAdded: Int
    var linesRemoved: Int
    var cli: SourceStats
    var commander: SourceStats
}
```

### ProjectStats (public)

```swift
struct ProjectStats {
    var main = SourceModelStats()       // Main session cost/lines for this project
    var subagents = SourceModelStats()  // Subagent cost/lines for this project
}
```

Aggregates cost and lines for a single project, split between the main session and its subagents. Used in the `byProject` map on `SourceStats`.

### SourceStats (public)

```swift
struct SourceStats {
    var total: SourceModelStats                    // Sum across all models
    var byModel: [String: SourceModelStats]        // Cost/lines per model display name
    var subagentsByModel: [String: SourceModelStats] // Cost/lines for subagents, per model
    var byProject: [String: ProjectStats]          // Cost/lines aggregated by project name
}
```

### SourceModelStats (public, Codable)

```swift
struct SourceModelStats: Codable {
    var cost: Double
    var linesAdded: Int
    var linesRemoved: Int
}
```

---

## .dat File Format

Single line, space-separated:

```
{cost} {linesAdded} {linesRemoved} {model name}\n
```

Example:
```
1.234567 850 320 Claude Sonnet 4.5
```

Parsing in `collectEntries`:
```swift
let parts = content.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
let cost  = Double(parts.first ?? "0") ?? 0
let la    = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
let lr    = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
let model = parts.count > 3 ? parts[3...].joined(separator: " ") : ""
```

The model name can contain spaces and occupies all tokens from index 3 onward.

---

## .models File Format

TSV append-log. One row per model switch:

```
{cost}\t{linesAdded}\t{linesRemoved}\t{model name}
```

Example:
```
0.120000	0	0	Claude Sonnet 4.5
0.890000	420	180	Claude Opus 4.5
1.234567	850	320	Claude Opus 4.5
```

The values in each row are the **cumulative totals at the time the model changed**. Each row represents the baseline at the point of the model switch, not the incremental delta for that model.

Parsing in `collectEntries`:
```swift
let cols = line.split(separator: "\t", maxSplits: 3)
guard cols.count >= 4 else { return nil }
return (cost: Double(cols[0]) ?? 0, la: Int(cols[1]) ?? 0, lr: Int(cols[2]) ?? 0, model: String(cols[3]))
```

A history with fewer than 2 rows is ignored (falls back to simple model attribution from `.dat`).

---

## .project File Format

A plain text file containing the resolved project root path (a single line, no trailing newline required):

```
/Users/alice/myproject
```

Written by `AgentTracker.reload()` during the agent construction loop. The filename stem is the PID (e.g. `12345.project`). The content is the `resolvedDir` — the result of `SessionScanner.resolveProjectRoot(workingDir:sessionID:)`.

### Reading in collectEntries

During `collectEntries`, `.project` files in each date directory are read first to build a `pidToProject: [String: String]` map. The project name is extracted as the last path component of the stored path:

```swift
pidToProject[pid] = (path as NSString).lastPathComponent
```

This project name is then stored in `DatEntry.project` for each corresponding `.dat` entry and is used during `accumulate()` to populate `SourceStats.byProject`.

---

## .subagents.json File Format

JSON-encoded `[String: SourceModelStats]`:

```json
{
  "Opus 4.6":    {"cost": 2.50, "linesAdded": 900, "linesRemoved": 300},
  "Sonnet 4.5":  {"cost": 0.60, "linesAdded": 300, "linesRemoved": 100}
}
```

Written by `AgentTracker.writeSubagentFiles(agents:todayStr:)`. Read by `UsageData.collectEntries` and merged into `SourceStats.subagentsByModel`.

---

## Period Boundaries

All boundaries are computed relative to the local calendar at the time of `reload()`:

| Period | Boundary | Computation |
|--------|----------|-------------|
| Today  | Start of current calendar day | `calendar.startOfDay(for: now)` |
| Week   | Most recent Monday | `today - (weekday + 5) % 7 days` where weekday is `calendar.component(.weekday)` (Sunday=1) |
| Month  | First day of current month | `calendar.dateComponents([.year, .month], from: now)` |

Only date folders from `monthStart` onward are processed (`dirDay >= monthStart`).

---

## PID Deduplication Logic

A Claude Code session that runs across midnight will have `.dat` files in multiple day folders with increasing cumulative costs. Without deduplication, the session would be counted multiple times.

### Deduplication Algorithm

After collecting all entries (sorted by `day` ascending):

```swift
for entry in entries.sorted(by: { $0.day < $1.day }) {
    if let existing = latestByPID[entry.pid] {
        previousByPID[entry.pid] = existing
    }
    latestByPID[entry.pid] = entry
}
```

After this pass:
- `latestByPID[pid]` = the entry from the most recent folder
- `previousByPID[pid]` = the entry from the second-most-recent folder (if any)

### Period Accumulation Rules

For each PID, using `(latest, prev)`:

**Month:**
Always use `latest.cost` (the most recent cumulative value). This is the maximum total cost for the session and is correct for month-to-date totals.

**Week:**
```
if latest.day >= weekStart:
    if prev.day >= weekStart:
        use incremental (latest - prev)
    else:
        use latest (prev is outside the week, not relevant)
```

**Today:**
```
if latest.day == today:
    if prev exists AND prev.day < today:
        use incremental (latest - prev)  ← session spans midnight
    else:
        use latest (session started today, no overnight component)
```

### incrementalEntry

```swift
func incrementalEntry(latest: DatEntry, previous: DatEntry) -> DatEntry {
    DatEntry(
        cost:          max(0, latest.cost - previous.cost),
        absoluteCost:  latest.cost,     // raw .dat total preserved
        linesAdded:    max(0, latest.linesAdded - previous.linesAdded),
        linesRemoved:  max(0, latest.linesRemoved - previous.linesRemoved),
        ...
    )
}
```

The `absoluteCost` always holds the raw cumulative `.dat` value even for incremental entries. This is critical for the model breakdown algorithm.

---

## Model Breakdown

### Overview

The `.models` file records cumulative costs at each model switch. `modelBreakdown()` converts this into per-model cost/lines attribution.

### Algorithm

Given history entries `[(cost, la, lr, model)]` sorted as written (chronological):

For each history entry `i`:
- `nextCost = history[i+1].cost` if exists, else `absoluteCost` (the final .dat value)
- `nextLA = history[i+1].la` if exists, else `baseLA + totalLA`
- `dc = max(0, nextCost - current.cost)` — cost delta attributed to model `i`

```
Example history:
  [0]  cost=0.12, model="Sonnet 4.5"   ← recorded at model switch to Sonnet
  [1]  cost=0.89, model="Opus 4.5"     ← recorded at model switch to Opus
  absoluteCost = 1.23

Attribution:
  Sonnet 4.5: dc = 0.89 - 0.12 = 0.77
  Opus 4.5:   dc = 1.23 - 0.89 = 0.34
```

### Untracked Initial Cost

For same-day sessions, there may be cost accumulated before `.models` tracking started (before the first model switch). This is attributed to `history[0].model`:

```swift
let isSameDay = abs(periodCost - absoluteCost) < 0.001
if isSameDay {
    let untrackedCost = absoluteCost - rawTotal
    if untrackedCost > 0.001 {
        rawByModel[history[0].model].cost += untrackedCost
    }
    return rawByModel  // No scaling needed
}
```

`isSameDay` is true when `periodCost ≈ absoluteCost` (within $0.001). If the session was active only today, these two values are equal. If the session spans midnight, `periodCost` (the incremental today cost) will be less than `absoluteCost` (the cumulative total).

### Midnight-Spanning Model Breakdown Scaling

For sessions spanning midnight, the model breakdown history records cumulative costs from the entire session lifetime, not just today's portion. Since we can't know which model was active at midnight, a proportional scale is applied:

```swift
let scale = periodCost / rawTotal
for (model, stats) in rawByModel {
    result[model] = SourceModelStats(
        cost:         stats.cost * scale,
        linesAdded:   stats.linesAdded,   // lines NOT scaled
        linesRemoved: stats.linesRemoved  // lines NOT scaled
    )
}
```

Only cost is scaled. Lines are not scaled because the `.dat` file already contains the incremental line count (the statusline reports cumulative lines, and `incrementalEntry` subtracts).

---

## Subagent Data Merging

After model breakdown, subagent data from `{pid}.subagents.json` is merged into `SourceStats.subagentsByModel`:

```swift
if let subs = subagentStats["\(pid)\t\(source.rawValue)"] {
    for (model, stats) in subs {
        p[keyPath: kp].subagentsByModel[model].cost += stats.cost
        p[keyPath: kp].subagentsByModel[model].linesAdded += stats.linesAdded
        p[keyPath: kp].subagentsByModel[model].linesRemoved += stats.linesRemoved
    }
}
```

Subagent costs are additive — they are included in `source.total.cost` but not in `source.byModel`. This means the stats detail screen can show both the main session model breakdown and the subagent breakdown as separate sections.

The subagent data is not subject to the same deduplication as the parent session. It is loaded from today's `.subagents.json` file only and merged directly.

---

## Data Collection Flow

```
UsageData.reload()
  ├── Define period boundaries (today, weekStart, monthStart)
  ├── collectEntries(under: usageDir, source: .cli, ...)
  │   └── For each date dir ≥ monthStart:
  │       ├── Read {pid}.project files → pidToProject map
  │       ├── Read each .dat file → DatEntry (with project from pidToProject)
  │       ├── Read {pid}.models → history
  │       └── Read {pid}.subagents.json → subagent stats
  ├── collectEntries(under: commander/baseDir, source: .commander, ...)
  │   └── Same structure
  ├── Deduplicate: build latestByPID and previousByPID
  └── For each (pid, latest):
      ├── Accumulate into month (latest.cost)
      ├── Accumulate into week (incremental if both in week)
      └── Accumulate into day (incremental if latest=today & prev=yesterday)
          └── accumulate() for each period:
              ├── Add to source.total
              ├── Distribute across source.byModel (via model history or single model)
              ├── Merge subagent stats into source.subagentsByModel
              └── If entry.project non-empty: aggregate into source.byProject[project]
                  ├── .main += entry cost/lines
                  └── .subagents += subagent cost/lines for this PID
```

---

## Edge Cases

### PID reuse across calendar days

The deduplication key is `{pid}` only, which is the filename stem from `.dat` files (NOT including the date or source). The `pid` field in `DatEntry` combines the string PID with a source suffix for model history lookups (`"\(pid)\t\(source.rawValue)"`). If two processes have the same PID on different days, deduplication may incorrectly merge them. In practice, macOS PIDs cycle through a large range, making collisions over a 3-month window extremely rare.

### Negative deltas

`max(0, ...)` is applied to all incremental subtractions. If for some reason a later `.dat` has a lower cost than an earlier one (e.g. file corruption or time zone shift), the delta is clamped to 0.

### Missing .models file

If no `.models` file exists for a PID, `modelHistories` has no entry for that key. The `accumulate` function falls back to `entry.model` attribution: the entire period's cost is attributed to the single model reported in the `.dat` file.

### Commander sessions without .models

Commander sessions never write `.models` files. Their model breakdown in the detail view comes either from `source.byModel` (populated from subagent JSONL scanning) or shows "Model breakdown not available for older sessions" if there's nothing.

### Data from test initializer

`UsageData.init(testUsageDir:)` is a package-internal initializer used in tests. It accepts a custom usage directory and sets `includeCommander = false` to avoid reading real Commander data during tests.

---

## Concurrency & Race Conditions

### Atomic File Writes

File writes in ClaudeUsageBar are atomic wherever possible to minimize the window for partial reads:

| File | Writer | Atomic mechanism |
|------|--------|-----------------|
| `.dat` (Commander) | `CommanderSupport.writeAgentData` | `String.write(atomically: true, ...)` — Swift writes to a `.tmp` file and renames |
| `.agent.json` (Commander) | `CommanderSupport.writeAgentData` | `Data.write(options: .atomic)` — writes to a temp file and renames |
| `.agent.json` (CLI) | `statusline-command.sh` | `cat > .tmp && mv` — shell-level atomic rename |
| `.subagents.json` | `AgentTracker.writeSubagentFiles` | `Data.write(options: .atomic)` |
| `.subagent-details.json` | `AgentTracker.writeSubagentFiles` | `Data.write(options: .atomic)` |

The `.atomic` option on `Data.write()` causes Swift to write the data to a temporary file in the same directory and then rename it into place. Rename is an atomic OS operation on local filesystems, so a reader will see either the old complete file or the new complete file — never a partial write.

### Read/Write Ordering

`CommanderSupport.refreshFiles()` always runs before `UsageData.reload()` and `AgentTracker.reload()`. This ordering ensures that `.dat` and `.agent.json` files for Commander sessions are fully written before the readers scan the directory. The ordering is enforced in two code paths:

- **Monitor callback** (`setupMonitor`): `refreshFiles()` is called synchronously, then `usageData.reload()`, then `agentTracker.reload()` — all on the main thread, sequentially.
- **Popover open** (`togglePopover`): `refreshFiles()` runs on the background thread; `usageData.reload()` and `agentTracker.reload()` run in the `DispatchQueue.main.async` block that is only dispatched after `refreshFiles()` returns.

### No File Locking

There is no explicit file locking between readers and writers. The `.atomic` write option minimizes the window during which a file is in a partially-written state, but it does not prevent a reader from accessing the file during the rename step. In practice the rename is so fast that a partial read during the rename is extremely unlikely, and `try?` on the read silently handles any resulting failure.

### FSEvents Debouncing

`FSEventStreamCreate` is called with a `latency` of `0.5` seconds:

```swift
guard let stream = FSEventStreamCreate(
    nil, callback, &context, [usageDir] as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
    0.5,   // 500ms latency
    ...
)
```

The 500ms latency causes FSEvents to coalesce multiple rapid filesystem changes into a single callback firing. A statusline invocation that writes `.dat`, `.models`, and `.agent.json` in quick succession triggers only one `onChange()` call rather than three. This reduces redundant `reload()` cycles.

### Timer Period

The poll timer fires every exactly 5.0 seconds:

```swift
pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { ... }
```

The `repeats: true` parameter keeps the timer firing indefinitely. The timer is scheduled on `RunLoop.main` (the default for `Timer.scheduledTimer`). It is invalidated in `UsageMonitor.deinit` to prevent firing after the monitor is released.

### No TOCTOU Guard

Directory listing and the subsequent per-file reads are not atomic — there is a time-of-check-to-time-of-use gap. A file listed by `contentsOfDirectory` may be deleted before the subsequent `Data(contentsOf: file)` call. This is handled gracefully: `try?` on the read returns `nil`, and the `guard let` discards the entry via `continue`. No TOCTOU-related error is possible that would crash or corrupt state.

### .models Files: Append-Only with Self-Contained Lines

`.models` files are written with the shell `>>` (append) operator — each model transition appends a new line. Concurrent writes to the same file (unlikely but theoretically possible if two statusline invocations run simultaneously) could interleave characters. However, each line is self-contained and the `guard cols.count >= 4` check in the parser skips any incomplete line that results from a partial append. The worst outcome is a missing transition entry, not corrupted state.

### Memory Footprint of Deduplication Maps

The `latestByPID` and `previousByPID` maps in `UsageData.reload()` hold at most one entry per unique PID seen across the past 3 months. In typical usage this is hundreds of entries (one per daily session). Each `DatEntry` is a small struct (~200 bytes including the model name string). The total memory for these maps is well under 1MB even for heavy users. The maps are local to `reload()` and are discarded after it returns; they do not contribute to steady-state memory usage.
