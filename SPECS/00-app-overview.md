# ClaudeUsageBar — App Overview

## Purpose

ClaudeUsageBar is a macOS menu bar application that monitors Claude Code API usage in real time. It aggregates cost, token, and lines-changed data from Claude Code sessions running on the local machine and presents them in either a compact popover attached to the macOS status bar or a floating window (configurable via Display Mode setting). The app can also spawn new Claude Code sessions via hidden PTY, providing a full GUI wrapper with bidirectional input, permission handling, and interactive prompt responses.

The app addresses three scenarios:

1. **Interactive (CLI) sessions** -- Claude Code invoked in a terminal, where a user-configured statusline command fires after every AI response and writes cost data to `~/.claude/usage/`.
2. **Commander (pipe-mode) sessions** -- Claude Code invoked programmatically with `-p --output-format=stream-json`, where no statusline fires. The app discovers these sessions through process scanning and parses the raw JSONL conversation files directly.
3. **App-spawned sessions** -- Claude Code spawned by the app via hidden PTY (using "Open Project"). The app controls the session lifecycle, sends user prompts, handles permission/question prompts, and monitors via JSONL + TTY activity callbacks.

---

## High-Level Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                        macOS Status Bar                             │
│  [chart.bar.fill] D: $1.23    ← NSStatusItem (variableLength)      │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ click → toggleUI
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│              NSPopover (320pt wide) or NSPanel (window mode)        │
│  PopoverView (SwiftUI, @Observable)                                 │
│  ┌─────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │ MainView    │  │ DetailView       │  │ SubagentDetailView   │   │
│  │ (period     │  │ (source +        │  │ (per-subagent        │   │
│  │  table +    │  │  model           │  │  context bars +      │   │
│  │  agents)    │  │  breakdown)      │  │  log viewer)         │   │
│  └─────────────┘  └──────────────────┘  └──────────────────────┘   │
│           │                                   │                      │
│           └── SettingsView                    └── LogViewerView     │
│               (picker-based settings)             (chat bubbles)    │
│                                                       │             │
│                                               LogParser + LogMessage│
│                                               (JSONL → display msgs)│
└─────────────────────────────────────────────────────────────────────┘
         ▲                    ▲
         │ .reload()          │ .reload()
         │                    │
┌────────┴───────┐  ┌─────────┴──────────┐
│  UsageData     │  │  AgentTracker      │
│  @Observable   │  │  @Observable       │
│                │  │                    │
│  Reads .dat    │  │  Reads .agent.json │
│  + .agent.json │  │                    │
│  .models       │  │  Checks PID liveness│
│  .subagents    │  │  Writes .project   │
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
│  │   ├── {pid}.subagent-details.json                                 │
│  │   └── {pid}.project         ← plain text, resolved workingDir    │
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
  UsageMonitor.onChange → AppDelegate.scheduleRefresh()
    → coalesces via refreshInFlight flag
    → dispatches to background refreshQueue
    → CommanderSupport.refreshFiles()
    → main thread: usageData.reload(), agentTracker.reload(), updateStatusItemTitle()

  UsageData.reload()
    → reads all .dat, .models, .subagents.json, .agent.json from both trees
    → deduplicates via 4-step algorithm:
      1. PID → sessionID map (from .agent.json)
      2. Build latestByPID / previousByPID
      3. Exact-content duplicate detection
      4. Session-ID-based merging
    → produces PeriodStats{day, week, month}

  AgentTracker.reload()
    → reads all .agent.json from today's folders
    → checks PID liveness (kill -0, then ps to verify "claude" in command)
    → checks JSONL mtime activity (parent + subagent files within 60s)
    → computes idle state (recently updated OR JSONL active)
    → writes {pid}.project files (plain text, resolved workingDir)
    → scans subagents/ dirs, writes .subagents.json and .subagent-details.json

App-Spawned Sessions:
  User taps "Open Project" in PopoverView
    -> NSOpenPanel selects directory
    -> SessionManager.spawn(workingDir:)
      -> TTYBridge.spawn(workingDir:) via openpty + Process
      -> Trust prompt auto-handled
    -> Navigate to SubagentDetailView -> LogViewerView
    -> LogViewerView sets bridge.onActivity callback
      -> Triggers JSONL reload on PTY output
    -> Input field sends prompts via TTYBridge.send()
    -> Pending prompts detected via JSONL gap (tool_use without tool_result)
    -> Modal overlay sends responses via TTYBridge.sendRaw()
    -> Debug logging via FileDebugLogger -> ~/.claude/usage/debug.log

Display:
  PopoverView reads from UsageData and AgentTracker via @Observable
  NSStatusItem title updated from UsageData.day/week/month
  Display mode: NSPopover (popover mode) or NSPanel (window mode)
  Appearance: System/Dark/Light via .preferredColorScheme()
```

---

## Key User Flows

### 1. Open UI
1. User clicks the status bar icon
2. `AppDelegate.toggleUI()` dispatches to `togglePopover()` or `toggleWindow()` based on `settings.displayMode`
3. `settings.isLoading = true` is set immediately
4. UI opens — shows existing (possibly stale) data at once. In popover mode: `NSPopover.show()`. In window mode: `NSPanel.orderFront()` (note: `NSApp.activate()` is missing from the implementation — see SPEC 15, this is a known bug).
5. Background thread runs `CommanderSupport.refreshFiles()`
6. Main thread runs `usageData.reload()` and `agentTracker.reload()`
7. `settings.isLoading = false` — loading indicator disappears

### 2. View Period Stats
The main view always shows Today / Week / Month cost and lines. Tapping any row navigates to `detailView` which breaks down cost by source (CLI, Commander) and by model.

### 3. View Active Agents
The main view lists all agents from today's `.agent.json` files, grouped by source (CLI, Commander). Active agents appear with a green dot; idle agents (low CPU + stale + project not active elsewhere) are dimmed with a moon icon and idle duration.

### 4. Drill Into Agent
Tapping an agent row navigates to `SubagentDetailView`. A `.task` modifier polls `{pid}.subagent-details.json` every 2 seconds from the appropriate usage directory and lists each subagent with model, cost, context bar, lines changed, description, and type. The subagent list is sorted according to `AppSettings.subagentSortOrder` (Recent, Cost, Context, or Name).

### 5. View Session Logs
From `SubagentDetailView`, tapping the log icon (top-right) opens `LogViewerView` for the parent session. Tapping a subagent row opens `LogViewerView` for that subagent. The log viewer shows a chat-bubble-style conversation with user messages, assistant text, expandable tool calls (with full content), and collapsible thinking blocks. It polls the JSONL file every 2 seconds with mtime caching and auto-scrolls to the latest message. For app-spawned sessions, TTY activity triggers immediate JSONL reloads for near-instant updates.

### 6. Open Project (Spawn New Session)
1. User taps "Open Project" button in the main view
2. `NSOpenPanel` opens (directories only, single selection)
3. User selects a project directory
4. `SessionManager.spawn(workingDir:)` creates a `TTYBridge` and spawns `claude` under a hidden PTY
5. Trust prompt is auto-handled (sends `\r` on first "trust" output)
6. A synthetic `AgentInfo` is constructed and `selectedAgent` is set, navigating to `SubagentDetailView`
7. From SubagentDetailView, the user navigates to `LogViewerView` where the input field is enabled

### 7. Interactive Session (Send Prompts)
1. In `LogViewerView` for an app-spawned session, the input field is visible at the bottom
2. User types a message and taps Send (or Cmd+Return)
3. `TTYBridge.send(text)` writes the text as bulk paste, waits 50ms, then sends carriage return
4. Claude processes the prompt; PTY activity triggers JSONL reload
5. Assistant response appears in the chat view

### 8. Handle Permission Prompt
1. Claude requests a tool permission (Bash, Edit, Write)
2. JSONL shows a `tool_use` without a matching `tool_result` -- detected by `pendingPrompt`
3. A modal overlay appears with "Allow" (green) and "Deny" (red) buttons
4. "Allow" sends `\r` (Enter) via `TTYBridge.sendRaw()` -- "Deny" sends `\u{1b}` (Escape)
5. Claude proceeds or skips; the JSONL `tool_result` resolves the prompt

### 9. Handle AskUserQuestion Prompt
1. Claude sends an `AskUserQuestion` tool call with options
2. JSONL gap detected -- modal overlay shows radio buttons for options
3. User selects an option (click updates `selectedOptionIdx`)
4. "Submit" sends N down-arrow keys (`\u{1b}[B`, each as separate `write()`) then `\r` (Enter)
5. The JSONL `tool_result` contains the structured answer via `toolUseResult`

### 10. Handle ExitPlanMode Prompt
1. Claude sends an `ExitPlanMode` tool call with a plan
2. Modal overlay shows "Approve" (green) and "Reject" (red) buttons
3. "Approve" sends `\r` -- "Reject" sends `\u{1b}`

### 11. Stop Session
1. In LogViewerView header, user taps the red stop button
2. `TTYBridge.detach()` terminates the child process and cleans up PTY
3. Session is removed from `SessionManager.sessions`
4. `onStop()` callback triggers navigation back to the parent view

### Window Mode: Sticky Navigation Headers

In window mode, navigation headers (Back button + title) are pinned above the scrollable content at all three navigation levels:

| Level | Sticky Header Contains |
|-------|----------------------|
| Settings / Detail | Back button + "Settings" or period label |
| SubagentDetailView | Back button + agent name + log icon |
| LogViewerView | Back button + connection dot + title + task toggle + stop + open-in-editor |

In popover mode, headers are inline (no sticky pinning needed due to compact size).

### 6. Settings
Tapping the gear icon navigates to `SettingsView`. Changes to status bar period, agent sort order, subagent sort order, appearance mode, or context budget take effect immediately via `@Bindable` and `@Observable`; status bar title re-renders via `withObservationTracking`. Display mode changes require an "Apply & Restart" to take effect.

---

## File System Layout

```
~/.claude/
├── settings.json                    ← Claude Code settings (statusLine.command lives here)
├── statusline-command.sh            ← Bundled script (if fresh install)
├── usage/
│   ├── .last_cleanup                ← Date string, prevents re-running cleanup each call
│   ├── debug.log                    ← FileDebugLogger output (TTYBridge + SessionManager events)
│   ├── YYYY-MM-DD/                  ← One folder per calendar day (CLI source)
│   │   ├── {PPID}.dat               ← "cost la lr model\n"
│   │   ├── {PPID}.models            ← TSV: cost\tla\tlr\tmodel per model switch
│   │   ├── {PPID}.agent.json        ← Full AgentFileData JSON
│   │   ├── {PPID}.subagents.json    ← [String: SourceModelStats] JSON (written by AgentTracker)
│   │   ├── {PPID}.subagent-details.json  ← [SubagentInfo] JSON (written by AgentTracker)
│   │   ├── {PPID}.parent-tools.json ← [String: Int] tool counts (written by AgentTracker)
│   │   └── {PPID}.project          ← Plain text, resolved workingDir (written by AgentTracker)
│   └── commander/
│       ├── .last_cleanup            ← Same pattern, separate from CLI cleanup
│       └── YYYY-MM-DD/              ← Commander source (same file structure as CLI)
│           ├── {pid}.dat
│           ├── {pid}.agent.json
│           ├── {pid}.subagents.json
│           ├── {pid}.subagent-details.json
│           ├── {pid}.parent-tools.json
│           └── {pid}.project       ← Plain text, resolved workingDir (written by AgentTracker)
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
| `AppDelegate` | `SessionManager` (create) | `applicationDidFinishLaunching` | Creates singleton with FileDebugLogger(isEnabled: true) |
| `AppDelegate` | `CommanderSupport.refreshFiles()` | Monitor callback + popover open | Writes fresh Commander .dat/.agent.json |
| `AppDelegate` | `UsageData.reload()` | After refreshFiles | Re-reads all .dat/.models/.subagents |
| `AppDelegate` | `AgentTracker.reload()` | After UsageData.reload | Re-reads .agent.json, writes subagent files |
| `AppDelegate` | `updateStatusItemTitle()` | After reload, and on settings change | Updates status bar text |
| `UsageMonitor` | `AppDelegate.scheduleRefresh()` | FSEvent on ~/.claude/usage/ or 5s poll | Coalesces via `refreshInFlight` flag, dispatches to background `refreshQueue`, then main-thread reload |
| `CommanderSupport` | `SessionScanner.findActiveSessions()` | refreshFiles | Discovers Commander-spawned claude PIDs |
| `CommanderSupport` | `JSONLParser.parseSession()` | Per active session | Computes cost from JSONL |
| `AgentTracker` | `JSONLParser.parseSubagents()` | Per live session with sessionID | Scans subagents dir, computes per-model stats |
| `AgentTracker` | `JSONLParser.parseSubagentMeta()` | Per live session with sessionID | Maps Agent tool_use calls to subagent IDs with descriptions |
| `AgentTracker` | `JSONLParser.parseSubagentDetails()` | Per live session with sessionID | Produces per-file SubagentInfo list (with meta from parseSubagentMeta) |
| `PopoverView` | `UsageData` (read) | On render | Reads day/week/month PeriodStats |
| `PopoverView` | `AgentTracker.activeAgents` (read) | On render | Reads live agent list |
| `PopoverView` | `SessionManager.spawn()` | "Open Project" button tap | Spawns new claude session via TTYBridge, navigates to agent |
| `PopoverView` | `SessionManager` (pass) | Navigation to SubagentDetailView | Passes sessionManager for downstream use |
| `SubagentDetailView` | filesystem (read) | `.task` (2s poll) | Reads {pid}.subagent-details.json |
| `SubagentDetailView` | `LogViewerView` | On row tap or log button | Navigates to log viewer, passes sessionManager |
| `LogViewerView` | `SessionManager.bridge(for:)` | On appear | Resolves TTYBridge for this agent's PID |
| `LogViewerView` | `TTYBridge.onActivity` | On appear (if bridge exists) | Sets callback to trigger JSONL reload on PTY output |
| `LogViewerView` | `LogParser.parseMessages()` | TTY activity callback + 2s poll | Parses JSONL into display-ready messages |
| `LogViewerView` | `TTYBridge.send()` | User submits text input | Sends user prompt via PTY (bulk paste + 50ms + CR) |
| `LogViewerView` | `TTYBridge.sendRaw()` | User responds to prompt | Sends permission/question/plan responses via PTY |
| `LogViewerView` | `TTYBridge.detach()` | User taps stop button | Terminates session, removes from SessionManager |
| `SessionManager` | `TTYBridge.spawn()` | spawn(workingDir:) | Creates PTY, launches claude process |
| `SessionManager` | `TTYBridge.onExit` | Bridge setup | Registers auto-cleanup on child process exit |
| `TTYBridge` | `DebugLogging.log()` | All lifecycle + I/O events | Logs spawn, send, read, detach, exit events |
| `AppSettings` | `UserDefaults` | On property change | Persists settings |
| `AppDelegate` | `AppSettings` (observe) | `withObservationTracking` | Re-renders status bar on period change |
