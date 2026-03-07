# Commander Integration Specification

## Overview

Commander is a class of tools that invoke Claude Code in pipe/batch mode using the flag combination `-p --output-format=stream-json`. In this mode, Claude Code reads from stdin and writes streaming JSON to stdout. The statusline hook is never invoked, so the CLI integration cannot capture cost data.

The Commander integration discovers these sessions through OS-level process inspection and parses Claude Code's own JSONL conversation files to reconstruct usage data. It writes the same `.dat` and `.agent.json` file format as the CLI integration, but to a separate `commander/` subdirectory to avoid namespace collisions.

---

## What Commander Is

A "Commander" process is any process whose executable path contains `"Commander.app"` or ends in `"/Commander"` as detected by `ps -e -o pid,ppid,comm`. The most common case is a GUI application (e.g. an Xcode application or custom tool named "Commander") that programmatically spawns `claude` as a child process in pipe mode.

---

## Why It Is Separate From CLI

| Aspect | CLI (statusline) | Commander |
|--------|-----------------|-----------|
| Trigger | After each AI response | Polling (5s) + popover open |
| Cost source | `cost.total_cost_usd` from Claude Code JSON | Computed from JSONL token counts × pricing |
| Lines source | `cost.total_lines_added/removed` from Claude Code | Counted from Edit/Write tool_use inputs in JSONL |
| API duration | `cost.total_api_duration_ms` from Claude Code | Not available (always 0) |
| Storage | `~/.claude/usage/YYYY-MM-DD/` | `~/.claude/usage/commander/YYYY-MM-DD/` |
| Models file | Written on model change | Not written (JSONL parsed instead) |
| Agent name | From `agent.name` in JSON | Empty string (not available from JSONL) |

Commander costs are estimates computed from token counts using `PriceCalculator`, while CLI costs are exact values reported by Claude Code itself. Commander pricing uses the actual Anthropic API rates (source: platform.claude.com/docs/en/about-claude/pricing).

---

## Session Discovery

`SessionScanner.findActiveSessions()` implements session discovery. Results are cached for 2 seconds to prevent redundant system calls when multiple callers run in the same refresh cycle.

### Step 1: Find Commander PIDs

```sh
ps -e -o pid,ppid,comm
```

Parse output to find PIDs where the `comm` column contains `"Commander.app"` or ends with `"/Commander"`:

```
Finding Commander processes from ps output:
  "12345  1234  /Applications/Commander.app/..."  → commanderPIDs.insert(12345)
```

### Step 2: Find Claude Processes Spawned by Commander

From the same `ps` output, find lines where:
- `comm` ends with `"/claude"` or `" claude"` (the claude binary)
- The PPID is in `commanderPIDs`

Extract the PID of each such process.

### Step 3: Get Working Directories via lsof

```sh
lsof -a -p {pid1,pid2,...} -d cwd -Fn
```

The `-Fn` flag produces output in `n` format (name-only), structured as:
```
p12345
n/Users/alice/myproject
p12346
n/Users/alice/otherapp
```

Parse: `p` lines set current PID; `n/` lines set the CWD for that PID.

**Deadlock prevention**: The pipe is read to completion (`readDataToEndOfFile`) *before* `waitUntilExit` to avoid blocking when lsof output exceeds the pipe buffer.

### Step 4: Locate JSONL File

For each `(pid, cwd)` pair:
1. Encode the path: `SessionScanner.encodeProjectPath(cwd)` — replaces `/`, `.`, `_` all with `-`
   - Example: `/Users/alice/.ai_rules` → `-Users-alice--ai-rules`
2. Look in `~/.claude/projects/{encoded_path}/` for the most recently modified `.jsonl` file (top-level directory only — not recursive)
3. The session ID is the stem of the JSONL filename (filename minus extension)
4. If no `.jsonl` file exists, the session is skipped

### Result

Returns `[ActiveSession]` where each element has:
- `pid`: the claude process PID
- `workingDir`: absolute path to the working directory
- `jsonlURL`: URL of the most recent JSONL file
- `sessionID`: stem of the JSONL filename

---

## refreshFiles() Flow

Called by `AppDelegate` on the main refresh cycle (before `UsageData.reload()` and `AgentTracker.reload()`).

```
CommanderSupport.refreshFiles()
  1. cleanupDeadPIDs(in: todayDir)
  2. cleanupOldData(today:dateFmt:)
  3. writeAgentData(in: todayDir)
```

### cleanupDeadPIDs

For each `.agent.json` in today's commander directory:
- Extract PID from filename
- `kill(Int32(pid), 0)` — if non-zero return (ESRCH = no such process), delete the file
- `.dat` files are intentionally preserved even for dead PIDs (cost history retention)

### cleanupOldData

Runs once per day (marker file at `~/.claude/usage/commander/.last_cleanup`):
- Computes cutoff date as 3 months before today
- Removes `commander/YYYY-MM-DD/` directories older than the cutoff
- Skips non-date-named entries (e.g. the `.last_cleanup` file itself)

### writeAgentData

For each active session returned by `SessionScanner.findActiveSessions()`:
1. Calls `JSONLParser.parseSession(at:sessionID:workingDir:)` — returns `SessionUsage?`
2. Skips sessions where parsing returns nil (no output tokens, JSONL unreadable)
3. Computes `durationMs` from `lastUpdatedAt - startedAt` (in milliseconds)
4. Resolves `ClaudeModel.from(modelID:)` to get context window size
5. Writes `{pid}.dat`:
   ```
   {costUSD} {linesAdded} {linesRemoved} {displayModel}\n
   ```
6. Writes `{pid}.agent.json` using `AgentFileData` struct (encoded via `JSONEncoder`)
   - `apiDurationMs` is always `0` (not available from JSONL)
   - `contextWindow` is set from `ClaudeModel.contextWindowSize` (not from JSONL)

---

## JSONL File Location

Claude Code stores conversation history in:
```
~/.claude/projects/{encoded_path}/{sessionID}.jsonl
```

### Path Encoding Rules

`SessionScanner.encodeProjectPath(_:)`:
- `/` → `-`
- `.` → `-`
- `_` → `-`
- All other characters preserved

Example:
```
/Users/alice/my.project_dir → -Users-alice-my-project-dir
```

Note: This encoding is not reversible (multiple paths can encode to the same string), but Claude Code uses it as a lookup key, so we replicate the same logic.

### Most Recent JSONL Selection

When multiple `.jsonl` files exist in a project directory, `SessionScanner.mostRecentJSONL(in:)` picks the one with the highest `contentModificationDate`. This handles the case where a user has run multiple sessions in the same project directory.

---

## Separate Storage

All Commander-generated files are stored under `~/.claude/usage/commander/` rather than `~/.claude/usage/`. This separation:

1. Prevents double-counting: `UsageData` knows CLI data is in `usageDir` and Commander data is in `CommanderSupport.baseDir`. They are aggregated separately into `PeriodStats.cli` and `PeriodStats.commander`
2. Prevents collision: If a CLI session and a Commander session happen to have the same PID (unlikely but possible across time), their files are in different directories
3. Allows Commander data to be removed cleanly: deleting `~/.claude/usage/commander/` removes all Commander data without affecting CLI history

---

## Limitations

| Limitation | Reason | Impact |
|------------|--------|--------|
| No `api_duration_ms` | Not present in JSONL | `AgentInfo.apiDurationMs` always 0 for Commander agents |
| No `agent_name` | Not captured in JSONL (field exists but always empty in parser) | `agent.displayName` falls back to model name |
| Cost is estimated | Token-based calculation, not exact | May differ from actual charges by up to ~20% |
| No `.models` file | Model breakdown comes from JSONL directly, not via transition log | Commander sessions show in the detail view but without model cost breakdown via `.models`; breakdown comes from JSONL if subagent scanning is available |
| Lines not from Claude Code | Counted from Edit/Write tool_use inputs | May miss lines changed by other tools |
| Only today's sessions | `writeAgentData` only writes today; historical Commander sessions not tracked | Past Commander sessions not visible in period stats unless a `.dat` file was already written |

---

## Edge Cases

### Multiple Commander Instances
If multiple Commander processes are running simultaneously, each spawns its own set of `claude` child processes. All are discovered by the PPID check and tracked independently by their PIDs.

### Commander Process Not Yet in ps
If `refreshFiles()` is called immediately after a Commander process starts, the `claude` child may not yet be visible in `ps`. The session will be discovered on the next refresh (5s poll or next popover open).

### JSONL File Being Written
The JSONL file is written incrementally by Claude Code. `JSONLParser` reads whatever is available at the time of scanning. Partial reads are safe because:
- Each line is parsed independently
- Message deduplication (last entry per message ID wins) handles streaming partials
- `guard totalOutput > 0 else { return nil }` prevents returning empty sessions

### Same Working Directory, Different Sessions
If a user runs multiple sequential Commander sessions in the same directory, `mostRecentJSONL(in:)` always picks the most recently modified file. The PID for the newer session will be different, so files from the previous session's PID are cleaned up by `cleanupDeadPIDs`.

### CLI Session and Commander Session in Same Directory
`CommanderSupport` skips CLI-tracked PIDs through the separation architecture. The CLI statusline uses `$PPID` (the claude process PID) and writes to `~/.claude/usage/YYYY-MM-DD/`. Commander writes to `~/.claude/usage/commander/YYYY-MM-DD/` using the same claude PID. `UsageData` reads from both roots and attributes them to different sources. The `AgentTracker` comment notes: "No dedup needed — CommanderSupport already skips CLI-tracked PIDs" by virtue of using a separate storage tree.

### lsof Permission Denied
On macOS, `lsof` for another user's processes may require elevated privileges. Since this app runs as the current user and targets claude processes also running as the current user, no privilege escalation is needed.

---

## External Command Contracts

### ps Invocation

```sh
/bin/ps -e -o pid,ppid,comm
```

- `-e`: list all processes (not just the current user's)
- `-o pid,ppid,comm`: output three columns — PID, parent PID, and command (executable path)
- Output format: space-separated, one process per line, with a header row as the first line
- `comm` is the full executable path (e.g. `/usr/bin/python3`) or the short name for system processes
- The header row is ignored during parsing because PID parsing (`Int(parts[0])`) fails on the header text

### lsof Invocation

```sh
/usr/sbin/lsof -a -p {pids} -d cwd -Fn
```

- `-a`: AND the following filters (all conditions must match)
- `-p {pids}`: filter to the specified PIDs; multiple PIDs joined with commas (e.g. `-p 1234,5678,9012`)
- `-d cwd`: filter to file descriptor `cwd` (current working directory)
- `-Fn`: produce output in field format, name-only (`n` field)

Output format: alternating lines, one block per process:
```
p12345
n/Users/alice/myproject
p12346
n/Users/alice/otherapp
```

`p` lines set the current PID context; `n` lines provide the field value (the path). A `n` line starting with `n/` is an absolute path — the cwd for the current PID.

### Commander Process Matching

Commander processes are identified from `ps` output using these string checks on the `comm` column (the executable path):

- `comm.contains("Commander.app")` — matches macOS app bundles (e.g. `/Applications/MyTool.app/Contents/MacOS/Commander`)
- `comm.hasSuffix("/Commander")` — matches bare executables named `Commander`

Both checks are case-sensitive. A process must match at least one to be classified as a Commander parent.

### claude Process Matching

`claude` processes spawned by Commander are identified from `ps` output using:

- `comm.hasSuffix("/claude")` — matches the full path to the claude binary (e.g. `/usr/local/bin/claude`)
- `comm.hasSuffix(" claude")` — catches cases where the name appears with a leading space in the comm field (unusual but defensive)

The PPID of each matching `claude` process is checked against the set of known Commander PIDs to confirm parentage.

### Cache TTL

`SessionScanner.findActiveSessions()` caches its results for exactly 2.0 seconds:

```swift
if let cache = cachedSessions, now.timeIntervalSince(cacheTime) < 2 {
    return cache
}
```

This prevents redundant `ps` + `lsof` invocations when multiple callers run within the same refresh cycle (e.g., both the monitor callback and a popover-open event fire close together). The 2-second TTL is short enough that session state remains current for practical purposes.

### runCommand: readDataToEndOfFile Before waitUntilExit

The `runCommand` helper (used for both `ps` and `lsof`) reads the pipe to completion before calling `waitUntilExit()`:

```swift
let data = pipe.fileHandleForReading.readDataToEndOfFile()
process.waitUntilExit()
```

This ordering is required to prevent a pipe buffer deadlock. If `waitUntilExit()` were called first, the child process (ps or lsof) could block trying to write to the pipe after the pipe buffer fills up, while the parent waits for the child to exit — a classic deadlock. Reading the pipe to completion first ensures the child is never blocked waiting for the reader.

### stderr Suppression

Both `ps` and `lsof` invocations redirect stderr to `FileHandle.nullDevice`:

```swift
process.standardError = FileHandle.nullDevice
```

Any error output from these commands (e.g., `lsof` warnings about inaccessible processes) is silently discarded. Only stdout is captured and parsed.

### Process Working Directory Line Format from lsof

The cwd line from lsof output starts with `n` (the field-name prefix) followed immediately by the absolute path:

```
n/Users/alice/myproject
```

Parsing: check that the line starts with `"n/"` (the `n` prefix plus the leading `/` of an absolute path), then take everything from index 1 onward as the path. Lines starting with `n` but not `n/` (e.g., `n(deleted)` for deleted working directories) are ignored.
