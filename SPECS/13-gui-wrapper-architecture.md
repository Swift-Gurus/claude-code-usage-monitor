# GUI Wrapper Architecture Specification

## Purpose

Design for a native macOS GUI wrapper around Claude Code that provides a rich visual interface for conversations, file changes, tool approvals, and agent monitoring — replacing the terminal-based workflow while retaining full Claude Code functionality including subagents.

---

## Architecture: PTY + JSONL Sidecar

The wrapper runs Claude Code interactively via a hidden pseudo-terminal (PTY) for full feature compatibility, while reading the JSONL conversation files in real-time for structured UI rendering.

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
         │ writes                    │ writes
         ▼                          ▼
~/.claude/projects/{encoded}/    ~/.claude/usage/
  {sessionID}.jsonl                {PPID}.dat
  {sessionID}/subagents/           {PPID}.agent.json
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

## Data Flow

### 1. Conversation Rendering (JSONL → Chat View)

The app polls the session JSONL file (sub-second interval) and renders messages as chat bubbles using the existing `LogParser` infrastructure.

```
JSONL entry (type: "assistant")
  → LogParser.parseMessages()
    → LogMessage { role, model, textContent, toolCalls }
      → Chat bubble with text + tool call chips
```

User messages, assistant responses, tool calls, and tool results all appear in the JSONL in chronological order. The existing deduplication (last entry per message.id wins) handles streaming partials.

### 2. File Change Tracking (FSEvents → Diff Viewer)

Claude Code's Edit/Write tool calls modify files on disk. The app watches the project directory via FSEvents and shows diffs when files change.

```
Tool call in JSONL: Edit { file_path, old_string, new_string }
  → Diff view: red (old) / green (new)

FSEvents on project dir
  → Detect file modification
  → Show file in sidebar with change indicator
```

The JSONL tool_use content contains `old_string`/`new_string` for Edit and `content` for Write — these can render rich diffs without needing to compute diffs ourselves.

### 3. Interactive Prompt Detection (JSONL Gap → Native UI)

When Claude Code waits for user input (tool permission, AskUserQuestion), the JSONL shows a `tool_use` entry without a subsequent `tool_result`. The app detects this gap and shows native UI.

#### Tool Permission Flow

```
1. JSONL: assistant entry with tool_use (e.g., Edit file.swift)
2. [No tool_result follows within ~500ms]
3. App detects pending tool_use → shows native permission dialog
4. User clicks Allow/Deny
5. App sends "y" or "n" to PTY stdin
6. CC executes (or skips) → writes tool_result to JSONL
7. App updates chat view
```

#### AskUserQuestion Flow

```
1. JSONL: assistant entry with tool_use name="AskUserQuestion"
   input: { questions: [{ question, options, multiSelect }] }
2. App parses the question structure
3. Shows native radio buttons / checkboxes / text input
4. User selects answer
5. App formats response and sends to PTY stdin
6. CC continues with the answer
```

#### Alternative: PreToolUse Hooks

Claude Code supports hooks — shell commands that fire on events. A `PreToolUse` hook can notify the app before tool execution, providing a cleaner signal than JSONL gap detection:

```json
// ~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [{
      "command": "echo '{tool_name}:{tool_input}' | nc localhost 9999"
    }]
  }
}
```

The app listens on a local socket for hook notifications. This avoids the timing uncertainty of JSONL polling for permission detection.

### 4. Agent & Subagent Monitoring (Existing Infrastructure)

The existing `AgentTracker`, `UsageData`, and subagent scanning infrastructure carries over directly:

- **Cost tracking**: Statusline fires in interactive mode → `.dat` / `.agent.json` files → `UsageData`
- **Subagent tracking**: `AgentTracker.writeSubagentFiles()` scans subagent JSONL dirs → `.subagent-details.json`
- **Subagent naming**: `JSONLParser.parseSubagentMeta()` maps Agent tool calls to subagent descriptions

---

## PTY Management

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

## UI Layout

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
│  ◐ sub2  │  [Enter prompt...]                        [Send]  │
│  ◐ sub3  │                                                    │
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
| Permission prompts | JSONL gap detection or hooks | 200-500ms |

---

## Session Management

### New Session

```
1. User selects project directory
2. App spawns: claude --cwd <dir>
3. Session JSONL created at ~/.claude/projects/{encoded}/{sessionID}.jsonl
4. App starts polling JSONL for messages
5. Statusline fires → .dat/.agent.json written → cost tracking begins
```

### Resume Session

```
1. App scans ~/.claude/projects/ for existing session JSONLs
2. User selects a session
3. App spawns: claude --resume <sessionID> --cwd <dir>
4. Existing messages loaded from JSONL (history)
5. New messages appear as conversation continues
```

### Multiple Sessions

Multiple PTY instances can run simultaneously (like multiple terminal tabs). Each has its own:
- PTY process
- Session JSONL
- Subagent directory
- Cost tracking via statusline

---

## Reusable Components from Existing App

| Component | Current Use | GUI Wrapper Use |
|-----------|-------------|-----------------|
| `LogParser` | JSONL to display-ready messages | Chat view rendering |
| `LogViewerView` | Chat-bubble log viewer (parent + subagent) | Basis for chat panel |
| `LogMessage` / `LogToolCall` | Structured message data model | Chat message model |
| `ExpandableSection` | Collapsible thinking/tool blocks | Expandable chat sections |
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

### Phase 1: PTY + Chat (MVP)

- Spawn Claude Code via PTY
- Poll JSONL, render chat bubbles (reuse `LogParser` + `LogViewerView` patterns)
- Text input field sends prompts to PTY stdin
- Basic cost display from statusline

### Phase 2: Interactive Prompts

- Detect pending tool_use (JSONL gap detection)
- Native permission dialog (Allow/Deny buttons)
- Native AskUserQuestion rendering
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

---

## Open Questions

1. **Does CC expose session ID before first response?** Needed to start JSONL polling immediately after spawn. May need to scan `~/.claude/projects/` for newest file.
2. **Hook reliability** — Are PreToolUse hooks guaranteed to fire before the terminal prompt? Need to verify timing.
3. **AskUserQuestion stdin format** — What exact text does CC expect when the user selects an option? Need to reverse-engineer from terminal interaction.
4. **Window target** — Should this be a separate app or a new mode within ClaudeUsageBar? Separate app is cleaner but duplicates dependencies.
5. **Licensing** — Does wrapping CC in a GUI violate any terms of service? Should verify with Anthropic.
