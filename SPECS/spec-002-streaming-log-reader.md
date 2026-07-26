---
number: SPEC-002
feature: streaming jsonl log reader
status: draft
blocked-by: []
blocking: []
---

## Problem

`LogViewerViewModel.loadMessages` re-reads and re-parses the entire JSONL session
file on every poll tick (every 2s, plus every PTY activity event). For an active
session with thousands of lines this is O(file size) per tick — wasted CPU,
wasted memory churn, and the resulting wholesale array reassignment is what
caused the recent "logs lag and disappear until I scroll" regression.

We want incremental parsing: read each line once, and on file growth read only
the new bytes. The view should observe a state that is *mutated in place* rather
than reassigned wholesale.

## Why streaming, not just diffing

A diff-the-output approach (parse the whole file, compute delta vs previous
result) still pays the full parse cost. The actual win is on the input side:
parse cost should scale with bytes-added, not file-size.

`URL.lines` (`AsyncLineSequence`) handles initial backfill cleanly. A
`DispatchSource.makeFileSystemObjectSource` on the file descriptor handles
the tail: on `.write`/`.extend` we seek to the last consumed offset and read
forward to the next `\n`. Both feed a single `AsyncStream<String>` (the
"line subject") that the parser reduces over.

## Architecture

Three components, one composition root:

### 1. `LineSource` — emits complete JSONL lines

```
protocol LineSource {
    func lines(at url: URL) -> AsyncStream<String>
    func cancel()
}
```

Implementation: `TailingLineSource`
- Phase A (backfill): use `URL(fileURLWithPath:).lines` (or manual `FileHandle`
  read) to emit every existing line. Track byte offset as bytes are consumed.
- Phase B (tail): open a `DispatchSource.makeFileSystemObjectSource(
  fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename])`.
  On each event, seek to the tracked offset and read forward; buffer bytes
  until `\n`, emit complete lines, advance offset.
- Termination: stream completes on `.delete`/`.rename`, or on explicit
  `cancel()`. `AsyncStream` continuation closes cleanly so the reducer task
  exits.

Edge cases:
- **Partial line at EOF**: hold a `Data` buffer of bytes after the last `\n`;
  do not emit until terminator arrives.
- **File shrunk** (truncate / rotate / replaced): if `fstat.st_size <
  trackedOffset`, reset offset to 0, signal a `.reset` event upstream so the
  reducer drops accumulated state and re-backfills.
- **File doesn't exist yet**: poll for existence (cheap, mtime-only) before
  opening the watcher. Once it appears, transition into Phase A.

### 2. `JSONLineApplier` — pure reducer over `ParserState`

```
struct ParserState {
    var messages: [LogMessage]
    var assistantByID: [String: Int]               // message.id → result index
    var assistantIdxByToolUseID: [String: Int]
    var hookRefByToolUseID: [String: (Int, Int)]
    var promptToolIDs: Set<String>
}

protocol JSONLineApplier {
    func apply(_ line: String, to state: inout ParserState) -> StateChange
}

enum StateChange {
    case appended(index: Int)
    case mutated(index: Int)
    case noop
}
```

This is `LogParser.parseMessages` factored line-by-line. The body of the
existing `for line in content.split(separator: "\n")` loop becomes the body
of `apply`. All state that is currently local to `parseMessages` (the four
dictionaries) moves into `ParserState`.

The reducer must handle the existing mutation cases:
- `hook_progress` → mutate prior assistant message at
  `assistantIdxByToolUseID[toolUseID]`, or append a new system message.
- `stop_hook_summary` → mutate prior hook chip at
  `hookRefByToolUseID[toolUseID]`.
- `hook_additional_context` / `hook_success` / `hook_blocking_error` /
  `hook_system_message` / `hook_cancelled` → attach to prior assistant or
  append system message.
- streamed `assistant` deltas with same `message.id` → merge tool calls
  into existing record.
- `user` messages with `tool_result` → resolve `pendingPrompt` for prior
  assistants on the *consumer* side (derived state, recomputed only when
  affected indices change).

Returning `StateChange` lets the consumer rebuild only the affected derived
state instead of running `rebuildDerivedState` over the whole array.

### 3. `StreamingLogViewModel` — observable façade

Replaces (or sits alongside) `LogViewerViewModel`. Same protocol surface
(`LogViewerState` + `LogViewerActions`) so `LogViewerView` is unchanged.

```
@Observable
final class StreamingLogViewModel: LogViewerState, LogViewerActions {
    private(set) var messages: [LogMessage] = []
    private(set) var displayedMessages: [LogMessage] = []
    private(set) var taskList: [TaskListItem] = []
    private(set) var toolResultLookup: [String: String] = [:]
    private(set) var pendingPrompt: LogToolCall?
    private(set) var isLoading = true

    private var state = ParserState(...)
    private let source: LineSource
    private let applier: JSONLineApplier
    private var streamTask: Task<Void, Never>?

    func startPolling() async {
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await line in source.lines(at: fileURL) {
                let change = applier.apply(line, to: &state)
                applyChange(change)
            }
        }
    }

    private func applyChange(_ change: StateChange) {
        switch change {
        case .appended(let i):
            messages.append(state.messages[i])
            updateDerived(touchedIndex: i)
        case .mutated(let i):
            messages[i] = state.messages[i]
            updateDerived(touchedIndex: i)
        case .noop: break
        }
        if isLoading { isLoading = false }
    }
}
```

Key property: `messages` is mutated index-by-index, never reassigned. SwiftUI's
diff is per-row, `LazyVStack` becomes safe to use, and per-tick cost is
proportional to new bytes.

## Composition root

`LogViewerScreen` (or wherever `LogViewerViewModel` is constructed today) gets
a feature flag during rollout:

```
let vm: any LogViewerState & LogViewerActions =
    settings.useStreamingLogReader
        ? StreamingLogViewModel(agent: agent, target: target, ...)
        : LogViewerViewModel(agent: agent, target: target, ...)
```

The flag goes away once streaming is validated.

## Out of scope

- Codex log files (`Sources/Codex/`) — different format, addressed in a follow-up
  spec by swapping the `JSONLineApplier`.
- Persisting parsed state across app launches.
- Replacing `lsof`-based PID-to-file resolution.

## Acceptance criteria

- Active session with 5000+ lines: parse CPU drops from O(file) per tick to
  O(new bytes) per tick. Verifiable by Instruments time-profile on the
  parser thread before vs after.
- Scrolling up to read older messages no longer snaps back unless user is
  already near bottom (separate from parser change but unblocked by it —
  consumer knows whether the change was an `append` or a `mutate`, so the
  view's autoscroll can be conditional).
- Truncating the JSONL file mid-session resets state and rebuilds without
  crashing or duplicating rows.
- File watcher cleanly cancels on view dismiss (no leaked DispatchSource).
- Existing `LogViewerView` UI is unchanged.

## Subtasks

1. Extract `ParserState` struct from `LogParser.parseMessages` locals.
2. Extract `JSONLineApplier.apply(_:to:)` from the existing parse loop body
   (one branch per `type`/`subtype`). Add unit tests using sample JSONL lines
   from `~/.claude/projects/`.
3. Implement `TailingLineSource` (backfill via `FileHandle`, tail via
   `DispatchSource`, partial-line buffer, shrink-reset).
4. Implement `StreamingLogViewModel` conforming to `LogViewerState` +
   `LogViewerActions`. Mutate `messages` index-by-index.
5. Add settings flag; wire composition root to choose VM.
6. Validate: 5000-line session, file truncation, file replacement, view
   dismiss/recreate, PTY activity bursts.
7. Remove old `LogViewerViewModel` + flag once validated.
