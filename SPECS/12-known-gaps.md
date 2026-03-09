# SPEC 12: Known Gaps

This file documents the known gaps in the spec set — details that cannot be inferred from
the other 11 spec files alone and would require consulting the original source code or running
the app to resolve. A developer rebuilding the app should read this file to know exactly what
to verify against the original implementation.

All gaps in this file have been investigated against the actual source code. Where the source
resolves the question definitively, the answer is given with a file and line reference. Where
genuine ambiguity remains, the action for a rebuilder is stated precisely.

---

## Gap 1: NSPopover positioning

**Question:** What are the exact anchor rect, anchor view, and preferred edge passed to
`popover.show(relativeTo:of:preferredEdge:)` when the status bar icon is clicked?

**Answer:** Resolved from source. The call is:

```swift
popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
```

- Anchor rect: `button.bounds` — the full bounding rectangle of the status bar button.
- Anchor view: `button` — the `NSButton` of the `NSStatusItem`.
- Preferred edge: `.minY` — the popover opens downward (below the menu bar).
- Popover behavior is `.transient` — it closes automatically when the user clicks outside it.
- After the popover appears, `popoverDidShow(_:)` calls
  `popover.contentViewController?.view.window?.makeKey()` to ensure the popover window
  receives keyboard events.
- When already shown, `popover.performClose(nil)` is called instead.

**Source:** `Sources/App/ClaudeUsageBarApp.swift`

**Action for rebuilder:** Use exactly `.minY` as the preferred edge and `button.bounds` as
the rect. Using a zero rect or `.maxY` will produce visually different or broken positioning
on macOS menu bars. Verify that `makeKey()` is called in `popoverDidShow`. Note that in
window mode (`DisplayMode.window`), an `NSPanel` is used instead of `NSPopover`, with
`isFloatingPanel = true`, `.floating` level, `setFrameAutosaveName` for position persistence,
and `hidesOnDeactivate = false`.

---

## Gap 2: CPU sampling strategy — RESOLVED/REMOVED

**Question:** Does `cpuUsage(for:)` take a single instantaneous `ps` sample or average
multiple samples? What does it return when `ps` produces no output or fails?

**Answer:** This gap no longer applies. The `cpuUsage(for:)` method has been removed from
`AgentTracker`. CPU usage is now always set to `0`:

```swift
agents.append(AgentInfo(
    // ...
    cpuUsage: 0,
    isIdle: true, // recalculated below
    // ...
))
```

There are no per-PID `ps -p {pid} -o %cpu=` calls. Idle detection is based entirely on
two criteria:
1. `updatedAt` timestamp recency (within 60 seconds of current time)
2. JSONL file mtime activity (parent or subagent JSONL modified within 60 seconds)

A single batch `verifyClaudePIDs()` call runs `/bin/ps` once with all candidate PIDs to
confirm they are claude processes (handles PID reuse), but this is for liveness verification,
not CPU sampling.

**Source:** `Sources/AgentTracker.swift`

**Action for rebuilder:** Do not implement `cpuUsage(for:)`. Set `cpuUsage` to `0` in
`AgentInfo` construction. Idle detection should use `updatedAt` recency and JSONL mtime
checks only.

---

## Gap 3: Statusline shell script

**Question:** What is the exact content of the shell script that Claude Code's statusline
hook executes? Spec 05 describes its behaviour at a high level but a rebuilder needs the
precise implementation.

**Answer:** Resolved from source. The full script is reproduced verbatim below.

```sh
#!/bin/sh
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTXWIN=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
AGENT_NAME=$(echo "$input" | jq -r '.agent.name // ""')
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'; MAGENTA='\033[35m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

# --- ClaudeUsageBar tracking ---
# Stores one file per session per day: ~/.claude/usage/YYYY-MM-DD/{pid}.dat
USAGE_DIR="$HOME/.claude/usage"
TODAY=$(date +%Y-%m-%d)
mkdir -p "$USAGE_DIR/$TODAY"
echo "$COST $LINES_ADDED $LINES_REMOVED $MODEL" > "$USAGE_DIR/$TODAY/$PPID.dat"

# Track model transitions for per-model cost breakdown
MF="$USAGE_DIR/$TODAY/$PPID.models"
PREV_MODEL=""; [ -f "$MF" ] && PREV_MODEL=$(tail -1 "$MF" | cut -f4-)
[ "$PREV_MODEL" != "$MODEL" ] && printf '%s\t%s\t%s\t%s\n' "$COST" "$LINES_ADDED" "$LINES_REMOVED" "$MODEL" >> "$MF"

# Write live agent metadata for menu bar app
cat > "$USAGE_DIR/$TODAY/$PPID.agent.json.tmp" <<AGENTEOF
{"pid":$PPID,"model":"$MODEL","agent_name":"$AGENT_NAME","context_pct":$PCT,"context_window":$CTXWIN,"cost":$COST,"lines_added":$LINES_ADDED,"lines_removed":$LINES_REMOVED,"working_dir":"$DIR","session_id":"$SESSION_ID","duration_ms":$DURATION_MS,"api_duration_ms":$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0'),"updated_at":$(date +%s)}
AGENTEOF
mv "$USAGE_DIR/$TODAY/$PPID.agent.json.tmp" "$USAGE_DIR/$TODAY/$PPID.agent.json"

# Cleanup data older than 3 months (runs once per day via marker file)
CLEANUP_MARKER="$USAGE_DIR/.last_cleanup"
if [ ! -f "$CLEANUP_MARKER" ] || [ "$(cat "$CLEANUP_MARKER")" != "$TODAY" ]; then
  echo "$TODAY" > "$CLEANUP_MARKER"
  CUTOFF=$(date -v-3m +%Y-%m-%d)
  for dir in "$USAGE_DIR"/????-??-??; do
    [ -d "$dir" ] || continue
    [ "$(basename "$dir")" \< "$CUTOFF" ] && rm -rf "$dir"
  done
fi

# Compute period boundaries
DOW=$(date +%u)
WEEK_START=$(date -v-$(( DOW - 1 ))d +%Y-%m-%d)
MONTH_START=$(date +%Y-%m-01)

# Sum all tracked sessions with deduplication (same logic as the menu bar app):
# A session spanning multiple days has .dat files in each day's folder with cumulative costs.
# Keep only the latest day per PID and subtract the previous day's value for today's increment.
TOTALS=$(find "$USAGE_DIR" -name "*.dat" -type f 2>/dev/null | sort | \
  awk -v today="$TODAY" -v week="$WEEK_START" -v month="$MONTH_START" '{
    n = split($0, p, "/"); date = p[n-1]; pid = p[n]
    sub(/\.dat$/, "", pid)
    key = pid
    if ((getline line < $0) > 0) {
      close($0)
      split(line, vals, " ")
      cost = vals[1] + 0; la = vals[2] + 0; lr = vals[3] + 0
      # Track latest and previous entry per PID (sorted by date, so later overwrites earlier)
      if (key in latest_cost) {
        prev_cost[key]  = latest_cost[key]
        prev_la[key]    = latest_la[key]
        prev_lr[key]    = latest_lr[key]
        prev_date[key]  = latest_date[key]
      }
      latest_cost[key] = cost
      latest_la[key]   = la
      latest_lr[key]   = lr
      latest_date[key] = date
    }
  } END {
    for (key in latest_cost) {
      date = latest_date[key]
      cost = latest_cost[key]; la = latest_la[key]; lr = latest_lr[key]
      # Month: latest cumulative value
      if (date >= month) { m += cost; m_la += la; m_lr += lr }
      # Week: latest if in week, else skip
      if (date >= week) {
        if (key in prev_cost && prev_date[key] >= week) {
          # both in week: use incremental
          w += cost - prev_cost[key]; w_la += la - prev_la[key]; w_lr += lr - prev_lr[key]
        } else {
          w += cost; w_la += la; w_lr += lr
        }
      }
      # Today: incremental (subtract previous day if session spans midnight)
      if (date == today) {
        if (key in prev_cost && prev_date[key] < today) {
          d += cost - prev_cost[key]; d_la += la - prev_la[key]; d_lr += lr - prev_lr[key]
        } else {
          d += cost; d_la += la; d_lr += lr
        }
      }
    }
    printf "%.2f %.2f %.2f %d %d %d %d %d %d", d+0, w+0, m+0, d_la+0, d_lr+0, w_la+0, w_lr+0, m_la+0, m_lr+0
  }')

DAY_TOTAL=$(echo "$TOTALS" | awk '{print $1}')
WEEK_TOTAL=$(echo "$TOTALS" | awk '{print $2}')
MONTH_TOTAL=$(echo "$TOTALS" | awk '{print $3}')
DAY_LA=$(echo "$TOTALS" | awk '{print $4}')
DAY_LR=$(echo "$TOTALS" | awk '{print $5}')
WEEK_LA=$(echo "$TOTALS" | awk '{print $6}')
WEEK_LR=$(echo "$TOTALS" | awk '{print $7}')
MONTH_LA=$(echo "$TOTALS" | awk '{print $8}')
MONTH_LR=$(echo "$TOTALS" | awk '{print $9}')

# Output
COST_FMT=$(printf '$%.2f' "$COST")
echo "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
echo "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"
echo "${MAGENTA}📊 ${RESET} Day: ${YELLOW}\$${DAY_TOTAL}${RESET} | Wk: ${YELLOW}\$${WEEK_TOTAL}${RESET} | Mo: ${YELLOW}\$${MONTH_TOTAL}${RESET}"
echo "✏️  Day: ${GREEN}+${DAY_LA}${RESET}/${RED}-${DAY_LR}${RESET} | Wk: ${GREEN}+${WEEK_LA}${RESET}/${RED}-${WEEK_LR}${RESET} | Mo: ${GREEN}+${MONTH_LA}${RESET}/${RED}-${MONTH_LR}${RESET}"
```

Key implementation details:
- Uses `$PPID` (parent PID of the script, i.e. the `claude` process) as the file key.
- `.dat` file format is a single space-separated line: `COST LINES_ADDED LINES_REMOVED MODEL`.
- `.models` file appends a tab-separated line only when the model changes between invocations.
- `.agent.json` is written atomically via a `.tmp` file then renamed.
- Context bar uses 10-character blocks (`█` for filled, `░` for empty), 1 block per 10%.
- Context bar colour thresholds: green below 70%, yellow 70–89%, red 90%+.
- Cleanup runs at most once per day, deletes date directories older than 3 months using
  macOS `date -v-3m` (BSD date syntax — not portable to GNU/Linux).
- `api_duration_ms` is fetched inline with a second `jq` call inside the heredoc.

**Source:** `Sources/Resources/statusline-command.sh:1-131`

**Action for rebuilder:** Copy this script exactly. Any deviation in the `.dat` or `.models`
file format will break the Swift-side parser in `UsageData.swift`.

---

## Gap 4: Line counting method — split vs components

**Question:** Which Swift string-splitting method is used to count lines in Edit tool
`old_string`/`new_string` and Write tool `content`? Does it count empty strings at the
end of a trailing newline?

**Answer:** Resolved from source. The method is `.components(separatedBy: "\n")`, not
`.split(separator: "\n")`.

```swift
case "Edit":
    let oldLines = (toolCall.input.old_string ?? "").components(separatedBy: "\n").count
    let newLines = (toolCall.input.new_string ?? "").components(separatedBy: "\n").count
    let delta = newLines - oldLines
    if delta > 0 { linesAdded += delta } else { linesRemoved += -delta }
case "Write":
    linesAdded += (toolCall.input.content ?? "").components(separatedBy: "\n").count
```

Behavioural difference that matters:
- `"a\nb\n".split(separator: "\n")` returns `["a", "b"]` — count 2.
- `"a\nb\n".components(separatedBy: "\n")` returns `["a", "b", ""]` — count 3.
- `"".components(separatedBy: "\n")` returns `[""]` — count 1 (never zero).
- `"".split(separator: "\n")` returns `[]` — count 0.

For Edit: delta = `newLines.count - oldLines.count`. Since both use the same method,
trailing-newline inflation is symmetric and largely cancels out.

For Write: every Write call counts at least 1 line, even for an empty file.

This exact method is used identically in three places: `parseSession`, `parseSubagents(in:)`,
and `parseSubagentDetails(in:meta:)`.

**Source:** `Sources/Commander/JSONLParser.swift:176-183` (parseSession),
`Sources/Commander/JSONLParser.swift:296-305` (parseSubagents),
`Sources/Commander/JSONLParser.swift:379-388` (parseSubagentDetails)

**Action for rebuilder:** Use `.components(separatedBy: "\n")` not `.split`. The 1-based
minimum for empty strings is a known quirk that must be preserved to keep line counts
consistent with the original.

---

## Gap 5: Model history zero-cost guard

**Question:** In `modelBreakdown()`, what happens when `rawTotal == 0` in the
midnight-spanning branch? Is there a guard that prevents a division-by-zero crash?

**Answer:** Resolved from source. There is an explicit guard.

```swift
// Midnight-spanning: scale proportionally to the incremental periodCost
guard rawTotal > 0 else { return rawByModel }
let scale = periodCost / rawTotal
```

The full control flow of `modelBreakdown()`:

1. The method builds `rawByModel` — per-model cost deltas from the `.models` transition
   history.
2. It checks if the session is same-day: `isSameDay = abs(periodCost - absoluteCost) < 0.001`.
3. **Same-day path:** attributes any untracked cost to `history[0].model`, then returns
   `rawByModel` directly — no scaling, no guard needed.
4. **Midnight-spanning path:** `guard rawTotal > 0 else { return rawByModel }` — if all
   transitions produced zero cost deltas, the unscaled (all-zero) dictionary is returned
   rather than dividing by zero. Then `scale = periodCost / rawTotal` is computed and each
   model's cost is multiplied by `scale`.

The `rawTotal > 0` guard is on line 254 of `UsageData.swift`. If this guard fires, the
returned dictionary will have zero costs for all models, so the period stats will show the
total cost correctly (from the `accumulate` call) but the model breakdown will be empty.
This is an edge case that should be rare (it requires a midnight-spanning session where the
`.models` file records no cost for any model transition).

**Source:** `Sources/UsageData.swift:243-264`

**Action for rebuilder:** Include the `guard rawTotal > 0` line precisely as shown. Omitting
it will crash at runtime for midnight-spanning sessions where all model costs compute to
zero. Verify that the same-day check uses `abs(periodCost - absoluteCost) < 0.001` (a
floating-point tolerance of $0.001) rather than strict equality.

---

## Gap 6: FSEvents + Timer interaction

**Question:** Can both the FSEvents callback and the 5-second Timer fire `onChange()` within
the same run loop iteration, causing a double reload? Is there any deduplication or
coalescing between them?

**Answer:** Resolved from source. Both sources call `onChange()` independently, but the
`onChange()` callback now calls `scheduleRefresh()` on the `AppDelegate`, which has a
`refreshInFlight` Boolean deduplication guard.

```swift
// FSEvents callback
DispatchQueue.main.async {
    monitor.onChange()
}

// Timer callback
pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
    DispatchQueue.main.async {
        self?.onChange()
    }
}
```

```swift
// In AppDelegate:
private func scheduleRefresh() {
    guard !refreshInFlight else { return }
    refreshInFlight = true
    refreshQueue.async { [weak self] in
        // ... refresh + reload ...
        DispatchQueue.main.async {
            self?.refreshInFlight = false
        }
    }
}
```

FSEvents is configured with a 2.0-second coalescing latency (`2.0` in the
`FSEventStreamCreate` call), meaning the kernel will batch rapid filesystem events and
deliver them at most every 2 seconds. The Timer fires every 5 seconds. Both dispatch to
the main queue via `DispatchQueue.main.async`.

The `refreshInFlight` guard in `scheduleRefresh()` means that if both FSEvents and the
Timer fire close together, only the first call dispatches a refresh — the second is
silently dropped. This prevents double reloads.

**Source:** `Sources/UsageMonitor.swift:33-75`, `Sources/App/ClaudeUsageBarApp.swift:78-100`

**Action for rebuilder:** The `refreshInFlight` guard provides effective deduplication.
Verify that FSEvents latency is 2.0 seconds (`2.0`) and Timer interval is 5 seconds —
these values affect perceived UI responsiveness. The 2.0-second FSEvents latency reduces
reload frequency during bursts of rapid file writes.

---

## Gap 7: AgentTracker subagent scanning thread model

**Question:** Does subagent JSONL parsing happen synchronously on the main thread? If so,
how much work can it do per reload call, and for how large a file?

**Answer:** Resolved from source. `AgentTracker.reload()` runs on the main thread, but
`writeSubagentFiles` is dispatched to a **dedicated serial background queue**:

```swift
// In reload():
let agentsSnapshot = activeAgents
subagentQueue.async { [weak self] in
    self?.writeSubagentFiles(agents: agentsSnapshot, todayStr: todayStr)
}
```

The queue is declared as:
```swift
private let subagentQueue = DispatchQueue(label: "com.swiftgurus.subagentScanner", qos: .utility)
```

The main thread work in `reload()` includes:
- `kill(pid, 0)` liveness checks (fast syscalls, no I/O)
- A single `verifyClaudePIDs()` call — runs `/bin/ps` once with all candidate PIDs to
  confirm they are claude processes. No per-PID `ps -p {pid} -o %cpu=` calls are made;
  CPU usage is always set to `0`.
- JSONL mtime checks for idle detection (checking parent and subagent JSONL modification dates)

The full call chain is:
```
AgentTracker.reload()           ← main thread
  ├── kill(pid, 0)              ← per-PID liveness check (syscall)
  ├── verifyClaudePIDs(pids)    ← single /bin/ps call for all PIDs
  ├── JSONL mtime checks        ← idle detection
  └── subagentQueue.async       ← dispatched to serial background queue
        └── writeSubagentFiles(...)
              ├── JSONLParser.parseSubagents(in:)        ← background, reads all .jsonl files
              ├── JSONLParser.parseSubagentMeta(...)      ← background, reads parent JSONL
              └── JSONLParser.parseSubagentDetails(in:meta:)  ← background, reads subagent files
                    └── DispatchQueue.main.async { subagentDetails[pid] = details }  ← back to main
```

The serial queue prevents data races when `reload()` fires multiple times in quick
succession (e.g. FSEvents + Timer firing close together). Only one scan runs at a time.

The `subagentCache` uses **max individual file mtime** (not directory mtime) to detect
when existing subagent JSONL files grow (not just when new files are added):

```swift
let files = (try? fm.contentsOfDirectory(at: subagentsDir,
    includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
let maxMtime = files.compactMap {
    try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
}.max() ?? Date.distantPast
guard subagentCache[agent.sessionID]?.mtime != maxMtime else { continue }
```

`@Observable` property mutations (`subagentDetails`, `parentToolCounts`) are dispatched
back to `DispatchQueue.main.async` to satisfy SwiftUI's main-actor requirement.

**Source:** `Sources/AgentTracker.swift` — `subagentQueue` declaration, `reload()` dispatch,
`writeSubagentFiles()` implementation.

**Action for rebuilder:** Use a serial `DispatchQueue` (not `DispatchQueue.global`) to
prevent concurrent scans. Dispatch all `@Observable` mutations back to main. Use max
individual file mtime (not directory mtime) for the cache key — directory mtime does not
change when existing files grow, only when files are added or removed.

---

## Gap 8: PID reuse collision

**Question:** Is the dedup key in `UsageData` just the bare PID filename, or does it
include the date? What prevents an old PID's `.dat` file from being confused with a
new process that was assigned the same PID on a later day?

**Answer:** Resolved from source. The dedup key is the bare PID string (filename without
extension), with no date component.

```swift
let pid = file.deletingPathExtension().lastPathComponent
// ...
entries.append(DatEntry(pid: pid, day: dirDay, ...))

// Later, in reload():
var latestByPID: [String: DatEntry] = [:]
for entry in entries.sorted(by: { $0.day < $1.day }) {
    if let existing = latestByPID[entry.pid] {
        previousByPID[entry.pid] = existing
    }
    latestByPID[entry.pid] = entry
}
```

The deduplication algorithm keeps only the latest-dated `.dat` entry per PID, and the
second-latest as `previousByPID`. The PID's date-folder path is parsed for the `day` field
used in period filtering but is not part of the dictionary key.

Collision scenario: macOS reuses a PID. PID 1234 ran on 2026-03-01 and left a `.dat` file.
On 2026-03-06, a new `claude` process is assigned PID 1234. Both files have the same bare
key `"1234"`. The algorithm will treat the newer day's file as the continuation of the older
session. If the new session's cumulative cost is higher than the old session's, the
incremental dedup logic correctly subtracts the old value. If the new session's cost is
lower (it is a brand new session with lower cost), `max(0, ...)` in `incrementalEntry`
clamps the delta to zero rather than producing a negative cost.

The practical risk is low because:
1. `.dat` files are cleaned up when `AgentTracker.reload()` calls `kill(pid, 0)` and
   removes dead-process `.agent.json` files. However, `.dat` files are only cleaned by the
   shell script's 3-month purge, not by `AgentTracker`.
2. PID reuse across days is uncommon for long-running interactive processes.

**Source:** `Sources/UsageData.swift:114-122`, `Sources/UsageData.swift:159-170`

**Action for rebuilder:** The key is intentionally bare-PID to detect midnight-spanning
sessions (same PID, consecutive days). Do not add date to the key. If PID collision is a
concern in practice, verify with the original app that the `max(0, ...)` clamp in
`incrementalEntry` prevents negative costs from appearing in the UI.

---

## Gap 9: Commander path encoding collision

**Question:** `encodeProjectPath` replaces `/`, `.`, and `_` with `-`. Can two different
paths produce the same encoded string? If so, what happens?

**Answer:** Resolved from source. The encoding is lossy by design, matching Claude Code's
own convention.

```swift
public static func encodeProjectPath(_ path: String) -> String {
    path.replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ".", with: "-")
        .replacingOccurrences(of: "_", with: "-")
}
```

Examples of paths that collide:
- `/Users/foo/my.project` → `-Users-foo-my-project`
- `/Users/foo/my_project` → `-Users-foo-my-project`
- `/Users/foo/my/project` → `-Users-foo-my-project` (if no top-level dir)

There is no collision detection. When two paths encode to the same string, `findActiveSessions()`
will find the same project directory for both processes and return `mostRecentJSONL(in:)` from
that directory for both. This means both processes would be attributed to the same session
file — potentially inflating costs or showing an agent under the wrong working directory.

This function is also used in `AgentTracker.writeSubagentFiles()` to find the subagents
directory. A collision there would cause subagents from one session to be attributed to a
different parent session.

The collision is inherited from Claude Code itself (which uses the same path-encoding
scheme for its project directories). The app cannot resolve it without changing how Claude
Code stores projects, which is outside the app's control.

**Source:** `Sources/Commander/SessionScanner.swift:111-115`

**Action for rebuilder:** Replicate the encoding exactly (all three replacements, in order:
`/` then `.` then `_`). Do not add collision detection — doing so would diverge from
Claude Code's directory layout. Document this limitation. Verify against the original by
creating two projects whose paths differ only by a `.` vs `_` and confirming what the app
shows.

---

## Gap 10: Dominant model detection in subagents

**Question:** In `parseSubagents(in:)` and `parseSubagentDetails(in:meta:)`, which method is
used to pick the "dominant model" for attributing line changes: first seen or most
frequent?

**Answer:** Resolved from source. The two functions use **different strategies**.

**`parseSubagents(in:)`** — uses **first seen**:

```swift
var dominantModel = ""
// ...
if dominantModel.isEmpty { dominantModel = model }
// ...
// Attribute lines to the dominant model for this subagent file
if linesAdded > 0 || linesRemoved > 0, !dominantModel.isEmpty {
    let key = ClaudeModel.from(modelID: dominantModel).displayName
    result[key, default: SourceModelStats()].linesAdded += linesAdded
    result[key, default: SourceModelStats()].linesRemoved += linesRemoved
}
```

`dominantModel` is set once — on the first assistant message with a non-empty model field —
and never updated. Lines are attributed to this first-seen model.

**`parseSubagentDetails(in:meta:)`** — uses **most frequent** (by message count):

```swift
var modelCounts: [String: Int] = [:]
for (_, mu) in usageByMsgID {
    modelCounts[mu.model, default: 0] += 1
    // ...
}
let dominantModel = modelCounts.max(by: { $0.value < $1.value })?.key ?? ""
let displayModel = ClaudeModel.from(modelID: dominantModel).displayName
```

`modelCounts` tallies how many messages used each model, and `max` picks the model with
the highest count. In the event of a tie, `Dictionary.max(by:)` returns an arbitrary entry
(dictionary iteration order is unspecified).

Note that `parseSubagents` uses the dominant model only for line attribution; cost is
tracked per-model for every message. `parseSubagentDetails` uses the dominant model for
the single `displayModel` field on the `SubagentInfo` struct, and cost is summed across
all messages regardless of model.

**Source:** `Sources/Commander/JSONLParser.swift:286-342` (parseSubagents),
`Sources/Commander/JSONLParser.swift:412-424` (parseSubagentDetails)

**Action for rebuilder:** The inconsistency is intentional at the design level — the two
functions serve different consumers. `parseSubagents` feeds the cost-breakdown dictionary
(per-model cost matters more than per-model lines). `parseSubagentDetails` feeds the
drill-down row view (a single display model per subagent is needed). Replicate both
strategies exactly. If refactoring, do not unify them to "most frequent" in `parseSubagents`
without verifying that line attribution results remain acceptable.

---

## Summary Table

| Gap | Title | Status | Risk | Action |
|-----|-------|--------|------|--------|
| 1 | NSPopover positioning | Resolved | Medium | Use `.minY`, `button.bounds`; call `makeKey()` in delegate |
| 2 | CPU sampling strategy | REMOVED | N/A | `cpuUsage(for:)` no longer exists; CPU is always 0; idle uses updatedAt + JSONL mtime |
| 3 | Statusline shell script | Resolved | High | Copy script verbatim; BSD `date -v-3m` syntax is macOS-only |
| 4 | Line counting method | Resolved | Medium | Use `.components(separatedBy:)`, not `.split`; empty string returns count 1 |
| 5 | Model history zero-cost guard | Resolved | High | `guard rawTotal > 0` on midnight-spanning path prevents divide-by-zero |
| 6 | FSEvents + Timer interaction | Resolved | Low | `refreshInFlight` guard deduplicates; FSEvents latency is 2.0s |
| 7 | AgentTracker subagent scanning thread model | Resolved | Medium | `writeSubagentFiles` runs on dedicated serial queue; no per-PID `ps` CPU calls; single batch `verifyClaudePIDs`; cache uses max file mtime |
| 8 | PID reuse collision | Resolved | Low | Key is bare PID; `max(0,...)` clamp prevents negative costs from PID reuse |
| 9 | Commander path encoding collision | Resolved | Low | Lossy by design; inherited from Claude Code; do not add collision detection |
| 10 | Dominant model detection | Resolved | Medium | `parseSubagents` uses first-seen; `parseSubagentDetails` uses most-frequent — intentionally different |
