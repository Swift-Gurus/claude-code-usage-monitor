# GUI Wrapper Architecture Specification

## Purpose

Native macOS GUI wrapper around Claude Code that provides a rich visual interface for conversations, file changes, tool approvals, and agent monitoring. The app can both monitor existing CLI sessions (read-only) and spawn new sessions via hidden PTY with full bidirectional control including input, permission handling, and interactive prompt responses.

---

## Architecture Overview

The app uses a PTY + JSONL architecture:
- **JSONL** is the source of truth for conversation rendering (parsed by `LogParser`)
- **PTY** (via `TTYBridge`) provides bidirectional communication for app-spawned sessions
- **SessionManager** is a central registry of active PTY sessions, shared across all views

### Current Architecture (Implemented)

```
+--------------------------------------------------------------+
|  ClaudeUsageBar (macOS menu bar app)                          |
|                                                               |
|  +---------------+  +--------------+  +--------------------+ |
|  | PopoverView   |  | Subagent     |  | LogViewerView      | |
|  | + Open Project |  | DetailView  |  | + Input field      | |
|  | + Agent list   |  | + Log icon  |  | + Prompt modals    | |
|  +-------+-------+  +------+-------+  | + Connection dot   | |
|          |                  |          | + Stop button      | |
|          |                  |          +--------+-----------+ |
|          |                  |                   |             |
|  +-------+------------------+-------------------+----------+ |
|  |                 SessionManager (@Observable)             | |
|  |  sessions: [Int: TTYBridge]  (keyed by child PID)       | |
|  +-----+------------------------------------+--------------+ |
|        |                                    |                 |
|  +-----+------+                    +--------+--------+       |
|  | TTYBridge   |                   | DebugLogger     |       |
|  | openpty +   |                   | Protocol-based  |       |
|  | Process     |                   | FileDebugLogger |       |
|  +------+------+                   | NullLogger      |       |
|         | stdin/stdout             +-----------------+       |
|  +------+------+                                             |
|  | claude CLI   |                                            |
|  | (child proc) |                                            |
|  +------+------+                                             |
|         | writes                                             |
|  +------+----------------------------+                       |
|  | ~/.claude/projects/{encoded}/     |                       |
|  |   {sessionID}.jsonl               |                       |
|  |   {sessionID}/subagents/          |                       |
|  +-----------------------------------+                       |
+--------------------------------------------------------------+
```

### Why PTY + JSONL (not pipe mode, not API-direct)

| Approach | Subagents | Statusline | Structured Data | Tool Approval UI | Complexity |
|----------|-----------|------------|-----------------|------------------|------------|
| **PTY + JSONL sidecar** | Yes | Yes | Yes (JSONL) | Yes (gap detection) | Medium |
| Pipe mode (`-p`) | Limited/No | No | Yes (stream-json) | No prompts | Low |
| PTY only (parse terminal) | Yes | Yes | No (ANSI scraping) | Fragile | High |
| API direct (no CLI) | Custom impl | N/A | Yes | Full control | Very High |

PTY + JSONL is the sweet spot: full CC feature support with structured data for the UI.

---

## TTYBridge — PTY Process Management

`Sources/TTYBridge.swift` spawns and manages a Claude Code process under a hidden PTY.

### Class Design

```swift
public final class TTYBridge {
    private var masterFD: Int32 = -1
    private var process: Process?
    private var readSource: DispatchSourceRead?
    public private(set) var isAttached = false
    public private(set) var childPID: Int = 0
    private let logger: DebugLogging

    public var onActivity: (() -> Void)?
    public var onExit: ((Int32) -> Void)?
}
```

### Spawning

Two spawn methods:
- `spawn(workingDir:)` -- starts a fresh `claude` session
- `spawn(sessionID:workingDir:)` -- resumes with `claude --resume <sessionID>`

Both delegate to `spawnProcess(arguments:workingDir:)`:

1. **PTY creation**: `openpty(&master, &slave, nil, nil, nil)` creates a pseudo-terminal pair
2. **Window size**: `ioctl(master, TIOCSWINSZ, &ws)` sets 200 columns x 50 rows
3. **Process setup**: `Process()` with `executableURL = /opt/homebrew/bin/claude`
4. **Environment stripping**: Removes `CLAUDECODE` and `CLAUDE_CODE_ENTRYPOINT` env vars to prevent nesting-detection refusal
5. **Slave FD**: The slave end is set as stdin/stdout/stderr for the child process via `FileHandle(fileDescriptor: slave)`
6. **Process.run()**: Launches the child; slave fd is closed in the parent after launch

Key difference from the original spec: uses `Process` (Foundation) instead of `fork`+`exec`. This is safer for macOS apps (no address space duplication, no signal handler inheritance issues).

### Activity Monitoring

A `DispatchSourceRead` on the master fd monitors output from Claude:

```
GCD Read Source (global .utility queue)
  -> reads up to 8192 bytes
  -> logs first 200 chars via DebugLogging
  -> auto-handles trust prompt (first output only)
  -> dispatches onActivity callback to main queue
```

### Trust Prompt Auto-Handler

On first output from a new session, Claude may ask "Do you trust this folder?". The bridge auto-responds:

```swift
if !trustHandled {
    if output.contains("trust") || output.contains("Yes,") {
        "\r".data(using: .utf8)!.withUnsafeBytes { ptr in
            _ = Darwin.write(self.masterFD, ptr.baseAddress!, ptr.count)
        }
        trustHandled = true
        return
    }
    trustHandled = true  // skip after first non-trust output
}
```

Sends a carriage return (`\r`) to accept the default trust option.

### Input Methods

**`send(_ text: String)`** -- for user prompts:
1. Writes the full text as a bulk paste via `Darwin.write(fd, ...)`
2. Waits 50ms (`usleep(50_000)`) for the TUI to process the paste
3. Sends carriage return (`0x0D`) to submit

This two-step approach is required because Claude's TUI uses raw terminal mode (not line-buffered). The 50ms delay ensures the text is processed before the Enter key arrives.

**`sendRaw(_ text: String)`** -- for control sequences (no newline appended):
- Permission responses: `"\r"` (Enter to allow), `"\u{1b}"` (Escape to deny)
- Arrow key navigation: `"\u{1b}[B"` (down arrow for AskUserQuestion option selection)
- Logs raw bytes sent for debugging

### Process Lifecycle

**Termination handler**: Set on `proc.terminationHandler`, logs exit status and reason, dispatches `onExit` callback to main queue, sets `isAttached = false`.

**Detach**: `detach()` cancels the read source (which closes the master fd via `setCancelHandler`), terminates the process if running, and resets all state.

**Deinit**: Calls `detach()` to ensure cleanup.

---

## SessionManager — Central Session Registry

`Sources/SessionManager.swift` manages all app-spawned Claude sessions.

### Class Design

```swift
@Observable
public final class SessionManager {
    public var sessions: [Int: TTYBridge] = [:]  // keyed by child PID
    private let logger: DebugLogging
}
```

Uses `@Observable` so SwiftUI views reactively update when sessions are added/removed.

### API

| Method | Description |
|--------|-------------|
| `spawn(workingDir:)` | Creates a `TTYBridge`, calls `bridge.spawn(workingDir:)`, registers in `sessions` by PID, sets up `onExit` to auto-remove. Returns the bridge or nil on failure. |
| `bridge(for: pid)` | Looks up the `TTYBridge` for a given PID. Used by `LogViewerView` to check if it owns a session. |
| `cleanup()` | Removes dead sessions (where `!bridge.isAttached`). |
| `detachAll()` | Detaches all sessions. Called on app termination. |

### Lifecycle Integration

Created in `AppDelegate` with `FileDebugLogger` (enabled=true):

```swift
private let sessionManager: SessionManager = {
    let logger = FileDebugLogger()
    logger.isEnabled = true
    return SessionManager(logger: logger)
}()
```

Passed through:
- `AppDelegate` -> `PopoverView` (as constructor param)
- `PopoverView` -> `SubagentDetailView` (as property)
- `SubagentDetailView` -> `LogViewerView` (as optional property)

---

## DebugLogger — Protocol-Based Logging

`Sources/DebugLogger.swift` provides injectable logging.

### Protocol

```swift
public protocol DebugLogging {
    func log(_ msg: String, category: String)
}
extension DebugLogging {
    public func log(_ msg: String) { log(msg, category: "General") }
}
```

### Implementations

**FileDebugLogger**: Writes to `~/.claude/usage/debug.log`. Has an `isEnabled` flag (default false). Format: `[{date}] [{category}] {message}\n`. Creates the file if it doesn't exist, appends otherwise.

**NullLogger**: No-op implementation. Default for components that don't need logging.

Injected into `TTYBridge` and `SessionManager` via constructor parameter.

---

## Open Project — Spawning New Sessions

`PopoverView` includes an "Open Project" button below the agent list.

### UI

```
[+circle.fill] Open Project
```

- Blue plus icon + "Open Project" label
- `.caption` font, `.medium` weight
- Full-width left-aligned, `.plain` button style

### Flow

```
1. User taps "Open Project"
2. NSOpenPanel opens (directories only, single selection)
3. User selects a project directory
4. SessionManager.spawn(workingDir: url.path) creates a TTYBridge
5. A synthetic AgentInfo is constructed:
   - pid: bridge.childPID
   - model: "Starting..."
   - sessionID: "" (empty — will be discovered later)
   - workingDir: selected path
   - isIdle: false, source: .cli
6. selectedAgent = syntheticAgent -> navigates to SubagentDetailView
7. SubagentDetailView passes sessionManager to LogViewerView
8. LogViewerView detects the bridge for this PID and enables input
```

### Auto-Navigation

Immediately after spawning, the app navigates to the agent detail view. The synthetic `AgentInfo` has `sessionID: ""` which means the log viewer may not find a JSONL file right away. The TTY bridge's `onActivity` callback triggers `loadMessages()` which polls for the JSONL file.

---

## Data Flow

### 1. Conversation Rendering (JSONL -> Chat View)

The app polls the session JSONL file (2-second interval + TTY activity triggers) and renders messages as chat bubbles using `LogParser`.

```
JSONL entry (type: "assistant")
  -> LogParser.parseMessages()
    -> LogMessage { role, model, textContent, toolCalls, toolResultIDs, toolResponses }
      -> Chat bubble with text + tool call chips + interactive prompts
```

User messages, assistant responses, tool calls, and tool results all appear in the JSONL in chronological order. The existing deduplication (last entry per message.id wins, tool calls merged by tool_use id) handles streaming partials.

### 2. Pending Prompt Detection (JSONL Gap)

When Claude waits for user input, the JSONL shows a `tool_use` without a subsequent `tool_result`. The `pendingPrompt` computed property detects this:

```
1. Collect all tool_use IDs that have been resolved (via toolResultIDs across all messages)
2. Scan messages in reverse for the last assistant message
3. Check each tool_use: if its ID is NOT in resolvedIDs and data.needsPrompt == true -> PENDING
4. needsPrompt is true for: .bash, .edit, .write, .askUserQuestion, .exitPlanMode
```

Only checked when `canSendInput == true` (parent target + bridge attached).

### 3. User Response Rendering (toolUseResult)

When a user responds to a prompt, the JSONL `tool_result` entry may contain a `toolUseResult` field at the top level. The parser extracts structured responses:

- **AskUserQuestion answered**: `toolUseResult` is a dict with `answers: [String: String]` -> `ToolResponse.answered`
- **ExitPlanMode approved**: `toolUseResult` is a dict with `plan` key present -> `ToolResponse.approved`
- **Permission allowed**: `is_error == false` and tool ID was in `promptToolIDs` -> `ToolResponse.approved`, displayed as "Allowed"
- **Rejected**: `is_error == true`, extracts feedback after "the user said:\n" -> `ToolResponse.rejected(feedback:)`

### 4. File Change Tracking (Existing)

JSONL tool_use content contains `old_string`/`new_string` for Edit and `content` for Write -- rendered as rich diffs via `editDiffView` and `writeDiffView` in LogViewerView.

### 5. Agent & Subagent Monitoring (Existing)

The existing `AgentTracker`, `UsageData`, and subagent scanning infrastructure carries over directly:

- **Cost tracking**: Statusline fires in interactive mode -> `.dat` / `.agent.json` files -> `UsageData`
- **Subagent tracking**: `AgentTracker.writeSubagentFiles()` scans subagent JSONL dirs -> `.subagent-details.json`
- **Subagent naming**: `JSONLParser.parseSubagentMeta()` maps Agent tool calls to subagent descriptions

---

## Interactive Prompt Handling

### Permission Prompts (Bash, Edit, Write)

Displayed as a modal overlay with shield icon, tool name, and summary:

```
+--------------------------------------------+
|  [shield] Bash  swift build 2>&1 | tail -5 |
|                                             |
|      [Allow (green)]    [Deny (red)]        |
+--------------------------------------------+
```

- **Allow**: `bridge.sendRaw("\r")` -- Enter key to accept the default "Allow once" option
- **Deny**: `bridge.sendRaw("\u{1b}")` -- Escape key to cancel/dismiss

Background: orange tint at 0.08 opacity.

### AskUserQuestion Prompts

Displayed as a modal with radio button selection:

```
+--------------------------------------------+
|  Optional Header                            |
|  Question text here?                        |
|                                             |
|  (*) Option 1 label                         |
|      Option 1 description                   |
|  ( ) Option 2 label                         |
|      Option 2 description                   |
|  ( ) Option 3 label                         |
|                                             |
|              [Submit]                        |
+--------------------------------------------+
```

- Options are clickable radio buttons with fill/empty circle icons
- Selection tracked via `@State selectedOptionIdx` and `@State promptToolID` (resets when a new prompt appears)
- **Submit**: Sends arrow-down keys to navigate to the selected option, then Enter:
  ```swift
  for _ in 0..<idx {
      bridge?.sendRaw("\u{1b}[B")  // down arrow, each as separate write()
  }
  bridge?.sendRaw("\r")  // Enter to confirm
  ```
- Each arrow key is sent as a separate `write()` call so the TUI processes them as individual key events

Background: blue tint at 0.08 opacity.

### ExitPlanMode Prompts

Displayed as an Approve/Reject dialog:

```
+--------------------------------------------+
|  [doc.text] Plan ready for review           |
|                                             |
|    [Approve (green)]    [Reject (red)]      |
+--------------------------------------------+
```

- **Approve**: `bridge.sendRaw("\r")` -- Enter to confirm
- **Reject**: `bridge.sendRaw("\u{1b}")` -- Escape to cancel

Background: purple tint at 0.08 opacity.

### Modal Overlay

All prompt types display as a modal overlay on top of the log content:

```swift
.overlay {
    if let pending = pendingPrompt {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            promptView(pending)
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8)
                .padding(16)
        }
    }
}
```

The input field is hidden when a modal prompt is active (`canSendInput && pendingPrompt == nil`).

---

## PTY Input Field

### Design

An auto-expanding `TextEditor` at the bottom of the log view, visible only for parent agent sessions with an active TTY bridge:

```
+---------------------------------------+
| [TextEditor: auto-expanding]    [Send]|
+---------------------------------------+
```

- Auto-sizing: invisible `Text` drives height via `ZStack` overlay pattern
- Min height: 36pt, max height: 120pt
- Placeholder: "Type a message..." in `.tertiary` when empty
- Send button: `arrow.up.circle.fill` at 24pt, blue when enabled, grey when disabled
- Keyboard shortcut: Cmd+Return

### Sending

```swift
private func sendInput() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    bridge?.send(text)  // bulk paste + 50ms delay + CR
    inputText = ""
}
```

---

## Session Lifecycle

### New Session (via Open Project)

```
1. User taps "Open Project" in PopoverView
2. NSOpenPanel: canChooseDirectories=true, canChooseFiles=false
3. SessionManager.spawn(workingDir:) creates TTYBridge
4. TTYBridge.spawn(workingDir:) calls openpty + Process.run()
5. Trust prompt auto-handled on first output
6. Synthetic AgentInfo constructed, navigate to SubagentDetailView
7. TTY onActivity triggers JSONL reload in LogViewerView
8. 2-second fallback polling also reloads JSONL
```

### Session Stop

From LogViewerView header, the stop button (red `stop.circle.fill`):

```swift
bridge?.detach()
sessionManager?.sessions.removeValue(forKey: agent.pid)
onStop?()  // triggers navigation back to parent view
```

### Auto-Cleanup on Exit

`TTYBridge.onExit` callback (set by SessionManager) removes the session from the registry when the child process exits naturally.

### Connection Indicator

The log viewer header shows a connection dot:
- **Green**: `canSendInput == true` (parent target + bridge attached)
- **Grey**: read-only (no bridge, or subagent target)

---

## Reusable Components

| Component | Current Use | GUI Wrapper Use |
|-----------|-------------|-----------------|
| `LogParser` | JSONL to display-ready messages | Chat view rendering |
| `LogViewerView` | Chat-bubble log viewer + input + prompts | Full chat interface |
| `LogMessage` / `LogToolCall` / `ToolData` | Structured message + tool data model | Chat message model + prompt rendering |
| `ToolResponse` | Structured user response from toolUseResult | Display "Allowed", answers, feedback in chat |
| `TTYBridge` | PTY spawn + bidirectional communication | Process management |
| `SessionManager` | Central registry of spawned sessions | Session lifecycle |
| `DebugLogger` / `DebugLogging` | Protocol-based logging | Debugging PTY communication |
| `ExpandableSection` | Collapsible thinking/tool blocks | Expandable chat sections |
| `editDiffView` / `writeDiffView` | Inline diff rendering for Edit/Write tools | File change visualization |
| `todoChecklist` | TodoWrite checklist rendering | Task panel |
| `JSONLParser` | Cost calculation + subagent meta | Cost calculation (unchanged) |
| `AgentTracker` | Agent monitoring (with JSONL idle detection) | Agent sidebar panel |
| `UsageData` | Period cost aggregation | Cost display |
| `SubagentInfo` | Subagent drill-down (with description/type) | Agent sidebar detail |
| `SessionScanner` | Commander session discovery | Session management |
| `FlowLayout` | Tool chips | Tool chips in chat |
| `PriceCalculator` | Cost estimation | Cost estimation |
| `AppSettings` | Display mode, appearance, expand settings | Settings panel |

---

## Implementation Status

### Completed

- TTYBridge: PTY spawn via `openpty` + `Process` (not fork)
- SessionManager: central registry with auto-cleanup
- DebugLogger: protocol injection with FileDebugLogger and NullLogger
- Open Project: NSOpenPanel + spawn + auto-navigate
- Trust prompt auto-handler
- Input field: auto-expanding TextEditor, parent agents only, bulk paste + 50ms delay + CR
- JSONL gap detection for pending prompts
- Modal overlay for permissions (Enter=Allow, Escape=Deny)
- Modal overlay for AskUserQuestion (radio buttons, arrow key navigation, separate write per key)
- Modal overlay for ExitPlanMode (Approve/Reject)
- User response display from toolUseResult structured data
- Connection indicator (green/grey dot)
- Stop session button
- Empty bubble filtering in message list

### Future (Not Yet Implemented)

- **Hooks integration**: Migrate from JSONL gap detection to `PreToolUse`/`PostToolUse` HTTP hooks for instant, polling-free prompt detection
- **File sidebar**: FSEvents on project directory with modification indicators
- **Session resume**: `claude --resume <sessionID>` support
- **Multi-session tabs**: Session picker / tab bar for concurrent sessions
- **Session history browser**: Browse and resume past sessions

---

## Hooks Approach (Future — Production Enhancement)

Claude Code supports hooks with 16+ event types. Hooks can be `"type": "http"` -- they POST JSON to a URL, and Claude Code waits for the response (synchronous by default). This would eliminate JSONL polling for prompt detection entirely.

### Architecture

```
+-----------------+     POST /hook      +------------------+
|  Claude Code    | ------------------> |  ClaudeUsageBar  |
|                 |                     |  localhost:9999   |
|  PreToolUse     | <------------------ |                  |
|                 |   JSON response     |  Shows prompt UI |
|                 |   allow/deny/ask    |  User clicks     |
+-----------------+                     +------------------+
```

### Advantages over JSONL Gap Detection

- **No polling delay** -- instant notification via HTTP POST
- **No false positives** -- no timing heuristics needed
- **Synchronous control** -- PreToolUse blocks until app responds
- **Full tool input** -- receives complete `tool_input` JSON
- **Bidirectional** -- app can allow, deny, or defer each tool individually
- **No TTY needed for permissions** -- the hook response IS the permission decision

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| CC changes JSONL format | Chat view breaks | Version-tolerant parser, defensive decoding |
| CC changes terminal prompt format | Permission detection breaks | JSONL gap detection is format-agnostic; future hooks approach eliminates this risk |
| PTY process leaks | Zombie processes | SessionManager auto-cleanup on exit + `onExit` handler + `detachAll()` on app terminate |
| Large JSONL files (long sessions) | Memory/performance | Mtime-based cache skips re-parsing unchanged files |
| CC updates break PTY interaction | Input format changes | Minimal PTY interaction (bulk paste + CR for text, raw bytes for control), low surface area |
| Trust prompt format changes | Auto-handler fails | Falls through after first output; user can manually respond via input field |
| 50ms delay insufficient for slow machines | Text arrives after Enter | Delay is conservative; could be made configurable if needed |

---

## Resolved Questions

1. **AskUserQuestion stdin format** -- Arrow down keys (`ESC[B`) navigate between options, Enter confirms. Each arrow key must be a separate `write()` call so the TUI receives them as individual key events. The first option is pre-selected, so sending N down arrows selects option N.

2. **Permission response format** -- Enter (`\r`) accepts the default "Allow once" option. Escape (`ESC`) dismisses/denies the permission prompt.

3. **Window target** -- Integrated into ClaudeUsageBar as a feature (not a separate app). SessionManager is shared across all views.

4. **PTY vs fork** -- Uses `Process` (Foundation) rather than `fork`+`exec`. Safer for macOS apps, avoids address space duplication issues.

## Open Questions

1. **Hook reliability** -- Are PreToolUse hooks guaranteed to fire before the terminal prompt? Need to verify timing before implementing hooks approach.
2. **Multi-session UI** -- How to present multiple concurrent sessions? Tab bar, sidebar, or session switcher dropdown?
