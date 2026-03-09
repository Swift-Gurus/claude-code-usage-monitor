# GUI Wrapper Architecture Specification

## Purpose

Design for a native macOS GUI wrapper around Claude Code that provides a rich visual interface for conversations, file changes, tool approvals, and agent monitoring — replacing the terminal-based workflow while retaining full Claude Code functionality including subagents.

---

## Architecture Overview

Two-phase approach:
1. **POC (Phase 0)**: Attach to existing Claude Code sessions via TTY device, add input field + interactive prompts to the existing LogViewerView
2. **Full (Phase 1+)**: Spawn Claude Code via hidden PTY with full lifecycle control

Both phases use JSONL as the source of truth for conversation rendering, with TTY/PTY for sending user input.

### POC Architecture (Attach to Existing)

```
┌──────────────────────────────────────────────────────┐
│  ClaudeUsageBar (existing app)                        │
│                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐│
│  │ LogViewer   │  │ Agent        │  │ Cost         ││
│  │ + Input     │  │ Dashboard    │  │ Tracking     ││
│  │ + Prompts   │  │ (existing)   │  │ (existing)   ││
│  └──────┬──────┘  └──────────────┘  └──────────────┘│
│         │                                             │
│  ┌──────┴──────────────────────────┐                 │
│  │ TTY Writer                     │                 │
│  │ - Resolve TTY via proc_pidinfo │                 │
│  │ - Write prompts to /dev/ttysXXX│                 │
│  │ - Write "y"/"n" for permissions│                 │
│  └─────────────────────────────────┘                 │
│         │ reads                                       │
│  ┌──────┴──────────────────────────┐                 │
│  │ JSONL Poller                   │                 │
│  │ - Detect pending tool_use      │                 │
│  │ - Show interactive prompts     │                 │
│  │ - Render conversation          │                 │
│  └─────────────────────────────────┘                 │
└──────────────────────────────────────────────────────┘
         │ reads                    │ reads
         ▼                          ▼
~/.claude/projects/{encoded}/    ~/.claude/usage/
  {sessionID}.jsonl                {PPID}.dat
  {sessionID}/subagents/           {PPID}.agent.json
```

### Full Architecture (Spawn via PTY)

```
┌──────────────────────────────────────────────────────┐
│  Native macOS App (SwiftUI)                           │
│                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐│
│  │ Chat View   │  │ File Diff    │  │ Agent        ││
│  │ (JSONL)     │  │ Viewer       │  │ Dashboard    ││
│  │             │  │ (FSEvents)   │  │ (existing)   ││
│  └──────┬──────┘  └──────────────┘  └──────────────┘│
│         │                                             │
│  ┌──────┴──────────────────────────┐                 │
│  │ Interactive Prompt Handler      │                 │
│  │ - Permission UI (JSONL gap)     │                 │
│  │ - AskUserQuestion (native)      │                 │
│  │ - Text input (prompt composer)  │                 │
│  └──────┬──────────────────────────┘                 │
│         │ stdin/stdout                                │
│  ┌──────┴──────────────────────────┐                 │
│  │ PTY (hidden)                    │                 │
│  │ Claude Code interactive mode    │                 │
│  │ - Full tool support             │                 │
│  │ - Subagent spawning             │                 │
│  │ - Statusline callbacks          │                 │
│  └─────────────────────────────────┘                 │
└──────────────────────────────────────────────────────┘
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

## POC: TTY Attach + Input Field

### TTY Resolution

Resolve the controlling terminal for a running `claude` process using `proc_pidinfo`:

```swift
import Darwin

func ttyPath(for pid: pid_t) -> String? {
    var info = proc_bsdinfo()
    let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info,
                            Int32(MemoryLayout.size(ofValue: info)))
    guard size > 0 else { return nil }
    return devname(info.e_tdev, S_IFCHR).map { "/dev/" + String(cString: $0) }
}
```

Once resolved, open the TTY device for writing:

```swift
func openTTY(for pid: pid_t) -> FileHandle? {
    guard let path = ttyPath(for: pid) else { return nil }
    return FileHandle(forWritingAtPath: path)
}
```

### Input Field

Added to `LogViewerView` for **parent agent sessions only** (not subagent logs):

- Text editor (not single-line TextField) at the bottom of the log view
- Default height: 5 lines
- Auto-expands as user types more lines
- Send button (or Enter) writes text + newline to the TTY
- Disabled/hidden when viewing subagent logs

```
┌──────────────────────────────────────────┐
│  ← Back            Session Logs     📋   │
├──────────────────────────────────────────┤
│  [Log messages...]                       │
│                                          │
│                                          │
├──────────────────────────────────────────┤
│  ┌────────────────────────────────┐      │
│  │ Type a message...              │ Send │
│  │                                │      │
│  │                                │      │
│  └────────────────────────────────┘      │
└──────────────────────────────────────────┘
```

### Sending Messages

```swift
func sendMessage(_ text: String, to pid: pid_t) {
    guard let tty = openTTY(for: pid) else { return }
    let data = (text + "\n").data(using: .utf8)!
    tty.write(data)
    tty.closeFile()
}
```

Only available for parent agent sessions. Subagent logs are read-only (subagents run autonomously — the parent controls them).

---

## Interactive Prompt Detection

### JSONL Gap Detection (POC)

When Claude Code waits for user input (tool permission, AskUserQuestion), the JSONL shows a `tool_use` entry without a subsequent `tool_result`. The app detects this gap and shows a unified prompt UI.

#### Detection Algorithm

```
1. Parse all messages from JSONL
2. For each assistant message with tool_use entries:
   a. Collect all tool_use IDs from the message
   b. Check if matching tool_result exists in subsequent user messages
   c. If no tool_result found → tool is PENDING (waiting for user input)
3. For pending tools:
   - AskUserQuestion → show question UI with options
   - ExitPlanMode → show plan approval UI
   - Edit/Write/Bash → show permission prompt (Allow/Deny)
   - Other → show generic approval prompt
```

#### JSONL Message Patterns

**Tool permission (Bash, Edit, Write, etc.):**
```
assistant: { content: [{ type: "tool_use", name: "Bash", id: "toolu_xxx",
                          input: { command: "rm -rf ...", description: "..." } }] }
  ↓ (gap — user being prompted in terminal)
user: { content: [{ type: "tool_result", tool_use_id: "toolu_xxx",
                    content: "<output>", is_error: false }] }
```

**AskUserQuestion:**
```
assistant: { content: [{ type: "tool_use", name: "AskUserQuestion", id: "toolu_xxx",
                          input: { questions: [{ question: "...", options: [...] }] } }] }
  ↓ (gap — user being prompted)
user: { content: [{ type: "tool_result", tool_use_id: "toolu_xxx",
                    content: "User has answered: \"...\"=\"option1\"" }] }
```

**Rejected/Clarified:**
```
user: { content: [{ type: "tool_result", tool_use_id: "toolu_xxx",
                    is_error: true,
                    content: "The user doesn't want to proceed... the user said:\n<feedback>" }] }
```

#### Unified Prompt UI

All pending tool_use entries show as interactive prompt bubbles in the log:

```
┌──────────────────────────────────────────┐
│  🔵 Opus 4.6                  10:00:12   │
│  I'll fix the bug in auth.swift.         │
│                                          │
│  ┌─ 🔒 Bash ────────────────────────┐   │
│  │ swift build 2>&1 | tail -5        │   │
│  │                                    │   │
│  │        [Allow]         [Deny]      │   │
│  └────────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

For AskUserQuestion:
```
┌──────────────────────────────────────────┐
│  ┌─ ❓ Question ──────────────────────┐  │
│  │ Where should the breakdown appear?  │  │
│  │                                     │  │
│  │  ○ In the detail drill-down        │  │
│  │  ○ New main screen section         │  │
│  │  ○ Both                            │  │
│  │                                     │  │
│  │                 [Submit]            │  │
│  └─────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

#### Sending Responses via TTY

- **Tool permission**: Write `"y\n"` (Allow) or `"n\n"` (Deny) to TTY
- **AskUserQuestion**: Write the selected option number + newline (need to reverse-engineer exact format)
- **ExitPlanMode**: Write approval or rejection text to TTY

### Hooks Approach (Production — Phase 2)

Claude Code supports hooks with 16+ event types. Hooks can be `"type": "http"` — they POST JSON to a URL, and Claude Code **waits for the response** (synchronous by default). This eliminates JSONL polling for prompt detection entirely.

#### Architecture

```
┌─────────────────┐     POST /hook      ┌──────────────────┐
│  Claude Code     │ ──────────────────► │  ClaudeUsageBar  │
│                  │                     │  localhost:9999   │
│  PreToolUse hook │ ◄────────────────── │                  │
│                  │   JSON response     │  Shows prompt UI │
│                  │   allow/deny/ask    │  User clicks     │
└─────────────────┘                     └──────────────────┘
```

#### Hook Configuration

```json
// .claude/settings.json (project-level or ~/.claude/settings.json for global)
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [{
          "type": "http",
          "url": "http://localhost:9999/pre-tool"
        }]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [{
          "type": "http",
          "url": "http://localhost:9999/permission"
        }]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [{
          "type": "http",
          "url": "http://localhost:9999/post-tool",
          "async": true
        }]
      }
    ]
  }
}
```

#### What the App Receives (POST body)

```json
{
  "session_id": "abc123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "swift build 2>&1 | tail -5" },
  "cwd": "/Users/crowea/Developer/...",
  "transcript_path": "/path/to/session.jsonl"
}
```

#### What the App Responds With

Allow:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

Deny (with reason fed back to Claude):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "User denied: use rg instead of grep"
  }
}
```

Defer to terminal (let CC show its own prompt):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask"
  }
}
```

#### Key Hook Events

| Event | Matcher | Use Case |
|-------|---------|----------|
| `PreToolUse` | `Bash\|Edit\|Write` | Permission decisions — app shows prompt, responds allow/deny |
| `Notification` | `permission_prompt` | Fires when CC shows permission dialog — more targeted than PreToolUse |
| `PostToolUse` | (all) | Track tool completion, update UI (async) |
| `PostToolUseFailure` | (all) | Track failures (async) |
| `SubagentStart` / `SubagentStop` | (all) | Real-time subagent lifecycle tracking |
| `SessionStart` | (all) | Detect new/resumed sessions |
| `Stop` | (all) | Know when Claude finishes responding |

#### Advantages over JSONL Gap Detection

- **No polling delay** — instant notification via HTTP POST
- **No false positives** — no timing heuristics needed
- **Synchronous control** — PreToolUse blocks until app responds, no TTY writing needed for permissions
- **Full tool input** — receives complete `tool_input` JSON
- **Bidirectional** — app can allow, deny, or defer each tool individually
- **No TTY needed for permissions** — the hook response IS the permission decision

#### Implementation Requirements

1. App starts lightweight HTTP server on `localhost:9999` (or Unix domain socket)
2. Configure hooks in project or user settings
3. Server handles POST requests, routes to prompt UI
4. Prompt UI blocks the HTTP response until user decides
5. Response sent back → Claude Code proceeds or skips
6. Only TTY still needed for: sending new user prompts (not permissions)

---

## Data Flow

### 1. Conversation Rendering (JSONL → Chat View)

The app polls the session JSONL file (sub-second interval) and renders messages as chat bubbles using the existing `LogParser` infrastructure.

```
JSONL entry (type: "assistant")
  → LogParser.parseMessages()
    → LogMessage { role, model, textContent, toolCalls }
      → Chat bubble with text + tool call chips + interactive prompts
```

User messages, assistant responses, tool calls, and tool results all appear in the JSONL in chronological order. The existing deduplication (last entry per message.id wins, tool calls merged by tool_use id) handles streaming partials.

### 2. File Change Tracking (FSEvents → Diff Viewer)

Claude Code's Edit/Write tool calls modify files on disk. The app watches the project directory via FSEvents and shows diffs when files change.

```
Tool call in JSONL: Edit { file_path, old_string, new_string }
  → Diff view: red (old) / green (new)  [already implemented in LogViewerView]

FSEvents on project dir
  → Detect file modification
  → Show file in sidebar with change indicator
```

The JSONL tool_use content contains `old_string`/`new_string` for Edit and `content` for Write — these render rich diffs via the existing `editDiffView` and `writeDiffView` in LogViewerView.

### 3. Agent & Subagent Monitoring (Existing Infrastructure)

The existing `AgentTracker`, `UsageData`, and subagent scanning infrastructure carries over directly:

- **Cost tracking**: Statusline fires in interactive mode → `.dat` / `.agent.json` files → `UsageData`
- **Subagent tracking**: `AgentTracker.writeSubagentFiles()` scans subagent JSONL dirs → `.subagent-details.json`
- **Subagent naming**: `JSONLParser.parseSubagentMeta()` maps Agent tool calls to subagent descriptions

---

## PTY Management (Full Mode — Phase 1+)

### Spawning

```swift
import Darwin

func spawnClaudeCode(workingDir: String) -> (pid: pid_t, masterFD: Int32) {
    var masterFD: Int32 = 0
    var slaveFD: Int32 = 0
    openpty(&masterFD, &slaveFD, nil, nil, nil)

    let pid = fork()
    if pid == 0 {
        // Child: set up PTY as stdin/stdout/stderr
        close(masterFD)
        setsid()
        dup2(slaveFD, STDIN_FILENO)
        dup2(slaveFD, STDOUT_FILENO)
        dup2(slaveFD, STDERR_FILENO)
        close(slaveFD)
        chdir(workingDir)
        execvp("claude", ["claude"])
    }
    close(slaveFD)
    return (pid, masterFD)
}
```

### Input/Output

- **Read from PTY**: Raw terminal output (ANSI). Used as a fallback "raw view" tab, not primary UI.
- **Write to PTY**: User prompts, permission responses ("y"/"n"), AskUserQuestion answers.
- **Window sizing**: `ioctl(masterFD, TIOCSWINSZ, &winsize)` — set to reasonable defaults since output isn't displayed raw.

### Process Lifecycle

- **Start**: User opens/creates a session → spawn PTY with `claude` or `claude --resume <sessionID>`
- **Send prompt**: Write user text + newline to PTY stdin
- **Interrupt**: Send SIGINT to child process (`kill(pid, SIGINT)`) — equivalent to Ctrl+C
- **Stop**: Send `/quit` command or SIGTERM
- **Crash recovery**: Monitor child process, show error if it exits unexpectedly

---

## UI Layout (Full Mode)

```
┌──────────────────────────────────────────────────────────────┐
│  [Sessions ▾]  project-name          [$12.34]  [Settings]    │
├──────────┬───────────────────────────────────────────────────┤
│          │                                                    │
│ Files    │  Chat / Conversation                              │
│          │                                                    │
│ ▸ src/   │  🟢 User                              10:00:05   │
│   auth.* │  ┌──────────────────────────────────┐             │
│   login. │  │ Fix the login bug in auth.swift  │             │
│          │  └──────────────────────────────────┘             │
│ Modified:│                                                    │
│  auth.sw │  🔵 Opus 4.6                          10:00:12   │
│  login.s │  ┌──────────────────────────────────┐             │
│          │  │ I'll look at the auth module.    │             │
│──────────│  │                                  │             │
│          │  │ ▶ Read auth.swift                │             │
│ Agents   │  │ ▶ Edit auth.swift [Allow] [Deny] │             │
│          │  │                                  │             │
│ ● main   │  │ Fixed the null check on line 42. │             │
│   $12.34 │  └──────────────────────────────────┘             │
│   3 subs │                                                    │
│          │                                                    │
│  ◐ sub1  ├───────────────────────────────────────────────────┤
│  ◐ sub2  │  ┌────────────────────────────────┐               │
│  ◐ sub3  │  │ Enter prompt...                │        [Send] │
│          │  │                                │               │
│          │  └────────────────────────────────┘               │
└──────────┴───────────────────────────────────────────────────┘
```

### Panels

| Panel | Source | Update Frequency |
|-------|--------|------------------|
| Chat view | JSONL polling | 200-500ms |
| File sidebar | FSEvents on project dir | Real-time |
| File diff | JSONL tool_use content (Edit/Write) | On tool call |
| Agent dashboard | Existing AgentTracker | 5s poll |
| Cost display | Existing UsageData (statusline) | On statusline fire |
| Permission prompts | JSONL gap detection (POC) / Hooks (production) | 200-500ms |
| Input field | Parent sessions only | User-driven |

---

## Session Management

### New Session (Full Mode)

```
1. User selects project directory
2. App spawns: claude --cwd <dir>
3. Session JSONL created at ~/.claude/projects/{encoded}/{sessionID}.jsonl
4. App starts polling JSONL for messages
5. Statusline fires → .dat/.agent.json written → cost tracking begins
```

### Attach to Existing (POC)

```
1. User clicks on active agent in main view → opens LogViewerView
2. App resolves TTY path via proc_pidinfo(agent.pid)
3. Input field enabled (parent agents only)
4. JSONL polling detects pending tool_use → shows interactive prompts
5. User sends messages/responses via TTY write
```

### Resume Session (Full Mode)

```
1. App scans ~/.claude/projects/ for existing session JSONLs
2. User selects a session
3. App spawns: claude --resume <sessionID> --cwd <dir>
4. Existing messages loaded from JSONL (history)
5. New messages appear as conversation continues
```

### Multiple Sessions

Multiple PTY instances can run simultaneously (like multiple terminal tabs). Each has its own:
- PTY process (or TTY attachment in POC)
- Session JSONL
- Subagent directory
- Cost tracking via statusline

---

## Reusable Components from Existing App

| Component | Current Use | GUI Wrapper Use |
|-----------|-------------|-----------------|
| `LogParser` | JSONL to display-ready messages | Chat view rendering |
| `LogViewerView` | Chat-bubble log viewer (parent + subagent) | Basis for chat panel + input field |
| `LogMessage` / `LogToolCall` / `ToolData` | Structured message + tool data model | Chat message model + prompt rendering |
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

## Implementation Phases

### Phase 0: POC — TTY Attach + Input (Current Sprint)

- Resolve TTY for running `claude` processes via `proc_pidinfo`
- Add auto-expanding text input field to `LogViewerView` (parent sessions only)
- Send user messages to TTY
- Detect pending `tool_use` via JSONL gap detection
- Show unified prompt UI for permissions + AskUserQuestion
- Send permission responses ("y"/"n") and question answers to TTY

### Phase 1: PTY Spawn + Chat

- Spawn Claude Code via hidden PTY (`openpty` + `fork` + `exec`)
- Poll JSONL, render chat bubbles (reuse `LogParser` + `LogViewerView` patterns)
- Text input field sends prompts to PTY master fd
- Basic cost display from statusline
- Process lifecycle management (start, stop, crash recovery)

### Phase 2: Interactive Prompts (Production)

- Migrate from JSONL gap detection to hooks (`PreToolUse` / `PostToolUse`)
- Native permission dialog (Allow/Deny buttons)
- Native AskUserQuestion rendering (radio buttons, checkboxes, text input)
- Send responses to PTY stdin

### Phase 3: File Viewer

- FSEvents on project directory
- File sidebar with modification indicators
- Inline diff view from Edit tool_use content
- Click to open in external editor

### Phase 4: Agent Dashboard

- Port existing AgentTracker/SubagentDetailView
- Real-time subagent monitoring
- Subagent log drill-down (already built)

### Phase 5: Multi-Session

- Session picker / tab bar
- Resume existing sessions
- Multiple concurrent PTY instances
- Session history browser

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| CC changes JSONL format | Chat view breaks | Version-tolerant parser, defensive decoding |
| CC changes terminal prompt format | Permission detection breaks | Use hooks (PreToolUse) as primary signal, JSONL gap as fallback |
| PTY management complexity | Process leaks, zombies | Robust lifecycle management, SIGCHLD handler |
| Large JSONL files (long sessions) | Memory/performance | Incremental parsing, only load tail for display |
| CC updates break PTY interaction | Input format changes | Minimal PTY interaction (just text + y/n), low surface area |
| Subagent JSONL format changes | Subagent tracking breaks | Already handled defensively in existing parser |
| TTY attach fails (POC) | Can't send input | Graceful fallback: disable input field, show read-only log |
| proc_pidinfo requires permissions | TTY resolution fails | Request appropriate entitlements, fallback to lsof |

---

## Open Questions

1. **AskUserQuestion stdin format** — What exact text does CC expect when the user selects an option? Need to reverse-engineer from terminal interaction.
2. **Hook reliability** — Are PreToolUse hooks guaranteed to fire before the terminal prompt? Need to verify timing.
3. **TTY write atomicity** — Does writing to `/dev/ttysXXX` interleave with other terminal input? Need to test with concurrent writes.
4. **Window target** — Should this be a separate app or a new mode within ClaudeUsageBar? Separate app is cleaner but duplicates dependencies.
5. **Sandbox restrictions** — Does App Sandbox allow `proc_pidinfo` and writing to `/dev/ttysXXX`? May need to run outside sandbox for POC.
