# Log Viewer Specification

## Overview

`LogViewerView` displays a Claude Code JSONL conversation log as a chat-style message list with full bidirectional interaction. It parses the raw JSONL file on disk, renders user and assistant messages as colored bubbles, shows tool calls as expandable chips with per-tool custom renderers, supports a task panel that reconstructs task state from tool call history, and provides interactive input/prompt handling for app-spawned sessions via `TTYBridge` and `SessionManager`.

The data layer is split across two files:
- `Sources/LogMessage.swift` -- data models (`LogMessage`, `LogToolCall`, `ToolData`, `ToolResponse`, all tool-specific structs) and the `LogParser` (JSONL parsing, tool data extraction, URL resolution)
- `Sources/LogViewerView.swift` -- SwiftUI view (`LogViewerView`), input field, prompt modals, task panel, tool rendering, `ExpandableSection`, polling

---

## View Properties and Dependencies

```swift
public struct LogViewerView: View {
    let agent: AgentInfo
    let target: LogTarget
    let settings: AppSettings
    var sessionManager: SessionManager?
    var stickyHeader: Bool = false
    var onStop: (() -> Void)?
    let onDismiss: () -> Void
}
```

| Property | Type | Description |
|----------|------|-------------|
| `agent` | `AgentInfo` | The agent whose log to display |
| `target` | `LogTarget` | `.parent` or `.subagent(SubagentInfo)` -- determines which JSONL file to read |
| `settings` | `AppSettings` | Controls expand behavior, display mode, max visible messages |
| `sessionManager` | `SessionManager?` | Optional -- provides access to the TTYBridge for app-spawned sessions |
| `stickyHeader` | `Bool` | `true` in window mode (header pinned above scroll), `false` in popover mode |
| `onStop` | `(() -> Void)?` | Called when user stops the session, triggers navigation back |
| `onDismiss` | `() -> Void` | Called when user taps Back |

### TTY Bridge Resolution

```swift
private var bridge: TTYBridge? {
    sessionManager?.bridge(for: agent.pid)
}
```

Looks up the `TTYBridge` for the current agent's PID via `SessionManager`. Returns nil if this session was not spawned by the app.

### Input Availability

```swift
private var canSendInput: Bool {
    guard case .parent = target else { return false }
    return bridge?.isAttached ?? false
}
```

Input is available only when:
1. The log target is `.parent` (not a subagent)
2. The session was spawned by the app (bridge exists)
3. The bridge is currently attached (process is running)

---

## LogMessage Data Model

```swift
public struct LogMessage: Identifiable {
    public let id: String
    public let role: Role
    public let model: String?
    public let timestamp: Date?
    public let thinking: String?
    public let textContent: [String]
    public let toolCalls: [LogToolCall]
    public let toolResultIDs: Set<String>
    public let toolResponses: [String: ToolResponse]

    public enum Role {
        case user, assistant
    }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | For user messages: `"user-{index}"`. For assistant messages: the `message.id` from the JSONL entry, falling back to `"assistant-{index}"`. Used as the deduplication key for streaming merge. |
| `role` | `Role` | `.user` or `.assistant` |
| `model` | `String?` | The model ID string from the JSONL `message.model` field. Only present on assistant messages. |
| `timestamp` | `Date?` | Parsed from the JSONL `timestamp` field using `ISO8601DateFormatter` with fractional seconds. |
| `thinking` | `String?` | Concatenation of all `"thinking"` content blocks, joined by `"\n\n"`. `nil` if no thinking blocks. |
| `textContent` | `[String]` | Array of text strings from `"text"` content blocks. User messages may have a single string from `message.content` (when content is a plain string, not an array). Also includes synthesized text from tool responses (e.g., "Allowed", answer values, feedback). |
| `toolCalls` | `[LogToolCall]` | Array of tool calls extracted from `"tool_use"` content blocks. |
| `toolResultIDs` | `Set<String>` | Tool_use IDs that have been resolved via `tool_result` in this user message. Used by `pendingPrompt` to detect unanswered prompts. |
| `toolResponses` | `[String: ToolResponse]` | Structured user responses keyed by tool_use_id. Extracted from `toolUseResult` in JSONL entries. |

---

## ToolResponse — Structured User Response

```swift
public enum ToolResponse {
    case answered([String: String])   // AskUserQuestion answers
    case approved                      // ExitPlanMode approved or permission allowed
    case rejected(feedback: String)    // User rejected with optional feedback
}
```

Extracted from the `toolUseResult` field at the top level of JSONL `tool_result` entries:

| Source | Condition | ToolResponse | Display Text |
|--------|-----------|-------------|-------------|
| AskUserQuestion | `toolUseResult.answers` is `[String: String]` | `.answered(answers)` | Answer values joined by ", " |
| ExitPlanMode | `toolUseResult.plan` key exists | `.approved` | "Plan approved" |
| Permission (Bash/Edit/Write) | `is_error == false` and tool ID in `promptToolIDs` | `.approved` | "Allowed" |
| Rejected | `is_error == true` | `.rejected(feedback:)` | Feedback text after "the user said:\n" |

---

## LogToolCall

```swift
public struct LogToolCall: Identifiable {
    public let id: String       // tool_use id from JSONL (for dedup)
    public let name: String
    public let data: ToolData
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | The `id` field from the JSONL `tool_use` content block. Used for deduplication during streaming merge (union by tool_use id). Falls back to `UUID().uuidString` if missing. |
| `name` | `String` | The tool name (e.g., `"Edit"`, `"Bash"`, `"Read"`). |
| `data` | `ToolData` | Parsed tool-specific data. |

---

## ToolData Enum -- All 15 Cases

```swift
public enum ToolData {
    case edit(EditToolData)
    case write(WriteToolData)
    case read(ReadToolData)
    case bash(BashToolData)
    case grep(GrepToolData)
    case glob(GlobToolData)
    case agent(AgentToolData)
    case taskCreate(TaskCreateToolData)
    case taskUpdate(TaskUpdateToolData)
    case todoWrite(TodoWriteToolData)
    case skill(SkillToolData)
    case webSearch(WebSearchToolData)
    case webFetch(WebFetchToolData)
    case askUserQuestion(AskUserQuestionToolData)
    case exitPlanMode(ExitPlanModeToolData)
    case other(raw: [String: String])
}
```

### Tool-Specific Structs

**EditToolData**
```swift
public struct EditToolData {
    public let filePath: String
    public let oldString: String
    public let newString: String
    public let replaceAll: Bool
}
```

**WriteToolData**
```swift
public struct WriteToolData {
    public let filePath: String
    public let content: String
}
```

**ReadToolData**
```swift
public struct ReadToolData {
    public let filePath: String
}
```

**BashToolData**
```swift
public struct BashToolData {
    public let command: String
    public let description: String
}
```

**GrepToolData**
```swift
public struct GrepToolData {
    public let pattern: String
    public let path: String
}
```

**GlobToolData**
```swift
public struct GlobToolData {
    public let pattern: String
    public let path: String
}
```

**AgentToolData**
```swift
public struct AgentToolData {
    public let description: String
    public let prompt: String
    public let subagentType: String
}
```

**TaskCreateToolData**
```swift
public struct TaskCreateToolData {
    public let subject: String
    public let description: String
    public let activeForm: String
}
```

**TaskUpdateToolData**
```swift
public struct TaskUpdateToolData {
    public let taskId: String
    public let status: String
}
```

**TodoWriteToolData**
```swift
public struct TodoWriteToolData {
    public let todos: [TodoItem]

    public struct TodoItem {
        public let content: String
        public let status: String
    }
}
```

**SkillToolData**
```swift
public struct SkillToolData {
    public let skill: String
    public let args: String
}
```

**WebSearchToolData**
```swift
public struct WebSearchToolData {
    public let query: String
}
```

**WebFetchToolData**
```swift
public struct WebFetchToolData {
    public let url: String
    public let prompt: String
}
```

**AskUserQuestionToolData**
```swift
public struct AskUserQuestionToolData {
    public let questions: [Question]

    public struct Question {
        public let question: String
        public let header: String
        public let options: [Option]
        public let multiSelect: Bool
    }

    public struct Option {
        public let label: String
        public let description: String
    }
}
```

**ExitPlanModeToolData**
```swift
public struct ExitPlanModeToolData {
    public let plan: String
}
```

**`.other(raw:)`** -- catches all unknown tool names. The `input` dictionary is flattened to `[String: String]` by extracting string values directly, converting `NSNumber` to `stringValue`, and joining arrays of dictionaries into newline-separated key-value strings.

---

## ToolData.summary -- Computed Property for Chip Label

`ToolData.summary` returns a short display string used as the secondary label in the tool chip:

| Case | Summary value |
|------|--------------|
| `.edit` | `filePath` |
| `.write` | `filePath` |
| `.read` | `filePath` |
| `.bash` | `description` if non-empty, else first 80 chars of trimmed `command` |
| `.grep` | `pattern` |
| `.glob` | `pattern` |
| `.agent` | First 80 chars of `description` |
| `.taskCreate` | `subject` |
| `.taskUpdate` | `"#{taskId} -> {status}"` |
| `.todoWrite` | `"{count} items"` |
| `.skill` | `skill` name |
| `.webSearch` | `query` |
| `.webFetch` | `url` |
| `.askUserQuestion` | First question's text, or "Question" |
| `.exitPlanMode` | `"Plan ready for review"` |
| `.other` | First sorted key's value, truncated to 80 chars |

---

## ToolData.hasDetail -- Expandable Tool Check

`ToolData.hasDetail` returns `false` for `.read`, `.skill`, and `.taskUpdate`. All other cases return `true`, meaning they render an expandable detail section when the user clicks the disclosure triangle.

---

## ToolData.needsPrompt -- Interactive Prompt Check

`ToolData.needsPrompt` returns `true` for tools that require user interaction:

```swift
public var needsPrompt: Bool {
    switch self {
    case .bash, .edit, .write, .askUserQuestion, .exitPlanMode: return true
    default: return false
    }
}
```

Used by:
1. `LogParser` to track `promptToolIDs` (set of tool_use IDs that need prompts)
2. `pendingPrompt` computed property to find unresolved prompts

---

## LogParser.parseMessages -- JSONL Parsing

`LogParser.parseMessages(at:)` reads a JSONL file from disk and returns an array of `LogMessage` values.

### Parsing Strategy

1. **File read:** `Data(contentsOf: url)` then `String(data:encoding: .utf8)`.
2. **Line-by-line parsing:** Each line is parsed with `JSONSerialization.jsonObject(with:)` -- **not** `Decodable`. This allows flexible handling of varying JSONL schemas.
3. **Type dispatch:** The `type` field determines whether the line is `"user"` or `"assistant"`.
4. **promptToolIDs tracking:** A `Set<String>` tracks tool_use IDs that have `needsPrompt == true`, enabling accurate response detection in subsequent user messages.

### User Message Parsing

User messages extract:
- **Text content**: from `content` array's `"text"` items, or from `message.content` as a plain string
- **Tool result IDs**: from `"tool_result"` items, collecting `tool_use_id` values
- **Tool responses**: from the top-level `toolUseResult` field, mapped to `ToolResponse` based on structure
- **Synthesized display text**: "Allowed", answer values, "Plan approved", or rejection feedback appended to `textContent`

### Assistant Message Parsing

Content array items are classified by `type`:
- `"text"` items -> `textContent`
- `"thinking"` items -> joined with `"\n\n"` into `thinking` field
- `"tool_use"` items -> parsed into `LogToolCall` via `parseToolData(name:input:)`; if `needsPrompt`, the tool_use ID is added to `promptToolIDs`

### Streaming Deduplication (Message Merge)

Claude Code streams assistant messages incrementally. Multiple JSONL entries may share the same `message.id`, each containing a subset of the tool calls. The parser merges these:

Key merge rules:
- **Tool calls:** unioned by `tool_use` id -- if a tool call id already exists in the previous entry, it is kept; new ids are appended.
- **Text content:** the later entry's text replaces the earlier entry's text (unless the later entry has no text).
- **Model, timestamp, thinking:** the later entry's value is used if non-nil; otherwise the earlier value is preserved.
- **Position in result array:** the merged message replaces the original at its index, preserving conversation order.

### Tool Data Parsing

`parseToolData(name:input:)` is a private static method that switches on the tool name and extracts fields from the `input` dictionary:

| JSONL tool name | ToolData case | Key fields extracted |
|----------------|---------------|---------------------|
| `"Edit"` | `.edit` | `file_path`, `old_string`, `new_string`, `replace_all` (Bool) |
| `"Write"` | `.write` | `file_path`, `content` |
| `"Read"` | `.read` | `file_path` |
| `"Bash"` | `.bash` | `command`, `description` |
| `"Grep"` | `.grep` | `pattern`, `path` |
| `"Glob"` | `.glob` | `pattern`, `path` |
| `"Agent"` | `.agent` | `description`, `prompt`, `subagent_type` |
| `"TaskCreate"` | `.taskCreate` | `subject`, `description`, `activeForm` |
| `"TaskUpdate"` | `.taskUpdate` | `taskId`, `status` |
| `"TodoWrite"` | `.todoWrite` | `todos` array of `{content, status}` |
| `"Skill"` | `.skill` | `skill`, `args` |
| `"WebSearch"` | `.webSearch` | `query` |
| `"WebFetch"` | `.webFetch` | `url`, `prompt` |
| `"AskUserQuestion"` | `.askUserQuestion` | `questions` array with `question`, `header`, `options` (label, description), `multiSelect` |
| `"ExitPlanMode"` | `.exitPlanMode` | `plan` |
| (unknown) | `.other` | All string/number/array values flattened to `[String: String]` |

Timestamps are parsed using an `ISO8601DateFormatter` configured with `.withInternetDateTime` and `.withFractionalSeconds`.

---

## LogParser.resolveURL -- JSONL Path Resolution

`LogParser.resolveURL(agent:target:)` builds the JSONL file path from an `AgentInfo` and a `LogTarget`:

Path structure:
- **Parent:** `~/.claude/projects/{encoded_path}/{sessionID}.jsonl`
- **Subagent:** `~/.claude/projects/{encoded_path}/{sessionID}/subagents/{agentID}.jsonl`

`LogTarget` is an enum with two cases: `.parent` and `.subagent(SubagentInfo)`.

---

## Pending Prompt Detection

The `pendingPrompt` computed property finds the last unresolved interactive tool call:

```swift
private var pendingPrompt: LogToolCall? {
    guard canSendInput else { return nil }
    let resolvedIDs = Set(messages.flatMap(\.toolResultIDs))
    for msg in messages.reversed() where msg.role == .assistant {
        for tc in msg.toolCalls.reversed() {
            if !resolvedIDs.contains(tc.id) && tc.data.needsPrompt {
                return tc
            }
        }
    }
    return nil
}
```

Logic:
1. Returns nil if input is not available (not a parent session, or no bridge)
2. Collects all resolved tool_use IDs from `toolResultIDs` across all messages
3. Scans messages in reverse order (most recent first)
4. For each assistant message, checks tool calls in reverse
5. If a tool_use ID is not resolved AND `needsPrompt == true`, returns it as pending

---

## Prompt Modal UI

### Prompt Type Dispatch

```swift
@ViewBuilder
private func promptView(_ tc: LogToolCall) -> some View {
    switch tc.data {
    case .askUserQuestion(let d): askUserQuestionPrompt(d, toolID: tc.id)
    case .exitPlanMode:           planApprovalPrompt()
    case .bash, .edit, .write:    permissionPrompt(tc)
    default:                      permissionPrompt(tc)  // generic fallback
    }
}
```

### Permission Prompt

For Bash, Edit, Write, and any other tool that `needsPrompt`:

- **Header**: Shield icon (orange) + tool name (`.caption` medium) + summary (`.caption` secondary, truncated)
- **Buttons**: "Allow" (green tint) and "Deny" (red tint), `.borderedProminent` style, small control size
- **Allow action**: `bridge?.sendRaw("\r")` -- Enter key
- **Deny action**: `bridge?.sendRaw("\u{1b}")` -- Escape key
- **Background**: orange at 0.08 opacity, rounded rectangle

### AskUserQuestion Prompt

- **Header**: optional header text (`.caption2` semibold secondary)
- **Question**: question text (`.caption` medium)
- **Options**: radio-button list with circle fill/empty icons, label and optional description
- **Selection state**: `@State selectedOptionIdx` (default 0), `@State promptToolID` tracks which prompt the selection belongs to
- **Stale detection**: if `promptToolID != tc.id`, the selection is treated as 0 (reset for new prompts)
- **Submit action**:
  ```swift
  for _ in 0..<idx {
      bridge?.sendRaw("\u{1b}[B")  // down arrow, separate write per key
  }
  bridge?.sendRaw("\r")  // Enter to confirm
  ```
- **Background**: blue at 0.08 opacity, rounded rectangle

### ExitPlanMode Prompt

- **Header**: doc.text icon (blue) + "Plan ready for review" (`.caption` medium)
- **Buttons**: "Approve" (green tint) and "Reject" (red tint)
- **Approve**: `bridge?.sendRaw("\r")` -- Enter
- **Reject**: `bridge?.sendRaw("\u{1b}")` -- Escape
- **Background**: purple at 0.08 opacity, rounded rectangle

### Modal Overlay

All prompts are displayed as a modal overlay on the log content:

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

The input field is hidden when a modal prompt is active.

---

## Input Field

### Visibility

Shown only when `canSendInput && pendingPrompt == nil`:
- Must be a parent agent target (not subagent)
- Must have an active TTY bridge
- No pending interactive prompt

### Design

```swift
private var inputField: some View {
    HStack(alignment: .bottom, spacing: 8) {
        ZStack(alignment: .topLeading) {
            // Invisible text for auto-sizing
            Text(inputText.isEmpty ? " " : inputText)
                .font(.system(size: 12)).padding(8).opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $inputText)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden).padding(4)

            // Placeholder
            if inputText.isEmpty {
                Text("Type a message...")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 8).padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 36, maxHeight: 120)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))

        Button { sendInput() } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(canSendInput && !inputText.isEmpty ? .blue : .gray)
        }
        .buttonStyle(.plain)
        .disabled(!canSendInput || inputText.isEmpty)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
```

- Auto-expanding `TextEditor` with invisible `Text` for height measurement
- Min height: 36pt, max height: 120pt
- Placeholder: "Type a message..." in `.tertiary`
- Send button: `arrow.up.circle.fill` at 24pt
- Keyboard shortcut: Cmd+Return
- Disabled when `canSendInput` is false or input is empty

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

## Log Header

The header bar contains:

```
[< Back]    [dot] Title    [tasks] [stop] [open]
```

| Element | Condition | Description |
|---------|-----------|-------------|
| Back button | Always | Chevron left + "Back", blue, adaptive font |
| Connection dot | Always | 6pt circle, green if `canSendInput`, grey otherwise |
| Title | Always | Agent display name (parent) or subagent model (subagent), adaptive font |
| Task toggle | `!taskList.isEmpty` | Checklist icon, toggles task panel visibility |
| Stop button | `canSendInput` | Red stop.circle.fill, detaches bridge and removes session |
| Open in editor | Always | arrow.up.right.square, opens JSONL file in default editor via `NSWorkspace` |

### Stop Session Action

```swift
bridge?.detach()
sessionManager?.sessions.removeValue(forKey: agent.pid)
onStop?()
```

---

## Tool Rendering -- Per-Tool Custom Views

Each expandable tool has a custom renderer in `toolExpandedContent(_:)`:

| Tool | Renderer | Visual |
|------|----------|--------|
| **Edit** | `editDiffView` | File path in monospace/tertiary. Old lines prefixed with `"- "` in red with red background. New lines prefixed with `"+ "` in green with green background. |
| **Write** | `writeDiffView` | File path in monospace/tertiary. All lines prefixed with `"+ "` in green with green background. |
| **Bash** | `monoText` | Command text in monospace, secondary color. |
| **Grep** | `monoText` | `"pattern: {pattern}"` and optionally `"\npath: {path}"`. |
| **Glob** | `monoText` | `"pattern: {pattern}"` and optionally `"\npath: {path}"`. |
| **Agent** | Custom VStack | Subagent type label (if non-empty), then prompt in `monoText`. |
| **TaskCreate** | Custom VStack | Description in secondary, activeForm in monospace/tertiary. |
| **TodoWrite** | `todoChecklist` | Each item shows a status icon and content. Icons: `checkmark.circle.fill` (completed, green), `circle.dotted.circle` (in_progress, orange), `circle` (pending, secondary). Completed items are strikethrough and secondary. |
| **WebSearch** | `monoText` | Query text. |
| **WebFetch** | `monoText` | URL, then prompt on next line if non-empty. |
| **AskUserQuestion** | Custom VStack | Questions with headers, question text, and numbered option labels. |
| **ExitPlanMode** | `monoText` | First 500 chars of plan text. |
| **Other** | `monoText` | Sorted key-value pairs, one per line. |
| **Read, Skill, TaskUpdate** | N/A | Non-expandable (`hasDetail == false`), rendered as flat chip only. |

Non-expandable tools show as a flat chip with a right chevron icon (`chevron.right`) and the tool name + summary.

---

## Task Panel

### TaskListItem Struct

```swift
struct TaskListItem: Identifiable {
    let id: String
    var content: String
    var status: String
    var activeForm: String
}
```

### Task State Reconstruction

The `taskList` computed property replays all tool calls across all messages in order, reconstructing the current task state:

1. **TodoWrite:** Replaces the entire task list. Each `TodoItem` becomes a `TaskListItem` with id `"todo-{index}"`.
2. **TaskCreate:** Appends a new task with an auto-incrementing numeric id, status `"pending"`, and the `activeForm` from the tool data.
3. **TaskUpdate:** Finds the task by `taskId` and updates its `status` if the new status is non-empty.

### Layout Modes

**Window mode** (`stickyHeader == true`): The task panel renders as a sidebar to the right of the log content, separated by a `Divider`, with a fixed width of 200 points. The log content and task panel are side-by-side in an `HStack`.

**Popover mode** (`stickyHeader == false`): The task panel renders inline above the message list, inside the scrollable content area, separated by `Divider`s above and below.

### Toggle Button

A checklist toggle button appears in the header bar when `taskList` is non-empty:
- Icon: `checklist.checked` (when shown, blue) or `checklist` (when hidden, secondary)
- State: controlled by `@State private var showTaskPanel = true` (default: visible)

### Progress Bar and Summary

The task panel header shows:
- A checklist icon and "Tasks" label
- A `"{completed}/{total}"` counter
- A green progress bar (`GeometryReader`-based) showing `completed/total` fill ratio

Task items use icons/colors:
- `checkmark.circle.fill` (completed, green)
- `circle.dotted.circle` (in_progress, orange)
- `xmark.circle` (deleted, red)
- `circle` (pending, secondary)

Completed items are strikethrough and secondary-colored. Each item is limited to 2 lines.

---

## ExpandableSection

A generic wrapper around `DisclosureGroup` that accepts an initial expanded state from settings. Used for:
- **Thinking blocks:** initial state from `settings.expandThinking`, tint color `.purple.opacity(0.8)`
- **Tool call chips:** initial state from `settings.expandTools`, tint color `.blue.opacity(0.7)`
- **Long user messages** (>120 chars): initial state `false`, tint color `.green.opacity(0.7)`

The `@State` initialization via `State(initialValue:)` means the expanded state is set once when the view is created and persists independently of the settings value thereafter.

---

## Empty Bubble Filtering

Messages are filtered before rendering to exclude empty bubbles:

```swift
ForEach(messages.filter { !$0.textContent.isEmpty || !$0.toolCalls.isEmpty || $0.thinking != nil }) { msg in
    messageBubble(msg)
}
```

A message must have at least one of: text content, tool calls, or thinking content to be displayed.

---

## Polling and Data Loading

### Dual-Trigger Loading

```swift
.task {
    // Set up TTY activity trigger if we own this session
    if let bridge {
        bridge.onActivity = {
            Task { await loadMessages() }
        }
    }

    await loadMessages()
    isLoading = false
    // Fallback polling (also serves non-owned sessions and subagent logs)
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        await loadMessages()
    }
}
```

Two triggers for loading:
1. **TTY activity callback**: For app-spawned sessions, `bridge.onActivity` is set to trigger `loadMessages()` whenever the PTY has output (Claude is responding). This provides near-instant updates.
2. **Fallback 2-second polling**: Runs for all sessions (both owned and external). Also handles subagent logs that don't have TTY bridges.

### Mtime Cache

`loadMessages()` uses `Task.detached(priority: .utility)` for file I/O with an mtime-based cache:

- **Mtime cache:** `@State private var lastMtime: Date?` stores the last known modification date. If the file mtime matches the cached value, parsing is skipped entirely.
- **Detached task:** File I/O runs on a `.utility` priority detached task to avoid blocking the main thread.
- **State update:** `messages` is only replaced when `msgs` is non-empty, preventing flicker on cache-hit polls.
- **Cancellation:** SwiftUI cancels the `.task` automatically when the view disappears.

---

## Layout

### Sticky Header Mode (Window)

When `stickyHeader == true`:
- The header is rendered **outside** the scroll view, pinned at the top
- Vertical padding of 8pt with a `Divider` below
- Task panel (when visible) renders as a sidebar alongside log content (200pt wide)
- `scrollHeight` returns `nil` -- the scroll view fills all available space

### Popover Mode

When `stickyHeader == false`:
- The header is rendered **inside** the content area
- Task panel (when visible) renders inline above messages
- `scrollHeight` is computed: `CGFloat(settings.maxVisibleLogMessages) * 60`

### Message Bubbles

Each message renders as a `VStack` with:
1. **Role header:** Colored circle (green for user, blue for assistant), role label, and timestamp
2. **Thinking block** (if present): Purple-tinted `ExpandableSection` with brain icon
3. **Content bubble:**
   - Long user messages (>120 chars): collapsible with first 100 chars preview, green background
   - Normal messages: text blocks followed by tool call chips, colored background (green for user, blue for assistant at 0.08 opacity)

Role label for assistant messages resolves model ID via `ClaudeModel.from(modelID:).displayName`, falling back to `"Assistant"`.

### Scroll Behavior

Uses `ScrollViewReader` for auto-scroll:
- On initial appearance: scrolls to last message without animation
- On `messages.count` change: scrolls to last message with 0.2-second ease-out animation

### Font Sizes

| Element | Font |
|---------|------|
| Navigation buttons | `.body` (window) / `.caption` (popover) |
| Title | `.title3` (window) / `.headline` (popover) |
| Role label | `.system(size: 10, weight: .medium)` |
| Timestamp | `.system(size: 9)` |
| Thinking text | `.system(size: 10)` |
| Message text | `.system(size: 11)` |
| Tool name | `.system(size: 10, weight: .medium)` |
| Tool summary | `.system(size: 10)` |
| Monospace tool content | `.system(size: 10, design: .monospaced)` |
| Edit diff file path | `.system(size: 9, design: .monospaced)` |
| Edit diff lines | `.system(size: 10, design: .monospaced)` |
| Input field text | `.system(size: 12)` |
| Prompt text | `.caption` |
| Prompt buttons | `.caption` medium |
