# Main Screen Specification

## Overview

The main screen is the default view rendered inside the `NSPopover` (popover mode) or `NSPanel` (window mode). It is implemented as `mainView` inside `PopoverView.swift`. The content area has a minimum width of 320pt, padded 16pt on all sides. In window mode, the content is wrapped in a `ScrollView` with visible scroll indicators. Navigation replaces the main view in-place (no sheet or push stack); the `@State` variables `showSettings`, `selectedAgent`, and `selectedPeriod` control which view is visible. The view applies `.preferredColorScheme(settings.appearanceMode.colorScheme)` to control light/dark appearance.

---

## Status Bar Item

### Appearance
- System icon: `chart.bar.fill` (SF Symbol), positioned leading
- Variable-length NSStatusItem (grows to fit text)
- Title format: `"{prefix}: ${cost}"` where cost is formatted to 2 decimal places
  - Example: `"D: $1.23"`, `"W: $14.50"`, `"M: $102.00"`

### Prefix Values (from `StatusBarPeriod`)
| Enum case | Prefix | Label |
|-----------|--------|-------|
| `.day`    | `D`    | Today |
| `.week`   | `W`    | Week  |
| `.month`  | `M`    | Month |

### When It Updates
- On every `UsageData.reload()` call (triggered by FSEvent or 5-second poll)
- Immediately when the user changes the status bar period in Settings (via `withObservationTracking` — re-subscribes after each change)
- On popover open (after the background refresh completes)

### Period Selection
The displayed period is controlled by `AppSettings.statusBarPeriod`. Changing it in the Settings view immediately updates the status bar title. The setting persists across launches via `UserDefaults` key `ClaudeUsageBar.statusBarPeriod`.

---

## Loading State

When the popover opens:
1. `settings.isLoading = true` is set synchronously before the popover is shown
2. The popover opens and renders immediately with whatever data was loaded at app launch or the last background refresh — stale data is shown rather than a blank screen
3. `CommanderSupport.refreshFiles()` runs on a background thread (`.userInitiated` QoS)
4. On main thread completion: `usageData.reload()`, `agentTracker.reload()`, `updateStatusItemTitle()`, then `settings.isLoading = false`

Loading affects only the agents section. The period table always shows the last-known values immediately. If no agents are present AND `settings.isLoading == true`, a spinner with "Loading active agents..." text appears instead of "No active agents".

---

## Period Table

Rendered as a SwiftUI `Grid` with trailing alignment.

### Columns
```
Label        Cost     +Lines    -Lines
─────────────────────────────────────
Today        $0.42    +1.2K     -834
Week         $3.15    +8.4K     -3.1K
Month        $18.90   +42K      -18K
```

- **Label column**: `.subheadline` + `.medium` weight, left-aligned; includes a trailing chevron (`chevron.right`, size 8, `.tertiary`)
- **Cost column**: `.subheadline` + `.semibold` weight, `.orange` foreground
- **+Lines column**: `.caption`, `addedColor` (green, adapts to dark mode)
- **-Lines column**: `.caption`, `removedColor` (red, adapts to dark mode)
- Vertical spacing: 8pt between rows
- Header row: `Cost`, `+Lines`, `-Lines` labels in `.caption2` + `.secondary`

### Tap Behavior
Each row has a `contentShape(Rectangle())` and `.onTapGesture` that sets `selectedPeriod = label` (e.g. `"Today"`, `"Week"`, `"Month"`). This triggers navigation to `detailView`.

### Line Count Formatting
Uses `.number.notation(.compactName)` — e.g. `1234` → `"1.2K"`, `1234567` → `"1.2M"`. The `+` and `-` prefixes are prepended manually.

---

## Agent Section

### Layout: Sticky Header/Footer with Scrollable Agents

The main view is **not** wrapped in a `ScrollView` (in popover mode). Instead, the header (title + gear icon), period table, statusline indicator, and quit button remain sticky. Only the agent section scrolls, using a `ScrollView` with `.scrollIndicators(.never)` and a computed `agentViewportHeight` frame.

In window mode, the entire `mainView` is wrapped in an outer `ScrollView` by `PopoverView.content`, so `agentViewportHeight` returns `nil` (no fixed height constraint).

### Flat Agent List with AgentListItem

Agents are grouped by `AgentSource` (`.cli` and `.commander`), in that order. A source group is omitted entirely if it has no agents. The groups are flattened into a single `allAgentsFlat` array of `AgentListItem` enum values:

```swift
private enum AgentListItem: Identifiable {
    case header(SourceGroup)
    case agent(AgentInfo)
}
```

The flat list is built by iterating `groupedSources` and appending `.header(group)` followed by `.agent(a)` for each active agent then each idle agent. This flat structure enables indexed height measurement via `AgentRowHeightsKey`.

### AgentRowHeightsKey PreferenceKey

```swift
private struct AgentRowHeightsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}
```

Each item in `allAgentsFlat` is wrapped in a `GeometryReader` that reports its rendered height via `.preference(key: AgentRowHeightsKey.self, value: [idx: geo.size.height])`. The collected `agentRowHeights` dictionary is used to compute `agentViewportHeight`.

### agentViewportHeight

In popover mode, the viewport height is computed to show exactly `settings.maxVisibleAgents` agent cards (headers do not count toward the limit):

```swift
private var agentViewportHeight: CGFloat? {
    if settings.displayMode == .window { return nil }
    // Count flat items needed to show N agent cards
    var agentsSeen = 0; var n = 0
    for item in allAgentsFlat {
        n += 1
        if case .agent = item { agentsSeen += 1 }
        if agentsSeen >= settings.maxVisibleAgents { break }
    }
    guard agentRowHeights.count >= n else { return nil }
    let h = (0..<n).compactMap { agentRowHeights[$0] }.reduce(0, +)
    return h + agentRowSpacing * CGFloat(max(0, n - 1))
}
```

`agentRowSpacing` is 6pt. Returns `nil` in window mode or until all heights are collected.

### Source Section Header
```
[icon] CLI                           3
```
- Icon: `terminal` for CLI, `app.connected.to.app.below.fill` for Commander (`.caption`, `.secondary`)
- Source name: `.subheadline` + `.medium` weight
- Agent count: `.caption` + `.secondary` (total of active + idle in this source)

### Within Each Source Group
Active (non-idle) agents are listed first, followed by idle agents. Both are sorted according to `AppSettings.agentSortOrder` before grouping:
- `.recentlyUpdated`: sorted by `updatedAt` descending
- `.cost`: sorted by `cost` descending
- `.contextUsage`: sorted by `contextPercent` descending

### Agent Row Layout (3 rows per agent)

```
[dot] Display Name                     $1.23
[context bar] [pct%] · [windowSize]    5m 30s
[folder] shortDir            +1.2K  -834
```

**Row 1 — Name + Cost:**
- Status indicator: `circle.fill` (8pt) — green if active, grey/moon if idle
- `displayName`: agent name if non-empty, else model name; `.caption` + `.medium`; lineLimit 1
- Idle duration text (only when idle): e.g. `"5m idle"`, `"1h 30m idle"`; `.caption2`
- Cost: `"$%.2f"` format; `.caption` + `.semibold` + `.orange`

**Row 2 — Context + Duration:**
- Context bar: 60×6pt filled rectangle. Color: green (<70%), yellow (70–89%), red (≥90%)
- Context % label: `"N%"` or `"N% · 1M"` (window label omitted if contextWindow ≤ 0)
- Clock icon + duration text: `"Nm Ns"` or `"NhNm"`; `.caption2` + `.secondary`

**Row 3 — Directory + Lines:**
- Folder icon + `shortDir` (last path component); `.caption2` + `.secondary`; lineLimit 1
- Lines added: `"+{compact}"` in `addedColor`
- Lines removed: `"-{compact}"` in `removedColor`
- Both in `.caption2`

**Row Container:**
- 8pt padding on all sides
- Background: `Color.primary.opacity(0.08)` in `RoundedRectangle(cornerRadius: 6)`
- Opacity: 0.85 (dark) / 0.6 (light) when idle, 1.0 when active
- `.contentShape(Rectangle())` + `.onTapGesture { selectedAgent = agent }` — navigates to `SubagentDetailView`

### Color Adaptation (Dark/Light Mode)
| Token | Dark mode | Light mode |
|-------|-----------|------------|
| `idleColor` | `Color(white: 0.7)` | `.gray` |
| `addedColor` | `.green` | `Color(red: 0.1, green: 0.55, blue: 0.1)` |
| `removedColor` | `Color(red: 1.0, green: 0.4, blue: 0.4)` | `.red` |

---

## Empty / Loading States

### No Active Agents (not loading)
```
No active agents
```
- `.caption` + `.tertiary`
- Full-width, left-aligned
- 4pt vertical padding

### Loading Active Agents
```
[spinner] Loading active agents...
```
- `ProgressView` at `.small` control size, scaled to 0.8
- Text: `.caption` + `.secondary`
- Only shown when `settings.isLoading == true` AND `workingAgents.isEmpty && idleAgents.isEmpty`

---

## Open Project Button

Displayed below the agent section, separated by a `Divider`.

```
[+circle.fill] Open Project
```

- Icon: `plus.circle.fill` in `.blue`
- Text: "Open Project" in `.caption` + `.medium` weight
- Full-width left-aligned, `.plain` button style
- Separated by `Divider`s above and below

### Action

1. Opens `NSOpenPanel` configured for directories only (`canChooseDirectories: true`, `canChooseFiles: false`, `allowsMultipleSelection: false`)
2. Panel message: "Select a project directory to open with Claude"
3. Panel prompt button: "Open"
4. On selection: `sessionManager.spawn(workingDir: url.path)` creates a `TTYBridge` and spawns `claude` under a hidden PTY
5. Constructs a synthetic `AgentInfo` with:
   - `pid`: `bridge.childPID`
   - `model`: `"Starting..."`
   - `sessionID`: `""` (empty, will be discovered by JSONL polling)
   - `workingDir`: selected directory path
   - `isIdle`: `false`, `source`: `.cli`
6. Sets `selectedAgent = syntheticAgent`, navigating immediately to `SubagentDetailView`
7. From there, the user navigates to `LogViewerView` where the input field is enabled via the `TTYBridge`

### Dependencies

Requires `SessionManager` (passed as a constructor parameter to `PopoverView`). The `SessionManager` is created in `AppDelegate` with a `FileDebugLogger(isEnabled: true)`.

---

## Statusline Install Indicator

Displayed below the Open Project button, above the Quit button.

```
[checkmark.circle.fill] Statusline active
```
or
```
[xmark.circle.fill] Statusline not configured         [Install]
```
or
```
[xmark.circle.fill] Install failed — check jq is installed
```

- Icon: green checkmark if installed, red X if not
- Text: `.caption` + `.secondary`
- Install button: `.caption` font, only visible when not installed
  - On tap: calls `StatuslineInstaller.install()`, updates local `@State var installed` and `installError`
  - Install failure shows error text (jq dependency message) with no retry button

---

## Quit Button

- Label: `"Quit"`, `.plain` button style, `.secondary` foreground, `.caption` font
- Action: `NSApplication.shared.terminate(nil)`
- Positioned at bottom of main view

---

## Navigation Summary

| User Action | State Change | Resulting View |
|-------------|--------------|----------------|
| Tap gear icon | `showSettings = true` | `SettingsView` |
| Tap period row | `selectedPeriod = label` | `detailView(label:stats:)` |
| Tap agent row | `selectedAgent = agent` | `SubagentDetailView` |
| Tap "Open Project" | `selectedAgent = syntheticAgent` | `SubagentDetailView` (with new session) |
| Tap Back in Settings | `showSettings = false` | Main view |
| Tap Back in Detail | `selectedPeriod = nil` | Main view |
| Tap Back in Agent Detail | `selectedAgent = nil` | Main view |
| Tap log icon in Agent Detail | `logTarget = .parent` | `LogViewerView` (parent session) |
| Tap subagent row in Agent Detail | `logTarget = .subagent(sub)` | `LogViewerView` (subagent session) |
| Tap Back in Log Viewer | `logTarget = nil` | `SubagentDetailView` |
| Tap Stop in Log Viewer | bridge.detach(), session removed | Parent view (via `onStop`) |

The top-level navigation is managed by a single `if/else if/else if/else` chain in `PopoverView.body`. Within `SubagentDetailView`, a secondary `logTarget` state controls navigation to `LogViewerView`. There is no navigation stack — only one view is visible at a time and state is replaced, not pushed.

### Window Mode Adaptive Fonts

Navigation headers in child views (detail view, settings, subagent detail) use adaptive fonts based on `settings.displayMode`:

| Element | Popover mode | Window mode |
|---------|-------------|-------------|
| Back button | `.caption` | `.body` |
| Screen title | `.headline` | `.title3` |

This provides larger, more readable text when the app runs in a floating window rather than the compact popover.
