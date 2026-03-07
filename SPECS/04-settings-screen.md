# Settings Screen Specification

## Overview

The settings screen is `SettingsView.swift`. It is shown when the user taps the gear icon (`gearshape`) in the main screen header. It uses a `@Bindable` reference to `AppSettings` — changes are reflected immediately without requiring confirmation.

The view is 320pt wide with 16pt padding on all sides.

---

## Navigation

- **Back button**: Top-left, `chevron.left` + `"Back"` text, `.plain` style, `.blue` foreground, `.caption` font
  - On tap: calls `onDismiss()` which sets `showSettings = false` in `PopoverView`
- **Title**: Top-right, `"Settings"`; `.headline` font

```
← Back                                   Settings
─────────────────────────────────────────────────
```

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

## Visible Subagents Before Scroll Setting

**Label**: `"Visible Subagents Before Scroll"` — `.subheadline` + `.medium`

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

## Persistence

All settings are backed by `UserDefaults.standard`. The persistence happens in `didSet` observers on each property of `AppSettings`, not lazily or on view dismiss.

| Setting | Key | Type | Default |
|---------|-----|------|---------|
| Status bar period | `ClaudeUsageBar.statusBarPeriod` | `String` (rawValue) | `"day"` |
| Agent sort order | `ClaudeUsageBar.agentSortOrder` | `String` (rawValue) | `"recentlyUpdated"` |
| Subagent context budget | `ClaudeUsageBar.subagentContextBudget` | `String` (rawValue) | `"m1"` |
| Max visible subagents | `ClaudeUsageBar.maxVisibleSubagents` | `Int` | `5` |

On `AppSettings.init()`, the raw values are read from `UserDefaults` and converted back to their enum cases (or Int values) with fallbacks to defaults if the stored value is missing or unrecognized.

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
│ Status Bar Cost                                   │
│ [   Today   |    Week    |    Month   ]           │
├──────────────────────────────────────────────────┤
│ Agent Sort Order                                  │
│ [  Recent   |    Cost    |   Context  ]           │
├──────────────────────────────────────────────────┤
│ Subagent Context Budget                           │
│ Used to calculate context % in subagent drill-down│
│ [    200K    |      1M      ]                     │
├──────────────────────────────────────────────────┤
│ Visible Subagents Before Scroll                   │
│ [  3  |  5  |  8  |  10  |  15  ]               │
└──────────────────────────────────────────────────┘
```
