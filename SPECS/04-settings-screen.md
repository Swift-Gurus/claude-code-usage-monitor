# Settings Screen Specification

## Overview

The settings screen is `SettingsView.swift`. It is shown when the user taps the gear icon (`gearshape`) in the main screen header. It uses a `@Bindable` reference to `AppSettings` — changes are reflected immediately without requiring confirmation.

The view is 320pt wide. `SettingsView` itself does not apply padding -- `PopoverView` provides 16pt padding on all sides (via `.padding(16)` on the wrapping context). In window mode, `PopoverView` wraps the settings view in a `ScrollView` before applying padding.

---

## Navigation

- **Back button**: Top-left, `chevron.left` + `"Back"` text, `.plain` style, `.blue` foreground. Font adapts: `.caption` in popover mode, `.body` in window mode.
  - On tap: calls `onDismiss()` which sets `showSettings = false` in `PopoverView`
- **Title**: Top-right, `"Settings"`. Font adapts: `.headline` in popover mode, `.title3` in window mode.

```
← Back                                   Settings
─────────────────────────────────────────────────
```

---

## Display Mode Setting

**Label**: `"Display Mode"` — `.subheadline` + `.medium`

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Raw value |
|---------|---------|-----------|
| Popover | `"Popover"` | `"popover"` |
| Window  | `"Window"`  | `"window"` |

**Behavior**:
- Selection bound to `$settings.displayMode`
- `AppSettings.displayMode.didSet` writes `rawValue` to `UserDefaults.standard` under key `"ClaudeUsageBar.displayMode"`
- Below the picker: an "Apply & Restart" button (`borderedProminent` style, `controlSize(.small)`, full-width). Disabled when `!settings.displayModeChanged`. On tap, calls `AppSettings.relaunch()` which spawns a new instance via `open -n` and terminates the current app after 0.3s.
- `AppSettings.launchedDisplayMode` stores the mode used at app launch (set once in `init()`, never changes). `displayModeChanged` is a computed property: `displayMode != launchedDisplayMode`.
- Default value is `.popover` if no saved preference exists.

**Window mode effects** (when `displayMode == .window`):
- The app uses an `NSPanel` instead of an `NSPopover` (see Spec 00 and Spec 13 for architecture details)
- `PopoverView.body` wraps its content in a `ScrollView` with visible scroll indicators
- `SubagentDetailView.viewportHeight` returns `nil` (no fixed viewport, scroll fills available space)
- `LogViewerView.scrollHeight` returns `nil` (no fixed scroll height)
- The "Visible Agents Before Scroll", "Visible Subagents Before Scroll", and "Visible Log Messages Before Scroll" settings are hidden in the settings view

---

## Appearance Mode Setting

**Label**: `"Appearance"` — `.subheadline` + `.medium`

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Raw value | ColorScheme |
|---------|---------|-----------|-------------|
| System  | `"System"` | `"system"` | `nil` (follows system) |
| Dark    | `"Dark"`   | `"dark"` | `.dark` |
| Light   | `"Light"`  | `"light"` | `.light` |

**Behavior**:
- Selection bound to `$settings.appearanceMode`
- `AppSettings.appearanceMode.didSet` writes `rawValue` to `UserDefaults.standard` under key `"ClaudeUsageBar.appearanceMode"`
- Applied via `.preferredColorScheme(settings.appearanceMode.colorScheme)` on `PopoverView.body`
- The `colorScheme` computed property on `AppearanceMode` returns `nil` for `.system` (which lets SwiftUI follow the system setting), `.dark` for dark, `.light` for light
- Default value is `.system` if no saved preference exists

---

## Status Bar Cost Setting

**Label**: `"Status Bar Cost"` — `.subheadline` + `.medium`

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Raw value |
|---------|---------|-----------|
| Today   | `"Today"` | `"day"` |
| Week    | `"Week"`  | `"week"` |
| Month   | `"Month"` | `"month"` |

**Behavior**:
- Selection bound to `$settings.statusBarPeriod`
- `AppSettings.statusBarPeriod.didSet` writes `rawValue` to `UserDefaults.standard` under key `"ClaudeUsageBar.statusBarPeriod"`
- `AppDelegate.observeSettings()` uses `withObservationTracking` to observe `settings.statusBarPeriod`; when it changes, `updateStatusItemTitle()` is called on the main actor and `observeSettings()` re-subscribes for the next change
- The status bar title updates immediately — no delay or debounce

---

## Agent Sort Order Setting

**Label**: `"Agent Sort Order"` — `.subheadline` + `.medium`

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Raw value | Sort Key |
|---------|---------|-----------|----------|
| Recent  | `"Recent"` | `"recentlyUpdated"` | `agent.updatedAt` descending |
| Cost    | `"Cost"`   | `"cost"` | `agent.cost` descending |
| Context | `"Context"` | `"contextUsage"` | `agent.contextPercent` descending |

**Behavior**:
- Selection bound to `$settings.agentSortOrder`
- `AppSettings.agentSortOrder.didSet` writes `rawValue` to `UserDefaults.standard` under key `"ClaudeUsageBar.agentSortOrder"`
- Sorting is applied in `PopoverView.sortAgents(_:)` — both `workingAgents` and `idleAgents` are sorted independently before being placed in their source groups

---

## Subagent Sort Order Setting

**Label**: `"Subagent Sort Order"` — `.subheadline` + `.medium`

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Raw value | Sort Key |
|---------|---------|-----------|----------|
| Recent  | `"Recent"` | `"recent"` | `sub.lastModified` descending (JSONL file mtime) |
| Cost    | `"Cost"`   | `"cost"` | `sub.cost` descending |
| Context | `"Context"` | `"context"` | `sub.lastInputTokens` descending |
| Name    | `"Name"`   | `"name"` | `sub.displayName` ascending (localized case-insensitive) |

**Behavior**:
- Selection bound to `$settings.subagentSortOrder`
- `AppSettings.subagentSortOrder.didSet` writes `rawValue` to `UserDefaults.standard` under key `"ClaudeUsageBar.subagentSortOrder"`
- Sorting is applied in `SubagentDetailView.sortedSubagents` computed property
- Default value is `.cost` if no saved preference exists

---

## Subagent Context Budget Setting

**Label**: `"Subagent Context Budget"` — `.subheadline` + `.medium`

**Description text**: `"Used to calculate context % in subagent drill-down"` — `.caption2` + `.secondary`

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Raw value | Token count |
|---------|---------|-----------|-------------|
| 200K    | `"200K"` | `"k200"` | 200,000 |
| 1M      | `"1M"` | `"m1"` | 1,000,000 |

**Behavior**:
- Selection bound to `$settings.subagentContextBudget`
- `AppSettings.subagentContextBudget.didSet` writes `rawValue` to `UserDefaults.standard` under key `"ClaudeUsageBar.subagentContextBudget"`
- Used in `SubagentDetailView.subagentRow(_:)` to compute context percentage: `Int(Double(sub.lastInputTokens) / Double(settings.subagentContextBudget.tokens) * 100)`
- Default value is `.m1` (1M) if no saved preference exists

---

## Visible Agents Before Scroll Setting (Popover Mode Only)

**Label**: `"Visible Agents Before Scroll"` -- `.subheadline` + `.medium`

**Visibility**: Only shown when `settings.displayMode == .popover`. Hidden in window mode because the window's scrollable content does not need a fixed viewport height.

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Value |
|---------|---------|-------|
| 2  | `"2"`  | `2`  |
| 3  | `"3"`  | `3`  |
| 5  | `"5"`  | `5`  |
| 8  | `"8"`  | `8`  |
| 10 | `"10"` | `10` |

**Behavior**:
- Selection bound to `$settings.maxVisibleAgents`
- `AppSettings.maxVisibleAgents.didSet` writes the `Int` value to `UserDefaults.standard` under key `"ClaudeUsageBar.maxVisibleAgents"`
- Used in `PopoverView` to compute `agentViewportHeight`: the number of agent cards (not headers) visible before the agent list scrolls
- Default value is `3` if `UserDefaults.standard.integer(forKey:)` returns `0` (key absent)

---

## Visible Subagents Before Scroll Setting (Popover Mode Only)

**Label**: `"Visible Subagents Before Scroll"` — `.subheadline` + `.medium`

**Visibility**: Only shown when `settings.displayMode == .popover`. Hidden in window mode because the window's scrollable content does not need a fixed viewport height.

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Value |
|---------|---------|-------|
| 3  | `"3"`  | `3`  |
| 5  | `"5"`  | `5`  |
| 8  | `"8"`  | `8`  |
| 10 | `"10"` | `10` |
| 15 | `"15"` | `15` |

**Behavior**:
- Selection bound to `$settings.maxVisibleSubagents`
- `AppSettings.maxVisibleSubagents.didSet` writes the `Int` value to `UserDefaults.standard` under key `"ClaudeUsageBar.maxVisibleSubagents"`
- Used in `SubagentDetailView` to compute `viewportHeight`: sum of the first `min(subagents.count, maxVisibleSubagents)` rows' actual rendered heights
- Default value is `5` if `UserDefaults.standard.integer(forKey:)` returns `0` (key absent)

---

## Visible Log Messages Before Scroll Setting (Popover Mode Only)

**Label**: `"Visible Log Messages Before Scroll"` — `.subheadline` + `.medium`

**Visibility**: Only shown when `settings.displayMode == .popover`. Hidden in window mode.

**Control**: Segmented `Picker` (`pickerStyle(.segmented)`, labels hidden)

| Segment | Display | Value |
|---------|---------|-------|
| 5  | `"5"`  | `5`  |
| 8  | `"8"`  | `8`  |
| 12 | `"12"` | `12` |
| 20 | `"20"` | `20` |
| 50 | `"50"` | `50` |

**Behavior**:
- Selection bound to `$settings.maxVisibleLogMessages`
- `AppSettings.maxVisibleLogMessages.didSet` writes the `Int` value to `UserDefaults.standard` under key `"ClaudeUsageBar.maxVisibleLogMessages"`
- Used in `LogViewerView.scrollHeight`: `CGFloat(settings.maxVisibleLogMessages) * 60` (popover mode only)
- Default value is `8` if `UserDefaults.standard.integer(forKey:)` returns `0` (key absent)

---

## Log Viewer Defaults Setting

**Label**: `"Log Viewer Defaults"` — `.subheadline` + `.medium`

**Controls**: Two `Toggle` controls, `.caption` font:
- `"Always expand thinking"` — bound to `$settings.expandThinking`
- `"Always expand tools"` — bound to `$settings.expandTools`

**Behavior**:
- `expandThinking` and `expandTools` are `Bool` properties on `AppSettings`
- Persisted via `didSet` to `UserDefaults.standard` under keys `"ClaudeUsageBar.expandThinking"` and `"ClaudeUsageBar.expandTools"`
- Default values are `false` if no saved preference exists
- Used as the initial `expanded` state for `ExpandableSection` views in `LogViewerView`: thinking blocks use `expandThinking`, tool call detail blocks use `expandTools`

---

## Persistence

All settings are backed by `UserDefaults.standard`. The persistence happens in `didSet` observers on each property of `AppSettings`, not lazily or on view dismiss.

| Setting | Key | Type | Default |
|---------|-----|------|---------|
| Display mode | `ClaudeUsageBar.displayMode` | `String` (rawValue) | `"popover"` |
| Appearance mode | `ClaudeUsageBar.appearanceMode` | `String` (rawValue) | `"system"` |
| Status bar period | `ClaudeUsageBar.statusBarPeriod` | `String` (rawValue) | `"day"` |
| Agent sort order | `ClaudeUsageBar.agentSortOrder` | `String` (rawValue) | `"recentlyUpdated"` |
| Subagent sort order | `ClaudeUsageBar.subagentSortOrder` | `String` (rawValue) | `"cost"` |
| Subagent context budget | `ClaudeUsageBar.subagentContextBudget` | `String` (rawValue) | `"m1"` |
| Max visible agents | `ClaudeUsageBar.maxVisibleAgents` | `Int` | `3` |
| Max visible subagents | `ClaudeUsageBar.maxVisibleSubagents` | `Int` | `5` |
| Max visible log messages | `ClaudeUsageBar.maxVisibleLogMessages` | `Int` | `8` |
| Expand thinking | `ClaudeUsageBar.expandThinking` | `Bool` | `false` |
| Expand tools | `ClaudeUsageBar.expandTools` | `Bool` | `false` |

On `AppSettings.init()`, the raw values are read from `UserDefaults` and converted back to their enum cases (or Int/Bool values) with fallbacks to defaults if the stored value is missing or unrecognized. The `launchedDisplayMode` is also set from the initial `displayMode` value during `init()`.

---

## Status Bar Update Chain

When the user changes the status bar period picker:

```
User taps segment
  → $settings.statusBarPeriod binding updates
    → AppSettings.statusBarPeriod.didSet writes UserDefaults
      → @Observable emits change notification
        → withObservationTracking onChange fires
          → Task { @MainActor in
              updateStatusItemTitle()
              observeSettings()   // re-subscribe
            }
```

The re-subscription step is required because `withObservationTracking` fires once and does not automatically re-observe. Each `observeSettings()` call sets up exactly one observation and queues one re-subscription.

The `isLoading` property on `AppSettings` is not persisted — it is a transient `Bool` used only to coordinate the loading indicator in the main view.

---

## Layout Structure (ASCII)

```
┌──────────────────────────────────────────────────┐
│ ← Back                              Settings     │
├──────────────────────────────────────────────────┤
│ Display Mode                                      │
│ [   Popover   |    Window    ]                    │
│ [         Apply & Restart        ]  (if changed)  │
├──────────────────────────────────────────────────┤
│ Appearance                                        │
│ [  System  |   Dark   |   Light  ]                │
├──────────────────────────────────────────────────┤
│ Status Bar Cost                                   │
│ [   Today   |    Week    |    Month   ]           │
├──────────────────────────────────────────────────┤
│ Agent Sort Order                                  │
│ [  Recent   |    Cost    |   Context  ]           │
├──────────────────────────────────────────────────┤
│ Subagent Sort Order                               │
│ [  Recent  |  Cost  |  Context  |  Name  ]        │
├──────────────────────────────────────────────────┤
│ Subagent Context Budget                           │
│ Used to calculate context % in subagent drill-down│
│ [    200K    |      1M      ]                     │
├──────────────────────────────────────────────────┤ ← below only in popover mode
│ Visible Agents Before Scroll                      │
│ [  2  |  3  |  5  |  8  |  10  ]                │
├──────────────────────────────────────────────────┤
│ Visible Subagents Before Scroll                   │
│ [  3  |  5  |  8  |  10  |  15  ]               │
├──────────────────────────────────────────────────┤
│ Visible Log Messages Before Scroll                │
│ [  5  |  8  |  12  |  20  |  50  ]              │
├──────────────────────────────────────────────────┤
│ Log Viewer Defaults                               │
│ [ ] Always expand thinking                        │
│ [ ] Always expand tools                           │
└──────────────────────────────────────────────────┘
```
