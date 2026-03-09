# Agent Breakdown Screen Specification

## Overview

The agent breakdown screen is `SubagentDetailView.swift`. It is navigated to by tapping an agent row on the main screen (`selectedAgent = agent` in `PopoverView`). It shows a summary of the selected agent, the tool calls made in the parent session, and a scrollable list of the subagents that ran within that session.

The view is always 320pt wide with 16pt padding on all sides, matching all other views in the popover.

---

## Navigation

- **Back button**: Top-left, `chevron.left` + `"Back"` text, `.plain` style, `.blue` foreground. Font adapts via `navFont`: `.caption` in popover mode, `.body` in window mode.
  - On tap: calls `onDismiss()` which sets `selectedAgent = nil` in `PopoverView`
- **Title**: Top-right, `agent.displayName` (agent name if non-empty, else model name). Font adapts via `titleFont`: `.headline` in popover mode, `.title3` in window mode.
- **Log viewer button**: To the right of the title, `doc.text.magnifyingglass` icon, font uses `navFont` (`.caption` / `.body`), `.plain` style, `.blue` foreground. Only shown when `!agent.sessionID.isEmpty`. On tap: sets `logTarget = .parent`, navigating to `LogViewerView` for the parent session.

```
← Back                         My Agent Name  [log]
─────────────────────────────────────────────────
```

---

## Agent Summary

Below the first divider, a compact summary of the parent agent. Layout is a two-column `Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4)`.

```
my-project                     Total  $1.23
2m 30s                      Subagents  $0.50
+42  -5
[=========░░░░░░░░░░░░░░] 45% · 1M
```

### Grid Row 1 — Left cell + Right cell

**Left cell** — `VStack(alignment: .leading, spacing: 4)`, `frame(maxWidth: .infinity, alignment: .leading)`:
- `agent.shortDir` — last path component of the working directory; `.caption` + `.secondary`
- `agent.durationText` — formatted session duration (`"Nm Ns"` or `"NhNm"`); `.caption2` + `.tertiary`
- `HStack(spacing: 6)` of lines-added/removed:
  - `"+{linesAdded formatted as compactName}"` — `.caption2` + `.green`
  - `"-{linesRemoved formatted as compactName}"` — `.caption2` + `.red`

**Right cell** — `HStack(alignment: .top, spacing: 4)`, `gridColumnAlignment(.trailing)`:

Two `VStack(alignment: .trailing, spacing: 4)` side-by-side — a label column and a number column — guaranteeing alignment regardless of text length:

- **Left VStack** (labels, trailing-aligned):
  - `Text("Total")` — `.caption2` + `.tertiary`
  - `Text("Subagents")` — `.caption2` + `.tertiary` — only shown when `subTotal > 0`
- **Right VStack** (numbers, trailing-aligned):
  - `Text("$%.2f", agent.cost)` — `.caption` + `.semibold` + `.orange`
  - `Text("$%.2f", subTotal)` — `.caption2` + `.tertiary` — only shown when `subTotal > 0`

### Total vs Subagents cost semantics

- **`agent.cost` (Total)** = `total_cost_usd` from the `.agent.json` statusline. This is the authoritative cost for the parent session and includes all subagent costs once each subagent's JSONL has been flushed and the parent session responds with updated totals.
- **`subTotal`** = sum of `sub.cost` over all loaded `SubagentInfo` records. This is computed directly from the subagent JSONL files by `JSONLParser.parseSubagentDetails`. It is an informational figure — the costs it represents are already baked into `agent.cost` once the parent updates.
- **During active execution**: `subTotal` may temporarily exceed `agent.cost` because the statusline lags until the parent session writes its next `.agent.json`. This is expected and transient.
- The "Subagents" row is omitted entirely when `subTotal == 0` (no subagent data loaded yet, or no subagents).

### Grid Row 2 — Context bar (full-width)

Shown only when `agent.contextPercent > 0`. Uses `gridCellColumns(2)` to span both columns:

```swift
GridRow {
    HStack(spacing: 8) {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(ctxColor.opacity(0.2))
                RoundedRectangle(cornerRadius: 2).fill(ctxColor)
                    .frame(width: geo.size.width * CGFloat(agent.contextPercent) / 100)
            }
        }
        .frame(height: 6)
        Text("\(agent.contextPercent)%\(agent.contextWindowText.isEmpty ? "" : " · \(agent.contextWindowText)")")
            .font(.caption2).foregroundStyle(ctxColor)
            .fixedSize()
    }
    .gridCellColumns(2)
}
```

- The `GeometryReader` bar fills all available horizontal space (no fixed width).
- The label uses `.fixedSize()` to prevent wrapping.
- Color: `.green` (< 70%), `.yellow` (70–89%), `.red` (≥ 90%).

### Duration Formatting

Duration comes from `agent.durationMs` (Double, milliseconds). Formatting logic in `AgentInfo.durationText`:

```
totalSec = Int(ms) / 1000
mins = totalSec / 60
secs = totalSec % 60
if mins < 60 → "{mins}m {secs}s"
else         → "{mins/60}h {mins%60}m"
```

---

## Tools Used Section

Shown below a `Divider()` only when `parentTools` (the view's local `@State`) is non-empty.

```
Tools Used
[Read (15)] [Edit (42)] [Bash (7)] [Write (3)] [TodoRead]
[TodoWrite (2)]
```

Layout:
- `Text("Tools Used")` — `.subheadline` + `.medium`
- `FlowLayout(spacing: 4, maxLines: 5)` containing `ForEach(sorted, id: \.key)`:
  - Sort: by count descending (`tools.sorted { $0.value > $1.value }`)
  - Each chip: `Text(count > 1 ? "\(tool) (\(count))" : tool)`
    - `.system(size: 10)` font, `.secondary` foreground
    - `.padding(.horizontal, 5)` + `.padding(.vertical, 2)`
    - Background: `Color.primary.opacity(0.06)` in `RoundedRectangle(cornerRadius: 4)`
- If the tool appears only once, the count is not shown (just the tool name)
- `maxLines: 5` — chips wrap across up to 5 lines; overflow chips are truncated

Data source: `parentTools` — a `@State private var parentTools: [String: Int]` populated by `loadFromFile()` reading `{pid}.parent-tools.json` from the usage directory. This file is written by `AgentTracker.writeSubagentFiles` via `JSONLParser.parseParentTools`.

---

## Subagents Section Header

Below the next `Divider()`:

```
Subagents  [3]                       Budget: 1M
```

- Left: `"Subagents"` label, `.subheadline` + `.medium`
- Count badge (only shown if `!subagents.isEmpty`): `Text("\(subagents.count)")` — `.caption2` + `.secondary`, `.padding(.horizontal, 5)` + `.padding(.vertical, 2)`, `Color.primary.opacity(0.08)` background in `Capsule()`
- Spacer
- Right: `"Budget: {settings.subagentContextBudget.label}"` — `.caption2` + `.secondary`

The budget label is informational only at this level. The actual context percentage calculation in each row uses `settings.subagentContextBudget.tokens`.

---

## Subagent List

### Container

When `subagents` is non-empty:

```swift
ScrollView {
    VStack(spacing: rowSpacing) {
        ForEach(Array(sortedSubagents.enumerated()), id: \.element.id) { idx, sub in
            subagentRow(sub)
                .contentShape(Rectangle())
                .onTapGesture { logTarget = .subagent(sub) }
                .background(GeometryReader { geo in
                    Color.clear.preference(key: RowHeightsKey.self, value: [idx: geo.size.height])
                })
        }
    }
}
.scrollIndicators(.never)
.frame(height: viewportHeight)
.onPreferenceChange(RowHeightsKey.self) { heights in
    rowHeights = heights
}
```

`sortedSubagents` is a computed property that sorts the `subagents` array according to `settings.subagentSortOrder`. Each row has a tap gesture that sets `logTarget = .subagent(sub)`, navigating to `LogViewerView` for that subagent's JSONL conversation.

`rowSpacing = 6pt`. Scroll indicators are hidden.

### Viewport Height Calculation

The `ScrollView`'s height is set to `viewportHeight`, which depends on the display mode:

**Window mode**: `viewportHeight` always returns `nil` — the scroll view fills available space without a fixed height.

**Popover mode**: The height is the sum of the first `min(subagents.count, settings.maxVisibleSubagents)` rows' actual rendered heights plus inter-row spacing:

```swift
private var viewportHeight: CGFloat? {
    if settings.displayMode == .window { return nil }
    let n = min(subagents.count, settings.maxVisibleSubagents)
    guard rowHeights.count >= n else { return nil }
    let h = (0..<n).compactMap { rowHeights[$0] }.reduce(0, +)
    return h + rowSpacing * CGFloat(max(0, n - 1))
}
```

Returns `nil` until `RowHeightsKey` preferences have been collected for all N rows. The `.frame(height: viewportHeight)` call with a `nil` height lets the ScrollView size naturally until heights are known — then snaps to the precise N-row viewport.

This uses real rendered heights (via `RowHeightsKey` `PreferenceKey`) rather than a fixed constant, so variable-height rows (e.g. rows with more tool chips) are accounted for correctly.

### SubagentRowsLayout (not used in current implementation)

`SubagentRowsLayout` is defined in the file as a private `Layout` that computes the total height of all rows (enabling `ScrollView` to know the full content height). It is available but the current `VStack`-based approach inside `ScrollView` is what the view actually uses for rendering rows.

### RowHeightsKey PreferenceKey

```swift
private struct RowHeightsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}
```

Each row reports its rendered height via `GeometryReader` + `.preference(key: RowHeightsKey.self, value: [idx: geo.size.height])`. The `reduce` function merges all row heights into a single `[Int: CGFloat]` dictionary keyed by row index.

### Subagent Row Layout

```
Opus 4.6                    +42   -0    $0.23
Explore UI navigation and views
Explore
[========░░░░] 45% of 1M
[Read (15)] [Edit (42)] [Bash (1)]
```

`subagentRow(_:)` returns a `VStack(alignment: .leading, spacing: 6)` with 8pt padding and `Color.primary.opacity(0.08)` background in `RoundedRectangle(cornerRadius: 6)`.

Tapping a subagent row navigates to `LogViewerView` with `logTarget = .subagent(sub)` — showing the full JSONL conversation for that subagent.

**Row 1 — Model + Lines + Cost (HStack):**
- Model name: `sub.model` (display name e.g. `"Opus 4.6"`); `.caption` + `.medium`; lineLimit 1
- `Spacer(minLength: 4)`
- Lines added: `"+{sub.linesAdded}"` (raw integer, not compact); `.caption2` + `.green`; `minWidth: 36`, trailing alignment
- Lines removed: `"-{sub.linesRemoved}"` (raw integer); `.caption2` + `.red`; `minWidth: 32`, trailing alignment
- Cost: `"$%.2f"` format; `.caption` + `.semibold` + `.orange`; `minWidth: 48`, trailing alignment

**Row 1.5 — Description + Type (optional):**
- If `sub.description` is non-empty: `Text(sub.description)` — `.caption` + `.secondary`; lineLimit 1
- If `sub.subagentType` is non-empty: `Text(sub.subagentType)` — `.caption2` + `.secondary`; lineLimit 1
- These come from `JSONLParser.parseSubagentMeta` which parses Agent tool_use calls in the parent JSONL

**Row 2 — Context Bar + Label (HStack, spacing 8pt):**
- Context bar: fixed 80×6pt `GeometryReader`-backed `ZStack`:
  - Background fill: `color.opacity(0.2)`, `RoundedRectangle(cornerRadius: 2)`
  - Foreground fill: `color`, width = `80 * contextPct / 100`
  - Color: `.green` (< 70%), `.yellow` (70–89%), `.red` (≥ 90%)
- Label: `"{contextPct}% of {budget.label}"` — `.caption2` in `color`

**Row 3 — Tool Chips (only shown if `!sub.toolCounts.isEmpty`):**
- `FlowLayout(spacing: 4, maxLines: 5)` containing sorted tool chips (same chip style as parent tools section)
- Sort: by count descending
- Chip text: `count > 1 ? "\(tool) (\(count))" : tool`

### Context Percentage Calculation

```swift
contextPct = min(100, Int(Double(sub.lastInputTokens) / Double(settings.subagentContextBudget.tokens) * 100))
```

- `sub.lastInputTokens`: the total input token count of the last message in the subagent's JSONL file (input + cacheCreation + cacheRead)
- `settings.subagentContextBudget.tokens`: 200,000 or 1,000,000 depending on user setting
- Clamped to 100 (no overflow beyond full bar)

#### Why a User-Configured Budget?

Subagents do not necessarily have the same context window as the parent agent. The app does not know at display time what model the subagent will use next, so it lets the user choose a budget that matches their typical subagent model (200K for Sonnet/Haiku, 1M for Opus).

---

## Empty State

If `subagents` is empty:

```
No subagents recorded for this session
```

- `.caption` + `.tertiary`
- 8pt vertical padding

This occurs when:
- The session has no subagents directory
- The subagent directory exists but contains no `.jsonl` files
- The `{pid}.subagent-details.json` file does not exist in the usage directory (AgentTracker has not scanned it yet)

---

## Data Loading

Data is loaded via `.task { ... }` on the view, which starts an async polling loop:

```swift
.task {
    await loadFromFile()
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        await loadFromFile()
    }
}
```

The task cancels automatically when the view disappears (SwiftUI `.task` lifetime is tied to the view).

### loadFromFile()

```swift
private func loadFromFile() async {
    let (details, tools) = await Task.detached(priority: .utility) {
        let details = (try? Data(contentsOf: dir.appendingPathComponent("\(pid).subagent-details.json")))
            .flatMap { try? JSONDecoder().decode([SubagentInfo].self, from: $0) } ?? []
        let tools = (try? Data(contentsOf: dir.appendingPathComponent("\(pid).parent-tools.json")))
            .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
        return (details, tools)
    }.value
    if !details.isEmpty { subagents = details }
    if !tools.isEmpty { parentTools = tools }
}
```

1. Formats today's date as `"yyyy-MM-dd"`
2. Resolves usage directory based on `agent.source`:
   - `.cli` → `~/.claude/usage/`
   - `.commander` → `~/.claude/usage/commander/`
3. Builds paths in `{usageDir}/{today}/`:
   - `{agent.pid}.subagent-details.json` — decoded as `[SubagentInfo]`
   - `{agent.pid}.parent-tools.json` — decoded as `[String: Int]`
4. Both file reads run together on a single detached task with `.utility` priority (background thread)
5. If `details` is non-empty, updates `subagents` state; if `tools` is non-empty, updates `parentTools` state
6. Polling interval: 2 seconds between each `loadFromFile()` call

No loading indicator is shown. The empty state ("No subagents recorded") appears immediately while the file is being loaded or if the file does not exist.

### SubagentInfo Fields Read

| Field | Type | Description |
|-------|------|-------------|
| `agentID` | String | Filename stem of the subagent JSONL (e.g. `"agent-abc123"`) |
| `model` | String | Display model name (e.g. `"Opus 4.6"`) |
| `cost` | Double | Total USD cost for this subagent |
| `lastInputTokens` | Int | Total input tokens in last message (for context %) |
| `linesAdded` | Int | Lines added by Edit/Write tool calls |
| `linesRemoved` | Int | Lines removed by Edit/Write tool calls |
| `toolCounts` | [String: Int] | Tool name → invocation count across all messages |
| `description` | String | Subagent description from Agent tool_use (e.g. `"Explore UI navigation"`) |
| `subagentType` | String | Subagent type from Agent tool_use (e.g. `"Explore"`) |
| `lastModified` | Double | JSONL file mtime as `timeIntervalSince1970` |

Subagents are sorted by cost descending (highest cost first) when written by `JSONLParser.parseSubagentDetails`. The display sort order is controlled by `AppSettings.subagentSortOrder` in `SubagentDetailView.sortedSubagents`:

| Sort Order | Key |
|------------|-----|
| Recent | `sub.lastModified` descending (JSONL file mtime) |
| Cost | `sub.cost` descending |
| Context | `sub.lastInputTokens` descending |
| Name | `sub.displayName` ascending (localized case-insensitive) |

---

## AgentTracker Threading

`writeSubagentFiles()` runs on a dedicated serial `DispatchQueue` to prevent data races when multiple reload cycles overlap:

```swift
private let subagentQueue = DispatchQueue(label: "com.swiftgurus.subagentScanner", qos: .utility)

// In reload():
subagentQueue.async { [weak self] in
    self?.writeSubagentFiles(agents: agentsSnapshot, todayStr: todayStr)
}
```

Observable property mutations (`subagentDetails`, `parentToolCounts`) are dispatched back to the main thread:

```swift
DispatchQueue.main.async { [weak self] in
    self?.subagentDetails[pid] = details
}
// ...
DispatchQueue.main.async { [weak self] in
    self?.parentToolCounts[pid] = counts
}
```

### subagentCache Invalidation

The cache key is the **maximum individual file mtime** across all files in the subagents directory — not the directory mtime. This correctly detects both new subagent files appearing and growth in existing subagent files (which would not change the directory mtime):

```swift
let maxMtime = files.compactMap {
    try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
}.max() ?? Date.distantPast
guard subagentCache[agent.sessionID]?.mtime != maxMtime else { continue }
```

A separate `parentToolCache` keyed by session ID tracks the parent JSONL mtime, so parent tool counts are only re-parsed when the JSONL file changes.

---

## Parent Tool Counts — File Persistence

Parent tool counts are written to `{pid}.parent-tools.json` alongside `{pid}.subagent-details.json` in the same usage directory:

```swift
try? data.write(
    to: todayDir.appendingPathComponent("\(agent.pid).parent-tools.json"),
    options: .atomic
)
```

`SubagentDetailView.loadFromFile()` polls both files every 2 seconds. This means the detail view does not depend on `agentTracker.parentToolCounts` being populated in memory — it reads the persisted file directly, which is important when the view opens after the agent has finished.

---

## Settings Consumed

| Setting | Type | Default | Used for |
|---------|------|---------|----------|
| `maxVisibleSubagents` | Int | 5 | Number of rows visible before scroll (popover mode only); options: 3, 5, 8, 10, 15 |
| `subagentContextBudget` | SubagentContextBudget | `.m1` | Denominator for context % per subagent row |
| `subagentSortOrder` | SubagentSortOrder | `.cost` | Sort order for subagent list; options: Recent, Cost, Context, Name |
| `displayMode` | DisplayMode | `.popover` | Controls viewport height behavior (nil in window mode) and adaptive font sizes |
| `expandThinking` | Bool | `false` | Initial expand state for thinking blocks in log viewer |
| `expandTools` | Bool | `false` | Initial expand state for tool call details in log viewer |

---

## Adaptive Font Sizes for Window Mode

The view defines two computed font properties that adapt based on `settings.displayMode`:

```swift
private var navFont: Font { settings.displayMode == .window ? .body : .caption }
private var titleFont: Font { settings.displayMode == .window ? .title3 : .headline }
```

| Element | Popover mode | Window mode |
|---------|-------------|-------------|
| Back button (`navFont`) | `.caption` | `.body` |
| Agent name title (`titleFont`) | `.headline` | `.title3` |
| Log viewer button (`navFont`) | `.caption` | `.body` |

In window mode, the navigation header (back button + title + log icon) is pinned above the scrollable content via a separate `VStack` with `.padding(.horizontal, 16)`. The `ScrollView` only wraps `detailContent`, keeping the header sticky.

---

## Full View Structure (ASCII)

```
┌──────────────────────────────────────────────────┐
│ ← Back                    My Agent Name  [log]   │
├──────────────────────────────────────────────────┤
│ my-project                    Total      $1.23   │
│ 2m 30s                     Subagents    $0.50   │
│ +42  -5                                          │
│ [=========░░░░░░░░░░░░░░░░░] 45% · 1M            │
├──────────────────────────────────────────────────┤
│ Tools Used                                        │
│ [Read (15)] [Edit (42)] [Bash (7)] [Write (3)]   │
│ [TodoWrite (2)]                                   │
├──────────────────────────────────────────────────┤
│ Subagents [3]                      Budget: 1M     │
│ ┌────────────────────────────────────────────┐   │
│ │ Opus 4.6              +42   -0    $0.23    │   │
│ │ Explore UI navigation and views            │   │
│ │ Explore                                    │   │
│ │ [========░░░░░░░░░░░] 45% of 1M           │   │
│ │ [Read (15)] [Edit (42)] [Bash (1)]        │   │
│ ├────────────────────────────────────────────┤   │
│ │ Sonnet 4.5             +8   -2    $0.04   │   │
│ │ [=░░░░░░░░░░░░░░░░░░░] 10% of 1M         │   │
│ │ [Read (3)] [Write (2)]                    │   │
│ ├────────────────────────────────────────────┤   │
│ │ Sonnet 4.5             +0   -0    $0.01   │   │
│ │ [░░░░░░░░░░░░░░░░░░░░]  3% of 1M         │   │
│ └────────────────────────────────────────────┘   │
│  ↕ scrolls when > maxVisibleSubagents (popover)   │
│  tap row → LogViewerView for that subagent        │
└──────────────────────────────────────────────────┘
```

---

## Edge Cases

- **Subagent with zero lines**: Both `+0` and `-0` are displayed. No special suppression.
- **Very high context usage (≥ 90%)**: Bar and label text both turn red.
- **More subagents than `maxVisibleSubagents`**: The ScrollView clips to the precise N-row height; additional rows are accessible by scrolling. Scroll indicators are hidden.
- **Agent with no session ID**: `AgentTracker` only scans subagents for agents where `!agent.sessionID.isEmpty`. If sessionID is absent, `{pid}.subagent-details.json` will never be written and the detail view will always show the empty state.
- **Commander vs CLI source**: The correct usage directory is selected based on `agent.source` so that Commander agent subagents are read from `~/.claude/usage/commander/YYYY-MM-DD/` rather than the CLI folder.
- **No parent tool counts**: The "Tools Used" section is omitted entirely if the local `parentTools` state is empty (file not yet written or contains no tools).
- **Variable row heights**: Rows with more tool chips are taller than rows with fewer. The `RowHeightsKey` PreferenceKey captures each row's actual rendered height, so the viewport always shows exactly N rows regardless of their individual heights.
- **viewportHeight nil state**: Until `RowHeightsKey` collects heights for all N rows, `viewportHeight` returns `nil` and the `.frame(height:)` has no effect — the ScrollView expands naturally. Once heights arrive, the frame snaps to the precise value.
- **subTotal temporarily exceeds agent.cost**: During active subagent execution, the sum of subagent JSONL costs may exceed the statusline total because the parent session has not yet flushed an updated `.agent.json`. This is expected and resolves automatically.
- **Overlapping reload cycles**: `writeSubagentFiles()` runs on a serial `DispatchQueue`, so concurrent reload triggers never race on the cache dictionaries or file writes.
