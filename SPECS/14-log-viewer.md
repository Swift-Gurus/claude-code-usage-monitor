# Log Viewer Specification

## Overview

`LogViewerView` displays a Claude Code JSONL conversation log as a chat-style message list. It parses the raw JSONL file on disk, renders user and assistant messages as colored bubbles, shows tool calls as expandable chips with per-tool custom renderers, and supports a task panel that reconstructs task state from tool call history. The view supports both popover mode (inline) and window mode (sticky header with sidebar task panel).

The data layer is split across two files:
- `Sources/LogMessage.swift` — data models (`LogMessage`, `LogToolCall`, `ToolData`, all tool-specific structs) and the `LogParser` (JSONL parsing, tool data extraction, URL resolution)
- `Sources/LogViewerView.swift` — SwiftUI view (`LogViewerView`), task panel, tool rendering, `ExpandableSection`, polling

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
| `textContent` | `[String]` | Array of text strings from `"text"` content blocks. User messages may have a single string from `message.content` (when content is a plain string, not an array). |
| `toolCalls` | `[LogToolCall]` | Array of tool calls extracted from `"tool_use"` content blocks. |

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

## ToolData Enum — All 14 Cases

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

**`.other(raw:)`** — catches all unknown tool names. The `input` dictionary is flattened to `[String: String]` by extracting string values directly, converting `NSNumber` to `stringValue`, and joining arrays of dictionaries into newline-separated key-value strings.

---

## ToolData.summary — Computed Property for Chip Label

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
| `.other` | First sorted key's value, truncated to 80 chars |

---

## ToolData.hasDetail — Expandable Tool Check

`ToolData.hasDetail` returns `false` for `.read`, `.skill`, and `.taskUpdate`. All other cases return `true`, meaning they render an expandable detail section when the user clicks the disclosure triangle.

```swift
public var hasDetail: Bool {
    switch self {
    case .read, .skill, .taskUpdate: return false
    default: return true
    }
}
```

---

## LogParser.parseMessages — JSONL Parsing

`LogParser.parseMessages(at:)` reads a JSONL file from disk and returns an array of `LogMessage` values.

### Parsing Strategy

1. **File read:** `Data(contentsOf: url)` then `String(data:encoding: .utf8)`.
2. **Line-by-line parsing:** Each line is parsed with `JSONSerialization.jsonObject(with:)` — **not** `Decodable`. This allows flexible handling of varying JSONL schemas.
3. **Type dispatch:** The `type` field determines whether the line is `"user"` or `"assistant"`.
4. **User messages:** Text content is extracted either from `message.content` as a plain string (simple user messages) or from the `content` array's `"text"` items.
5. **Assistant messages:** Content array items are classified by `type`:
   - `"text"` items are collected into `textContent`
   - `"thinking"` items are collected and joined with `"\n\n"` into the `thinking` field
   - `"tool_use"` items are parsed into `LogToolCall` via `parseToolData(name:input:)`

### Streaming Deduplication (Message Merge)

Claude Code streams assistant messages incrementally. Multiple JSONL entries may share the same `message.id`, each containing a subset of the tool calls. The parser merges these:

```swift
if let existing = assistantByID[msgID] {
    let prev = existing.msg
    // Merge tool calls: union by tool_use id
    var mergedTools = prev.toolCalls
    let existingIds = Set(mergedTools.map(\.id))
    for tc in logMsg.toolCalls where !existingIds.contains(tc.id) {
        mergedTools.append(tc)
    }
    let merged = LogMessage(
        id: msgID, role: .assistant,
        model: logMsg.model ?? prev.model,
        timestamp: logMsg.timestamp ?? prev.timestamp,
        thinking: logMsg.thinking ?? prev.thinking,
        textContent: logMsg.textContent.isEmpty ? prev.textContent : logMsg.textContent,
        toolCalls: mergedTools
    )
    result[existing.index] = merged
    assistantByID[msgID] = (existing.index, merged)
}
```

Key merge rules:
- **Tool calls:** unioned by `tool_use` id — if a tool call id already exists in the previous entry, it is kept; new ids are appended.
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
| (unknown) | `.other` | All string/number/array values flattened to `[String: String]` |

Timestamps are parsed using an `ISO8601DateFormatter` configured with `.withInternetDateTime` and `.withFractionalSeconds`.

---

## LogParser.resolveURL — JSONL Path Resolution

`LogParser.resolveURL(agent:target:)` builds the JSONL file path from an `AgentInfo` and a `LogTarget`:

```swift
public static func resolveURL(agent: AgentInfo, target: LogTarget) -> URL {
    let projectsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")
    let encoded = SessionScanner.encodeProjectPath(agent.workingDir)

    switch target {
    case .parent:
        return projectsDir
            .appendingPathComponent(encoded)
            .appendingPathComponent("\(agent.sessionID).jsonl")
    case .subagent(let sub):
        return projectsDir
            .appendingPathComponent(encoded)
            .appendingPathComponent(agent.sessionID)
            .appendingPathComponent("subagents")
            .appendingPathComponent("\(sub.agentID).jsonl")
    }
}
```

Path structure:
- **Parent:** `~/.claude/projects/{encoded_path}/{sessionID}.jsonl`
- **Subagent:** `~/.claude/projects/{encoded_path}/{sessionID}/subagents/{agentID}.jsonl`

`LogTarget` is an enum with two cases: `.parent` and `.subagent(SubagentInfo)`.

---

## Tool Rendering — Per-Tool Custom Views

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

Task items use the same icon/color system as `todoChecklist`:
- `checkmark.circle.fill` (completed, green)
- `circle.dotted.circle` (in_progress, orange)
- `xmark.circle` (deleted, red)
- `circle` (pending, secondary)

Completed items are strikethrough and secondary-colored. Each item is limited to 2 lines.

---

## ExpandableSection

```swift
private struct ExpandableSection<Content: View, Label: View>: View {
    @State private var isExpanded: Bool
    let tintColor: Color
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label

    init(expanded: Bool, tintColor: Color,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder label: @escaping () -> Label) {
        self._isExpanded = State(initialValue: expanded)
        self.tintColor = tintColor
        self.content = content
        self.label = label
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content()
        } label: {
            label()
        }
        .tint(tintColor)
    }
}
```

A generic wrapper around `DisclosureGroup` that accepts an initial expanded state from settings. Used for:
- **Thinking blocks:** initial state from `settings.expandThinking`, tint color `.purple.opacity(0.8)`
- **Tool call chips:** initial state from `settings.expandTools`, tint color `.blue.opacity(0.7)`
- **Long user messages** (>120 chars): initial state `false`, tint color `.green.opacity(0.7)`

The `@State` initialization via `State(initialValue:)` means the expanded state is set once when the view is created and persists independently of the settings value thereafter (user can toggle each section independently).

---

## Message Deduplication

Streaming assistant entries are merged by `message.id`:
- An `assistantByID: [String: (index: Int, msg: LogMessage)]` dictionary tracks seen assistant message IDs.
- When a duplicate `message.id` is encountered, the new entry is merged into the existing one at its original array index.
- Tool calls are unioned by their `id` field — existing tool call ids are kept, new ones are appended.
- User messages are never deduplicated — each user JSONL entry produces a new `LogMessage` with a unique `"user-{index}"` id.

---

## Polling — loadMessages Every 2s with Mtime Cache

`LogViewerView` polls the JSONL file for changes using a `.task` modifier:

```swift
.task {
    await loadMessages()
    isLoading = false
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        await loadMessages()
    }
}
```

`loadMessages()` uses `Task.detached(priority: .utility)` for file I/O with an mtime-based cache:

```swift
private func loadMessages() async {
    let url = fileURL
    let cached = lastMtime
    let (msgs, mtime): ([LogMessage], Date?) = await Task.detached(priority: .utility) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = attrs?[.modificationDate] as? Date
        if let cached, let mtime, cached == mtime {
            return ([], mtime)  // unchanged — skip parsing
        }
        return (LogParser.parseMessages(at: url), mtime)
    }.value
    if let mtime { lastMtime = mtime }
    if !msgs.isEmpty { messages = msgs }
}
```

- **Mtime cache:** `@State private var lastMtime: Date?` stores the last known modification date. If the file mtime matches the cached value, parsing is skipped entirely and an empty array is returned.
- **Detached task:** File I/O runs on a `.utility` priority detached task to avoid blocking the main thread.
- **State update:** `messages` is only replaced when `msgs` is non-empty, preventing flicker on cache-hit polls.
- **Cancellation:** SwiftUI cancels the `.task` automatically when the view disappears. `Task.sleep` throws on cancellation (caught by `try?`), exiting the loop.

---

## Layout

### Sticky Header Mode (Window)

When `stickyHeader == true` (window display mode):
- The header (`logHeader`) is rendered **outside** the scroll view, in a fixed position at the top.
- The header has vertical padding of 8 points and a `Divider` below it.
- The task panel (when visible) renders as a sidebar alongside the log content.
- `scrollHeight` returns `nil` — the scroll view fills all available space.

### Popover Mode

When `stickyHeader == false` (popover display mode):
- The header is rendered **inside** the content area (inside `logContent`).
- The task panel (when visible) renders inline above the messages.
- `scrollHeight` is computed from the `maxVisibleLogMessages` setting: `CGFloat(settings.maxVisibleLogMessages) * 60`.

### Message Bubbles

Each message renders as a `VStack` with:
1. **Role header:** A colored circle (green for user, blue for assistant), role label, and timestamp.
2. **Thinking block** (if present): A purple-tinted `ExpandableSection` with brain icon.
3. **Content bubble:**
   - Long user messages (>120 chars): collapsible with first 100 chars preview, green background.
   - Normal messages: text blocks followed by tool call chips, colored background (green for user, blue for assistant at 0.08 opacity).

The role label for assistant messages resolves the model ID to a display name via `ClaudeModel.from(modelID:).displayName`, falling back to `"Assistant"` if the model is empty.

### Scroll Behavior

The scroll view uses `ScrollViewReader` to auto-scroll to the last message:
- On initial appearance: scrolls to the last message without animation.
- On `messages.count` change: scrolls to the last message with a 0.2-second ease-out animation.

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
