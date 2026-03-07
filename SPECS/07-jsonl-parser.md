# JSONL Parser Specification

## Overview

`JSONLParser.swift` parses Claude Code's JSONL conversation files to extract token usage, model information, cost, line counts, and subagent data. It is used exclusively by the Commander integration; CLI sessions get cost data directly from Claude Code's statusline JSON.

The parser is implemented as a pure `enum` (no instance state) with five public entry points: `parseSession`, `parseSubagents`, `parseSubagentDetails`, `parseParentTools`, and `parseSubagentMeta`.

---

## Input Format

Claude Code's JSONL files (`~/.claude/projects/{encoded_path}/{sessionID}.jsonl`) use the "stream-json" format. Each line is a self-contained JSON object. Entries come in two flavors:

**User/system entries** (type `"user"`):
```json
{"type":"user","message":{...},"timestamp":"2026-03-06T10:00:00.000Z","sessionId":"abc123","cwd":"/Users/alice/proj"}
```

**Assistant entries** (type `"assistant"`):
```json
{"type":"assistant","message":{"id":"msg_01abc","model":"claude-sonnet-4-5","usage":{"input_tokens":1500,"output_tokens":250,"cache_creation_input_tokens":0,"cache_read_input_tokens":8000},"content":[...],"stop_reason":"end_turn"},"timestamp":"2026-03-06T10:00:05.123Z"}
```

Assistant entries for the same `message.id` appear multiple times during streaming — streaming partials followed by a final entry with `stop_reason`. Only the final entry has complete token counts.

---

## Message Deduplication

The parser uses a `[String: MsgUsage]` dictionary keyed by `message.id`:

```swift
// Overwrite — last entry per message ID wins (the final with stop_reason)
usageByMsgID[msgID] = MsgUsage(input: inp, output: out, cacheCreation: cc, cacheRead: cr)
```

Because the JSONL lines are read in order and the final message entry comes last, this simple overwrite pattern correctly retains only the final token counts. After processing all lines, `usageByMsgID` contains exactly one entry per message with complete data.

---

## Token Extraction

For each deduplicated message, four token fields are extracted:

| Field | JSON key | Description |
|-------|----------|-------------|
| `input_tokens` | `message.usage.input_tokens` | Non-cached input tokens |
| `output_tokens` | `message.usage.output_tokens` | Generated output tokens |
| `cache_creation_input_tokens` | `message.usage.cache_creation_input_tokens` | Tokens written to cache |
| `cache_read_input_tokens` | `message.usage.cache_read_input_tokens` | Tokens read from cache |

All fields default to `0` if absent (optional Int?).

Total input for context % calculation:
```swift
totalIn = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
```

---

## Model Detection

`modelID` is updated to the last non-empty `message.model` value seen in any assistant entry:

```swift
if let m = message.model, !m.isEmpty { modelID = m }
```

This means the model reported is the model used in the final API call of the session (in case of model switching, which is not typical for Commander sessions).

The raw `modelID` (e.g. `"claude-sonnet-4-5-20250102"`) is resolved to a `ClaudeModel` via `ClaudeModel.from(modelID:)`.

---

## Cost Calculation

Cost is computed via `PriceCalculator`:

```swift
cost = inputTokens * inputPerMTok / 1_000_000
     + outputTokens * outputPerMTok / 1_000_000
     + cacheCreationTokens * cacheWritePerMTok / 1_000_000
     + cacheReadTokens * cacheReadPerMTok / 1_000_000
```

Subagent costs are summed and added to the session total:
```swift
costUSD = PriceCalculator.cost(for: usage, model: resolved) + subagentCost
```

Where `subagentCost = parseSubagents(sessionID:workingDir:).values.reduce(0) { $0 + $1.cost }`.

---

## Context Percentage

```swift
contextPct = min(100, Int(Double(lastInputTokens) / Double(resolved.contextWindowSize) * 100))
```

- `lastInputTokens`: the `totalIn` from the last assistant message processed (not the maximum)
- `contextWindowSize`: from the resolved `ClaudeModel` enum (200K for Sonnet/Haiku, 1M for Opus)
- Clamped to 100 to prevent overflow display

---

## Lines Added/Removed

Lines are counted by inspecting `tool_use` content items in assistant messages. The parser looks for `"Edit"` and `"Write"` tool calls:

### Edit Tool

```swift
case "Edit":
    let oldLines = (toolCall.input.old_string ?? "").components(separatedBy: "\n").count
    let newLines = (toolCall.input.new_string ?? "").components(separatedBy: "\n").count
    let delta = newLines - oldLines
    if delta > 0 { linesAdded += delta } else { linesRemoved += -delta }
```

- `old_string`: the text being replaced
- `new_string`: the replacement text
- Line counts use `components(separatedBy: "\n")` — a string with no newlines returns count 1
- Net delta: if new has more lines, adds; if old has more, removes

### Write Tool

```swift
case "Write":
    linesAdded += (toolCall.input.content ?? "").components(separatedBy: "\n").count
```

- `content`: the full file content being written
- All lines are counted as added (Write always creates/replaces a file)

### Limitation

Lines are processed from both streaming partial entries and final entries. However, tool_use inputs only appear in complete assistant messages, and the parser processes all lines (not only deduplicated ones) for line counting. This means line counting could theoretically double-count if a tool_use appears in both a streaming partial and the final message — but in practice, tool_use content items appear only in the final assistant message.

---

## Subagent Scanning

### parseSubagents(in:) — Per-Model Aggregation

Processes all `.jsonl` files in a subagents directory. Returns `[String: SourceModelStats]` where keys are display model names.

For each subagent file:
1. Same streaming deduplication (last entry per message ID)
2. Per-message cost calculated and aggregated by `ClaudeModel.displayName`
3. Lines counted from Edit/Write tool calls, attributed to the dominant model (first non-empty model seen)
4. `dominantModel` = `entry.message.model` of the first assistant entry

The result is a flat map: `"Opus 4.6" → SourceModelStats(cost: X, linesAdded: Y, linesRemoved: Z)`.

### parseSubagents(sessionID:workingDir:) — Convenience Overload

Builds the subagents directory path from session ID and working dir, then calls `parseSubagents(in:)`. Used during `parseSession` to add subagent costs to the total.

### parseSubagentMeta(sessionID:workingDir:) — Subagent Naming

```swift
public static func parseSubagentMeta(sessionID: String, workingDir: String) -> [String: SubagentMeta]
```

Parses the parent session's JSONL file to build a map of `agentID -> SubagentMeta`, linking Agent tool_use calls to their corresponding subagent IDs.

**SubagentMeta struct:**
```swift
public struct SubagentMeta {
    public let description: String    // from Agent tool_use input.description
    public let subagentType: String   // from Agent tool_use input.subagent_type
}
```

**Algorithm (three-pass over JSONL lines using raw JSON parsing):**

1. **Pass 1**: Scan assistant entries for `tool_use` items with `name == "Agent"`. Extract the `id` (tool_use ID), `input.description`, and `input.subagent_type` from each. Store in `agentCalls: [String: AgentCall]` keyed by tool_use ID. Uses `JSONSerialization` (not `Decodable`) because the tool_use `id` field is not part of the `ToolCall` decodable struct.

2. **Pass 2**: Scan user entries for `tool_result` items whose `tool_use_id` matches a known Agent call. Extract the `agentId` from the tool_result content text, which follows the format `"agentId: abc123def456 (for resuming..."`. The agent ID is extracted as a hex string prefix after `"agentId: "` using `$0.isHexDigit`.

3. **Result**: Maps `"agent-{hexID}"` to `SubagentMeta(description:subagentType:)`. The `"agent-"` prefix matches the filename convention used for subagent JSONL files.

**Return value:** `[String: SubagentMeta]` where keys are subagent IDs (e.g. `"agent-abc123"`) matching JSONL filenames. Returns `[:]` if the parent file cannot be read.

**Usage:** Called by `AgentTracker.writeSubagentFiles` and passed as the `meta` parameter to `parseSubagentDetails(in:meta:)`.

---

### parseSubagentDetails(in:meta:) — Per-File Detail

```swift
public static func parseSubagentDetails(in dir: URL, meta: [String: SubagentMeta] = [:]) -> [SubagentInfo]
```

Returns `[SubagentInfo]`, one per JSONL file (one per subagent invocation), sorted by cost descending.

The optional `meta` parameter provides description and subagentType from the parent session's Agent tool calls (via `parseSubagentMeta`). If not provided, defaults to empty.

For each file:
- Same deduplication and line counting
- **Dominant model**: the most frequently occurring model across all deduplicated messages (mode, not last-seen)
  ```swift
  let dominantModel = modelCounts.max(by: { $0.value < $1.value })?.key ?? ""
  ```
- **lastInputTokens**: the total input tokens (`input + cacheCreation + cacheRead`) of the last assistant message
- **cost**: total across all deduplicated messages
- **agentID**: stem of the JSONL filename
- **toolCounts**: `[String: Int]` of all `tool_use` entries counted by name across all assistant messages (populated alongside line counting; same pass)
- **description**: `meta[agentID]?.description ?? ""`
- **subagentType**: `meta[agentID]?.subagentType ?? ""`
- **lastModified**: file's `contentModificationDate` as `timeIntervalSince1970`

### parseParentTools(sessionID:workingDir:) — Parent Session Tool Counts

```swift
public static func parseParentTools(sessionID: String, workingDir: String) -> [String: Int]
```

Parses the parent session's JSONL file to count all tool invocations made by the assistant.

**Path resolution:**
```
projectsDir = ~/.claude/projects/
encoded     = SessionScanner.encodeProjectPath(workingDir)
jsonlURL    = projectsDir/{encoded}/{sessionID}.jsonl
```

**Algorithm:**
1. Read and split the JSONL file by `"\n"`
2. For each line: decode into `JSONLEntry`, skip non-assistant entries
3. For each assistant entry with a `message`: iterate `message.toolCalls`
4. Increment `toolCounts[toolCall.name, default: 0]`

**Return value:** `[String: Int]` where keys are tool names (e.g. `"Read"`, `"Edit"`, `"Bash"`) and values are total invocation counts across the entire parent session. Returns `[:]` if the file cannot be read.

**Cross-session compatibility:** Works identically for both CLI and Commander sessions. Both session types store their JSONL at `~/.claude/projects/{encoded}/{sessionID}.jsonl` — there is no format difference between CLI and Commander JSONL files.

**Usage:** Called by `AgentTracker.writeSubagentFiles` to populate `parentToolCounts[pid]`. The caller is responsible for sorting (AgentTracker sorts by count descending before storing and `SubagentDetailView` re-sorts before rendering).

---

## SubagentInfo Data Model

`SubagentInfo` is defined in `JSONLParser.swift` and is the `Codable` + `Identifiable` struct used to pass per-subagent data from `AgentTracker` through to `SubagentDetailView`.

```swift
public struct SubagentInfo: Codable, Identifiable {
    public let agentID: String           // filename stem, e.g. "agent-abc123"
    public let model: String             // display name, e.g. "Opus 4.6"
    public let cost: Double              // total USD cost
    public let lastInputTokens: Int      // total input tokens in last message (for context %)
    public let linesAdded: Int           // lines added via Edit/Write
    public let linesRemoved: Int         // lines removed via Edit tool
    public let toolCounts: [String: Int] // tool name → invocation count, default [:]
    public let description: String       // e.g. "Explore UI navigation and views" (from Agent tool_use)
    public let subagentType: String      // e.g. "Explore", "solid-coder:validate-findings-agent"
    public let lastModified: Double      // file mtime as timeIntervalSince1970

    public var id: String { agentID }

    /// Display label: description if available, otherwise subagentType, otherwise agentID.
    public var displayName: String {
        if !description.isEmpty { return description }
        if !subagentType.isEmpty { return subagentType }
        return agentID
    }
}
```

| Field | Populated by | Default |
|-------|-------------|---------|
| `agentID` | `parseSubagentDetails` | — |
| `model` | `parseSubagentDetails` | — |
| `cost` | `parseSubagentDetails` | — |
| `lastInputTokens` | `parseSubagentDetails` | — |
| `linesAdded` | `parseSubagentDetails` | `0` |
| `linesRemoved` | `parseSubagentDetails` | `0` |
| `toolCounts` | `parseSubagentDetails` | `[:]` |
| `description` | `parseSubagentDetails` (via `meta` parameter from `parseSubagentMeta`) | `""` |
| `subagentType` | `parseSubagentDetails` (via `meta` parameter from `parseSubagentMeta`) | `""` |
| `lastModified` | `parseSubagentDetails` (from JSONL file's `contentModificationDate`) | `0` |

`toolCounts` is populated during the same pass as line counting: every `tool_use` content item encountered in any assistant message increments `toolCounts[toolCall.name, default: 0]`. The field is included in the `Codable` serialization and is read back by `SubagentDetailView` to render per-subagent tool chip rows.

`description` and `subagentType` come from `parseSubagentMeta`, which parses the parent session's JSONL to extract metadata from Agent tool_use calls and maps them to subagent IDs via tool_result responses. The `displayName` computed property prefers `description`, then `subagentType`, then falls back to `agentID`.

`lastModified` stores the file's `contentModificationDate` as `timeIntervalSince1970`, enabling sort-by-recent in the subagent detail view.

---

## Timestamp Handling

Timestamps use ISO8601 with fractional seconds:

```swift
private static let timestampFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
```

Example format: `"2026-03-06T10:00:05.123Z"`

`firstTimestamp` is the timestamp of the first successfully-parsed JSONL entry. `lastTimestamp` is the last. Both fall back to `Date()` (now) if no timestamps were parsed.

`durationMs = (lastUpdatedAt - startedAt) * 1000` — computed in `CommanderSupport.writeAgentData`.

---

## ClaudeModel Registry

`ClaudeModel` is defined in `JSONLParser.swift` and serves as the single source of truth for model metadata.

### Supported Models

| Case | ID Patterns | Display Name | Input $/MTok | Output $/MTok | Cache Write $/MTok | Cache Read $/MTok | Context Window |
|------|-------------|--------------|-------------|--------------|-------------------|------------------|----------------|
| `opus4_6` | `opus-4-6`, `opus-4.6` | Opus 4.6 | 5.00 | 25.00 | 6.25 | 0.50 | 1,000,000 |
| `opus4_5` | `opus-4-5`, `opus-4.5` | Opus 4.5 | 5.00 | 25.00 | 6.25 | 0.50 | 1,000,000 |
| `sonnet4_6` | `sonnet-4-6`, `sonnet-4.6` | Sonnet 4.6 | 3.00 | 15.00 | 3.75 | 0.30 | 200,000 |
| `sonnet4_5` | `sonnet-4-5`, `sonnet-4.5` | Sonnet 4.5 | 3.00 | 15.00 | 3.75 | 0.30 | 200,000 |
| `sonnet4` | `sonnet-4-`, `sonnet-4[` | Sonnet 4 | 3.00 | 15.00 | 3.75 | 0.30 | 200,000 |
| `haiku4_5` | `haiku-4-5`, `haiku-4.5` | Haiku 4.5 | 1.00 | 5.00 | 1.25 | 0.10 | 200,000 |

### Pricing Note

Pricing values are the Anthropic API rates (source: platform.claude.com/docs/en/about-claude/pricing). The comment in the source notes these are used for JSONL cost estimation from token counts.

### Fallback Matching

`ClaudeModel.from(modelID:)` iterates all cases and checks `idPatterns.contains(where: { modelID.contains($0) })`. If no pattern matches:

```swift
if modelID.contains("opus")  { return .opus4_6  }
if modelID.contains("haiku") { return .haiku4_5 }
return .sonnet4_6  // default fallback
```

This handles future model versions whose exact IDs are not yet registered.

### Display Name Helper

`ClaudeModel.displayName(for:)` returns `"Claude"` for empty model IDs, otherwise delegates to `from(modelID:).displayName`.

---

## JSONL Decodable Types

### JSONLEntry

```swift
struct JSONLEntry: Decodable {
    let type: String              // "user" or "assistant"
    let message: MessageContent?
    let sessionId: String?
    let cwd: String?
    let slug: String?
    let timestamp: String?        // ISO8601 with fractional seconds
}
```

### MessageContent

```swift
struct MessageContent: Decodable {
    let id: String?               // message ID for deduplication
    let model: String?            // raw model ID
    let usage: Usage?
    let content: [ContentItem]?   // array of text/tool_use items
    var toolCalls: [ToolCall]?    // computed: filter content for tool_use items
}
```

### ContentItem (enum)

`ContentItem` is decoded via a custom `init(from:)`:
- If `"type"` is `"tool_use"`: decoded as `.toolCall(ToolCall)`
- If `"type"` is `"text"`: decoded as `.text(String)` with the value from the `text` JSON key
- Otherwise: decoded as `.other` (ignored)

The `.text` case enables the `textBlocks` computed property on `MessageContent`:
```swift
var textBlocks: [String] {
    content?.compactMap {
        if case .text(let t) = $0 { return t }
        return nil
    } ?? []
}
```

### ToolCall

```swift
struct ToolCall: Decodable {
    let name: String              // "Edit", "Write", "Read", "Bash", etc.
    let input: ToolInput
}

struct ToolInput: Decodable {
    let old_string: String?       // Edit: text being replaced
    let new_string: String?       // Edit: replacement text
    let content: String?          // Write: file content
    let file_path: String?        // Read/Edit/Write: target file path
    let command: String?          // Bash: shell command
    let pattern: String?          // Grep/Glob: search pattern
    let query: String?            // WebSearch: search query
    let url: String?              // WebFetch: URL to fetch
    let prompt: String?           // WebFetch: prompt for content extraction
}
```

The additional `ToolInput` fields (`file_path`, `command`, `pattern`, `query`, `url`, `prompt`) are used by `LogParser` to generate tool call summaries and detail text in the log viewer, not by the cost/lines calculation in `JSONLParser`.

### Usage

```swift
struct Usage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
}
```

---

## Guard Conditions

`parseSession` returns `nil` when:
- The file cannot be read
- `totalOutput == 0` (no assistant responses with usage data found)

`parseSubagentDetails` skips files where:
- The file cannot be read
- `usageByMsgID.isEmpty` after parsing (no valid assistant messages)

These guards prevent zero-cost phantom sessions from appearing in the UI.

---

## Edge Cases & Format Notes

### JSONL Line Endings

The parser uses `.split(separator: "\n")` which handles LF-only line endings. CRLF (`\r\n`) line endings are not handled — if present, each field value would have a trailing `\r` character. In practice, Claude Code on macOS writes LF-only JSONL files, so this is not an issue in production.

### Empty Model String

```swift
if let m = message.model, !m.isEmpty { modelID = m }
```

Lines where `message.model` is an empty string are guarded by `!m.isEmpty` and do not update `modelID`. This prevents streaming partial entries (which may arrive before the model field is populated) from overwriting a valid model ID with an empty string.

### Null vs Missing Fields

All usage token fields use `?? 0` default handling:

```swift
let inp = usage.input_tokens ?? 0
let out = usage.output_tokens ?? 0
let cc  = usage.cache_creation_input_tokens ?? 0
let cr  = usage.cache_read_input_tokens ?? 0
```

A `null` JSON value and an absent JSON key are both decoded as `nil` by Swift's `Decodable`, and both are treated identically — as zero tokens.

### Streaming Partial Entries

The same `message.id` appears multiple times in a JSONL file as streaming progresses. Each streaming partial has a subset of the final token counts. The last entry wins via dictionary overwrite:

```swift
usageByMsgID[msgID] = MsgUsage(input: inp, output: out, cacheCreation: cc, cacheRead: cr)
```

Because JSONL lines are read in chronological order and the final message entry (with `stop_reason`) always comes last, this simple overwrite pattern correctly retains only the final, complete token counts for each message.

### Tool Call Content in Final Messages Only

`tool_use` content items — the `Edit` and `Write` entries used for line counting — appear only in final assistant messages, not in streaming partial entries. Streaming partials contain usage token counts but not content arrays. This means line counting is safe from double-counting: even though the parser processes every line (not only deduplicated ones), `tool_use` blocks appear exactly once per message in the JSONL stream.

### Subagent JSONL Format

The JSONL format for subagent files (`~/.claude/projects/{encoded}/sessionID}/subagents/{agentID}.jsonl`) is identical to the parent session JSONL format. The same parser (`parseSubagents`, `parseSubagentDetails`) handles both. No format distinction is needed.

### Large JSONL Files

There is no caching or incremental parsing. Each call to `parseSession`, `parseSubagents`, or `parseSubagentDetails` reads the full file fresh via `Data(contentsOf: url)`. For very large sessions (files over ~50MB, representing many thousands of messages), this could introduce noticeable latency on the main thread or during background refresh. For typical usage patterns this is acceptable — most sessions produce JSONL files well under 10MB.

### model Field Path

For parent sessions, the model is at `entry.message.model` (i.e., `JSONLEntry.MessageContent.model`). This is a top-level field on the message object:

```json
{"type": "assistant", "message": {"id": "msg_01...", "model": "claude-sonnet-4-5", "usage": {...}, "content": [...]}}
```

Content items are decoded via the custom `ContentItem` enum: `type == "tool_use"` produces `.toolCall(ToolCall)`, `type == "text"` produces `.text(String)`, and all other types produce `.other` (ignored). The `textBlocks` computed property on `MessageContent` filters for `.text` cases.
