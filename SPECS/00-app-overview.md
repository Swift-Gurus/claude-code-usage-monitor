# ClaudeUsageBar — App Overview

## Purpose

ClaudeUsageBar is a macOS menu bar application that monitors Claude Code API usage in real time. It aggregates cost, token, and lines-changed data from Claude Code sessions running on the local machine and presents them in a compact popover attached to the macOS status bar.

The app addresses two scenarios:

1. **Interactive (CLI) sessions** — Claude Code invoked in a terminal, where a user-configured statusline command fires after every AI response and writes cost data to `~/.claude/usage/`.
2. **Commander (pipe-mode) sessions** — Claude Code invoked programmatically with `-p --output-format=stream-json`, where no statusline fires. The app discovers these sessions through process scanning and parses the raw JSONL conversation files directly.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        macOS Status Bar                             │
│  [chart.bar.fill] D: $1.23    ← NSStatusItem (variableLength)      │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ click → togglePopover
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        NSPopover (320pt wide)                       │
│  PopoverView (SwiftUI, @Observable)                                 │
│  ┌─────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │ MainView    │  │ DetailView       │  │ SubagentDetailView   │   │
│  │ (period     │  │ (source +        │  │ (per-subagent        │   │
│  │  table +    │  │  model           │  │  context bars)       │   │
│  │  agents)    │  │  breakdown)      │  │                      │   │
│  └─────────────┘  └──────────────────┘  └──────────────────────┘   │
│           │                                                          │
│           └── SettingsView (picker-based settings)                  │
└─────────────────────────────────────────────────────────────────────┘
         ▲                    ▲
         │ .reload()          │ .reload()
         │                    │
┌────────┴───────┐  ┌─────────┴──────────┐
│  UsageData     │  │  AgentTracker      │
│  @Observable   │  │  @Observable       │
│                │  │                    │
│  Reads .dat    │  │  Reads .agent.json │
│  .models       │  │  Checks PID liveness│
│  .subagents    │  │  Gets CPU usage    │
│  .json files   │  │  Writes subagent   │
│                │  │  detail files      │
└────────┬───────┘  └─────────┬──────────┘
         │                    │
         └──────────┬─────────┘
                    │ reads from
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    ~/.claude/usage/                                  │
│  ├── YYYY-MM-DD/                ← CLI (statusline writes)           │
│  │   ├── {PPID}.dat                                                  │
│  │   ├── {PPID}.models                                               │
│  │   ├── {PPID}.agent.json                                           │
│  │   ├── {pid}.subagents.json   ← AgentTracker writes               │
│  │   └── {pid}.subagent-details.json                                 │
│  ├── commander/                                                      │
│  │   └── YYYY-MM-DD/            ← CommanderSupport writes           │
│  │       ├── {pid}.dat                                               │
│  │       ├── {pid}.agent.json                                        │
│  │       ├── {pid}.subagents.json                                    │
│  │       └── {pid}.subagent-details.json                             │
│  └── .last_cleanup              ← Cleanup marker (CLI)              │
└─────────────────────────────────────────────────────────────────────┘
         ▲                    ▲
         │ writes             │ reads JSONL + writes .dat/.agent.json
         │                    │
┌────────┴────────┐  ┌────────┴──────────────────────────────────────┐
│  statusline-    │  │  CommanderSupport                              │
│  command.sh     │  │  ┌─────────────────┐  ┌────────────────────┐  │
│                 │  │  │  SessionScanner │  │  JSONLParser       │  │
│  runs after     │  │  │  ps + lsof      │  │  parses JSONL      │  │
│  every AI       │  │  │  finds claude   │  │  computes cost     │  │
│  response in    │  │  │  processes by   │  │  counts lines      │  │
│  interactive    │  │  │  PPID           │  │                    │  │
│  sessions       │  │  └─────────────────┘  └────────────────────┘  │
└─────────────────┘  └───────────────────────────────────────────────┘
         ▲
         │ installed/injected by
┌────────┴──────────────┐
│  StatuslineInstaller  │
│  detects, injects,    │
│  or upgrades the      │
│  tracking snippet in  │
│  ~/.claude/settings.json│
└───────────────────────┘
```

---

## Two Data Sources

### Source 1: CLI (Statusline)

Claude Code supports a user-configurable `statusLine.command` in `~/.claude/settings.json`. After every AI response, Claude Code pipes a JSON blob to this command over stdin. The command can parse it and write whatever it wants.

`StatuslineInstaller` either deploys a full bundled script (`statusline-command.sh`) or injects a tracking snippet into the user's existing script. The snippet extracts cost, lines changed, model, agent name, context window info, and session metadata from the JSON blob, then writes three files per session per day to `~/.claude/usage/YYYY-MM-DD/`:

- `{PPID}.dat` — space-separated: `cost linesAdded linesRemoved model`
- `{PPID}.models` — TSV append-log of model transitions
- `{PPID}.agent.json` — full JSON agent metadata

The PID used is `$PPID` (the parent of the shell running the script, i.e., the claude process).

### Source 2: Commander (Pipe-Mode)

When Claude Code is run with `-p --output-format=stream-json`, it does not invoke the statusline command. `CommanderSupport` bridges this gap by:

1. Scanning running processes to find `claude` processes whose parent is a Commander process
2. Finding the working directory of each such process via `lsof`
3. Locating the most recent JSONL conversation file in `~/.claude/projects/{encoded_path}/`
4. Parsing the JSONL with `JSONLParser` to compute cost, lines changed, and session duration
5. Writing `.dat` and `.agent.json` files to `~/.claude/usage/commander/YYYY-MM-DD/`

Commander data is stored in a separate `commander/` subdirectory so it never collides with CLI-written files even if the same PID appears in both contexts.

---

## Data Flow Overview

```
Collection → Storage → Aggregation → Display

CLI:
  Claude Code statusline hook
    → statusline-command.sh (or injected snippet)
      → ~/.claude/usage/YYYY-MM-DD/{PPID}.dat
      → ~/.claude/usage/YYYY-MM-DD/{PPID}.models
      → ~/.claude/usage/YYYY-MM-DD/{PPID}.agent.json

Commander:
  UsageMonitor poll (5s) or popover open
    → CommanderSupport.refreshFiles()
      → SessionScanner.findActiveSessions()     (ps + lsof)
      → JSONLParser.parseSession()              (reads JSONL)
      → ~/.claude/usage/commander/YYYY-MM-DD/{pid}.dat
      → ~/.claude/usage/commander/YYYY-MM-DD/{pid}.agent.json

Aggregation (triggered by FSEvent on ~/.claude/usage/ or 5s poll):
  UsageData.reload()
    → reads all .dat, .models, .subagents.json from both trees
    → deduplicates multi-day PIDs (keep latest, compute incremental)
    → produces PeriodStats{day, week, month}

  AgentTracker.reload()
    → reads all .agent.json from today's folders
    → checks PID liveness (kill -0)
    → fetches CPU usage (ps)
    → computes idle state
    → scans subagents/ dirs, writes .subagents.json and .subagent-details.json

Display:
  PopoverView reads from UsageData and AgentTracker via @Observable
  NSStatusItem title updated from UsageData.day/week/month
```

---

## Key User Flows

### 1. Open Popover
1. User clicks the status bar icon
2. `AppDelegate.togglePopover()` fires
3. `settings.isLoading = true` is set immediately
4. Popover opens — shows existing (possibly stale) data at once
5. Background thread runs `CommanderSupport.refreshFiles()`
6. Main thread runs `usageData.reload()` and `agentTracker.reload()`
7. `settings.isLoading = false` — loading indicator disappears

### 2. View Period Stats
The main view always shows Today / Week / Month cost and lines. Tapping any row navigates to `detailView` which breaks down cost by source (CLI, Commander) and by model.

### 3. View Active Agents
The main view lists all agents from today's `.agent.json` files, grouped by source (CLI, Commander). Active agents appear with a green dot; idle agents (low CPU + stale + project not active elsewhere) are dimmed with a moon icon and idle duration.

### 4. Drill Into Agent
Tapping an agent row navigates to `SubagentDetailView`. On `.onAppear`, it reads `{pid}.subagent-details.json` from the appropriate usage directory and lists each subagent with model, cost, context bar, and lines changed.

### 5. Settings
Tapping the gear icon navigates to `SettingsView`. Changes to status bar period, agent sort order, or context budget take effect immediately via `@Bindable` and `@Observable`; status bar title re-renders via `withObservationTracking`.

---

## File System Layout

```
~/.claude/
├── settings.json                    ← Claude Code settings (statusLine.command lives here)
├── statusline-command.sh            ← Bundled script (if fresh install)
├── usage/
│   ├── .last_cleanup                ← Date string, prevents re-running cleanup each call
│   ├── YYYY-MM-DD/                  ← One folder per calendar day (CLI source)
│   │   ├── {PPID}.dat               ← "cost la lr model\n"
│   │   ├── {PPID}.models            ← TSV: cost\tla\tlr\tmodel per model switch
│   │   ├── {PPID}.agent.json        ← Full AgentFileData JSON
│   │   ├── {PPID}.subagents.json    ← [String: SourceModelStats] JSON (written by AgentTracker)
│   │   └── {PPID}.subagent-details.json  ← [SubagentInfo] JSON (written by AgentTracker)
│   └── commander/
│       ├── .last_cleanup            ← Same pattern, separate from CLI cleanup
│       └── YYYY-MM-DD/              ← Commander source (same file structure as CLI)
│           ├── {pid}.dat
│           ├── {pid}.agent.json
│           ├── {pid}.subagents.json
│           └── {pid}.subagent-details.json
└── projects/
    └── {encoded_path}/              ← e.g. "-Users-alice-myproject"
        └── {sessionID}.jsonl        ← Claude Code's own conversation log
            └── subagents/
                └── {agentID}.jsonl  ← One JSONL per subagent invocation
```

---

## Component Communication Map

| Caller | Callee | When | What |
|--------|--------|------|------|
| `AppDelegate` | `StatuslineInstaller.install()` | `applicationDidFinishLaunching` | Ensures statusline is configured |
| `AppDelegate` | `CommanderSupport.refreshFiles()` | Monitor callback + popover open | Writes fresh Commander .dat/.agent.json |
| `AppDelegate` | `UsageData.reload()` | After refreshFiles | Re-reads all .dat/.models/.subagents |
| `AppDelegate` | `AgentTracker.reload()` | After UsageData.reload | Re-reads .agent.json, writes subagent files |
| `AppDelegate` | `updateStatusItemTitle()` | After reload, and on settings change | Updates status bar text |
| `UsageMonitor` | `AppDelegate.onChange` | FSEvent on ~/.claude/usage/ or 5s poll | Triggers full refresh cycle |
| `CommanderSupport` | `SessionScanner.findActiveSessions()` | refreshFiles | Discovers Commander-spawned claude PIDs |
| `CommanderSupport` | `JSONLParser.parseSession()` | Per active session | Computes cost from JSONL |
| `AgentTracker` | `JSONLParser.parseSubagents()` | Per live session with sessionID | Scans subagents dir, computes per-model stats |
| `AgentTracker` | `JSONLParser.parseSubagentDetails()` | Per live session with sessionID | Produces per-file SubagentInfo list |
| `PopoverView` | `UsageData` (read) | On render | Reads day/week/month PeriodStats |
| `PopoverView` | `AgentTracker.activeAgents` (read) | On render | Reads live agent list |
| `SubagentDetailView` | filesystem (read) | `.onAppear` | Reads {pid}.subagent-details.json |
| `AppSettings` | `UserDefaults` | On property change | Persists settings |
| `AppDelegate` | `AppSettings` (observe) | `withObservationTracking` | Re-renders status bar on period change |
