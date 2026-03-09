# Stats Detail Screen Specification

## Overview

The stats detail screen is the `detailView(label:stats:)` function inside `PopoverView.swift`. It is shown when the user taps a period row on the main screen. The view occupies the same 320pt-wide, 16pt-padded space as all other views in the popover.

---

## Navigation

- **Back button**: Top-left, chevron.left + "Back" text, `.plain` style, `.blue` foreground. Font adapts: `.caption` in popover mode, `.body` in window mode.
  - On tap: sets `selectedPeriod = nil`, returning to main view
- **Title**: Top-right, e.g. `"Today Breakdown"`, `"Week Breakdown"`, `"Month Breakdown"`. Font adapts: `.headline` in popover mode, `.title3` in window mode.

```
← Back                        Today Breakdown
─────────────────────────────────────────────
```

---

## Total Row

Below the divider, a summary row shows the combined cost across all sources:

```
Total                               $18.90
```

- Label: `"Total"`, `.subheadline` + `.medium`
- Cost: `"$%.2f"` format, `.subheadline` + `.semibold` + `.orange`

---

## Source Breakdown Sections

Two source sections may appear: **CLI** and **Commander**. A source section is shown only if it has a non-zero cost OR non-zero lines added. Sources with zero activity are filtered out.

Each source section is rendered by `sourceBreakdown(name:icon:source:)`.

### Source Header Row

```
[icon] CLI             +8.4K  -3.1K    $14.50
```

- Icon: `terminal` (CLI) or `app.connected.to.app.below.fill` (Commander); `.caption` + `.secondary`
- Name: `" CLI"` or `" Commander"`; `.subheadline` + `.medium`
- `addedCell` — total lines added for this source
- `removedCell` — total lines removed for this source
- `costCell` — total cost; `.subheadline` + `.semibold`

### Per-Model Rows

Below the source header, one row per model (sorted by cost, descending):

```
        Opus 4.6            +5.1K  -2.0K    $12.30
        Sonnet 4.5          +3.3K  -1.1K     $2.20
```

- Indented 20pt from left edge
- Model name: `.caption` + `.secondary`, lineLimit 1, truncated from tail
- `addedCell` — lines for this model
- `removedCell` — lines for this model
- `costCell` — cost for this model

### "Model breakdown not available" Fallback

If `source.byModel` is empty but `source.total.cost > 0`, a fallback message appears:

```
        Model breakdown not available for older sessions
```

- `.caption2` + `.tertiary`, indented 20pt

This occurs for sessions that predate the `.models` file format or where only a `.dat` file was written without model transition tracking.

### Subagents Subsection

If `source.subagentsByModel` is non-empty, a subagent subsection appears after the model rows:

```
  ↳ Subagents              +1.2K    -400    $3.10
          Opus 4.6          +900    -300    $2.50
          Sonnet 4.5        +300    -100    $0.60
```

- Subagents header: indented 8pt, top padding 2pt
  - Icon: `arrow.turn.down.right`, `.caption2` + `.secondary`
  - Label: `" Subagents"`, `.caption` + `.secondary`
  - `addedCell` + `removedCell` + `costCell` — totals across all subagent models
- Per-model subagent rows: indented 28pt
  - Model name: `.caption2` + `.secondary`
  - `addedCell` + `removedCell` + `costCell` (`.caption2` font)
  - Sorted by cost, descending

### Projects Subsection

If `source.byProject` is non-empty, a projects subsection appears after the subagents subsection. Projects are sorted by total cost (main + subagent) descending.

```
Projects
  [folder] my-project          +5.1K   -2.0K     $10.50
      ↳ Subs                    +900     -300      $2.50
  [folder] other-repo          +3.3K   -1.1K      $4.00
```

- Section label: `Text("Projects")`, `.caption` + `.medium` + `.secondary`, top padding 4pt
- Per-project rows: indented 8pt
  - Icon: `folder`, `.caption2` + `.secondary`
  - Project name: `.caption`, lineLimit 1, `truncationMode(.middle)`
  - `addedCell` — combined main + subagent lines added
  - `removedCell` — combined main + subagent lines removed
  - `costCell` — combined `stats.main.cost + stats.subagents.cost`
- Subagent sub-row (only shown when `stats.subagents.cost > 0`): indented 20pt
  - Icon: `arrow.turn.down.right`, `.caption2` + `.secondary`
  - Label: `" Subs"`, `.caption2` + `.secondary`
  - `addedCell` — subagent lines added only
  - `removedCell` — subagent lines removed only
  - `costCell` — subagent cost only, `.caption2` font

Each project represents the combined cost of all sessions running in that working directory during the period. The project name is the resolved working directory (last path component shown in the folder label). Data comes from `source.byProject`, which aggregates `{pid}.project` files written by `AgentTracker`.

---

## Column Layout (Fixed-Width Trailing Cells)

All data columns use fixed-width `frame` with trailing alignment to ensure consistent column alignment across rows regardless of data values.

| Cell function | Width | Font | Foreground |
|---------------|-------|------|------------|
| `costCell` (default) | 64pt | `.caption` + `.medium` | `.orange` |
| `costCell` (source header) | 64pt | `.subheadline` + `.semibold` | `.orange` |
| `costCell` (subagent model) | 64pt | `.caption2` + `.medium` | `.orange` |
| `addedCell` | 46pt | `.caption2` | `addedColor` |
| `removedCell` | 40pt | `.caption2` | `removedColor` |

The `linesCell` function combines `addedCell` + `removedCell` in an HStack with zero spacing (used internally but source header uses them separately for individual control).

---

## Compact Number Formatting

All line counts use `.number.notation(.compactName)` — Swift's built-in compact number formatter:

| Raw value | Formatted |
|-----------|-----------|
| 0         | `"0"`     |
| 999       | `"999"`   |
| 1000      | `"1K"`    |
| 1234      | `"1.2K"`  |
| 1000000   | `"1M"`    |
| 1234567   | `"1.2M"`  |

The `+` and `-` prefixes are prepended manually as string literals in the view code.

---

## Color Scheme

Colors adapt to the system color scheme (light/dark). The `@Environment(\.colorScheme)` is read in `PopoverView` and the derived colors are passed implicitly (the detail view is rendered in the same `PopoverView` scope).

| Token | Dark mode | Light mode |
|-------|-----------|------------|
| `addedColor` | `.green` | `Color(red: 0.1, green: 0.55, blue: 0.1)` (darker green) |
| `removedColor` | `Color(red: 1.0, green: 0.4, blue: 0.4)` (lighter red) | `.red` |
| Cost cells | `.orange` | `.orange` (unchanged) |
| Secondary text | `.secondary` | `.secondary` |

The cost color `.orange` does not adapt and remains constant in both modes.

---

## Layout Structure (ASCII)

```
← Back                            Today Breakdown
────────────────────────────────────────────────
Total                                      $18.90
────────────────────────────────────────────────
[terminal] CLI          +8.4K   -3.1K     $14.50
    Opus 4.6            +5.1K   -2.0K     $12.30
    Sonnet 4.5          +3.3K   -1.1K      $2.20
  ↳ Subagents           +1.2K     -400     $3.10
      Opus 4.6            +900     -300     $2.50
      Sonnet 4.5          +300     -100     $0.60
  Projects
    [folder] my-project   +5.1K   -2.0K   $10.50
        ↳ Subs              +900     -300    $2.50
    [folder] other-repo   +3.3K   -1.1K    $4.00
────────────────────────────────────────────────
[app] Commander         +200K    -80K      $4.40
    Opus 4.6            +200K    -80K      $4.40
```

---

## Edge Cases

- **Both sources have no data**: The `detailView` is only accessible by tapping a period row on the main screen. If a period has zero cost and zero lines, the row still exists and is tappable; the detail view shows the total row (`$0.00`) and no source sections.
- **Source has cost but no model breakdown**: Shows `"Model breakdown not available for older sessions"` instead of model rows. This can happen for `.dat` files written before the `.models` file format was introduced.
- **Subagent cost not in byModel**: Subagent costs come from `{pid}.subagents.json`, not from `.models` transition history. They are displayed in the separate "Subagents" subsection and are not double-counted in the source total (they are included in `source.total.cost`).
- **Long model names**: Truncated with `truncationMode(.tail)`, lineLimit 1 — the fixed-width cost/lines columns are preserved.
- **Long project names**: Truncated with `truncationMode(.middle)`, lineLimit 1.
- **Projects with no subagent cost**: The "Subs" sub-row is omitted entirely when `stats.subagents.cost == 0`.

---

## Adaptive Fonts for Window Mode

The detail view navigation header uses adaptive fonts based on `settings.displayMode`:

| Element | Popover mode | Window mode |
|---------|-------------|-------------|
| Back button | `.caption` | `.body` |
| Screen title (e.g. "Today Breakdown") | `.headline` | `.title3` |

In window mode, the entire `detailView` is wrapped in a `ScrollView` by `PopoverView.content`.
