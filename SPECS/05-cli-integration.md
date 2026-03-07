# CLI Integration Specification

## Overview

The CLI integration captures usage data from interactive Claude Code sessions. Claude Code supports a user-configurable statusline command (`statusLine.command` in `~/.claude/settings.json`). After each AI response, Claude Code pipes a JSON blob over stdin to this command. The ClaudeUsageBar tracking code parses this blob and writes three files per session per day to `~/.claude/usage/YYYY-MM-DD/`.

The Swift component responsible for installing and managing this integration is `StatuslineInstaller.swift`.

---

## How It Works

```
Claude Code (interactive session)
  → fires statusLine.command after each response
    → statusline-command.sh receives JSON via stdin
      → extracts: cost, lines, model, agent, context, session, working dir
        → writes {PPID}.dat, {PPID}.models, {PPID}.agent.json
          → UsageData and AgentTracker read these files
```

The script uses `$PPID` (the parent PID of the shell executing the script — the `claude` process itself) as the identifier for each session file. This ensures each Claude Code session has its own set of files.

---

## Data Captured

The statusline command receives a JSON blob from Claude Code. The following fields are extracted:

| Shell variable | JSON path | Description |
|----------------|-----------|-------------|
| `$COST` / `$_CUB_COST` | `.cost.total_cost_usd` | Cumulative USD cost since session start |
| `$LINES_ADDED` / `$_CUB_LA` | `.cost.total_lines_added` | Cumulative lines added |
| `$LINES_REMOVED` / `$_CUB_LR` | `.cost.total_lines_removed` | Cumulative lines removed |
| `$MODEL` / `$_CUB_MODEL` | `.model.display_name` | Current model display name |
| `$AGENT_NAME` / `$_CUB_AGENT` | `.agent.name` | Agent name (empty string if not in agent mode) |
| `$PCT` / `$_CUB_CTX` | `.context_window.used_percentage` | Context usage % (integer portion) |
| `$CTXWIN` / `$_CUB_CTXWIN` | `.context_window.context_window_size` | Context window size in tokens |
| `$DURATION_MS` / `$_CUB_DUR` | `.cost.total_duration_ms` | Total session duration in milliseconds |
| `_CUB_ADUR` | `.cost.total_api_duration_ms` | Total API time in milliseconds (injection snippet only) |
| `$SESSION_ID` / `$_CUB_SID` | `.session_id` | Claude Code session UUID |
| `$DIR` / `$_CUB_WDIR` | `.workspace.current_dir` | Absolute path to working directory |

All values default to `0` or `""` via jq's `// 0` / `// ""` fallback operators if the field is absent.

The context window percentage is truncated to integer via `cut -d. -f1` (bundled script) or similar logic (injected snippet).

---

## Files Written

All files live under `~/.claude/usage/YYYY-MM-DD/` where `YYYY-MM-DD` is today's date in local time.

### `{PPID}.dat`

Space-separated single-line text file:

```
{cost} {linesAdded} {linesRemoved} {model}\n
```

Example:
```
1.234567 850 320 Claude Sonnet 4.5
```

- Written atomically (overwrite on each statusline invocation)
- Stores cumulative values for the session — not incremental
- Model name can contain spaces (joined from remaining tokens when parsing)
- Parsed by `UsageData.collectEntries(under:source:since:)` — splits on space, `[3...]` joined for model

### `{PPID}.models`

TSV append-log. One line is appended whenever the model changes between statusline invocations:

```
{cost}\t{linesAdded}\t{linesRemoved}\t{model}
```

**Model transition detection logic** (bundled script):
```sh
MF="$USAGE_DIR/$TODAY/$PPID.models"
PREV_MODEL=""; [ -f "$MF" ] && PREV_MODEL=$(tail -1 "$MF" | cut -f4-)
[ "$PREV_MODEL" != "$MODEL" ] && printf '%s\t%s\t%s\t%s\n' "$COST" "$LINES_ADDED" "$LINES_REMOVED" "$MODEL" >> "$MF"
```

The last line of the file is read; if the model in its 4th column differs from the current model, a new line is appended. The values written are the cumulative totals at the moment of the model switch.

This file is the basis for per-model cost attribution in `UsageData.modelBreakdown(history:absoluteCost:periodCost:totalLA:totalLR:)`.

**Edge case — first-time model:**
The very first invocation writes the first `.models` entry (no previous model to compare to). Subsequent invocations only write if the model changes.

**Edge case — empty `.models` file:**
`UsageData` requires `transitions.count > 1` to use the model breakdown algorithm. A file with a single line falls back to the simple `entry.model` attribution.

### `{PPID}.agent.json`

Full agent metadata written as a single JSON object. Written atomically (`.tmp` then `mv`):

```json
{
  "pid": 12345,
  "model": "Claude Sonnet 4.5",
  "agent_name": "My Agent",
  "context_pct": 45,
  "context_window": 200000,
  "cost": 1.234567,
  "lines_added": 850,
  "lines_removed": 320,
  "working_dir": "/Users/alice/myproject",
  "session_id": "abc123-...",
  "duration_ms": 180000,
  "api_duration_ms": 12000,
  "updated_at": 1741234567
}
```

The atomic write (`cat > .tmp` + `mv`) prevents `AgentTracker` from reading a partially-written file. The `updated_at` field is a Unix timestamp (seconds since epoch) from `date +%s`.

This file is decoded by `AgentTracker` using `AgentFileData` (Codable). The `CodingKeys` mapping uses snake_case JSON names.

---

## Cleanup

The bundled statusline script runs a cleanup pass on each invocation, but only once per day (controlled by `~/.claude/usage/.last_cleanup`):

```sh
CLEANUP_MARKER="$USAGE_DIR/.last_cleanup"
if [ ! -f "$CLEANUP_MARKER" ] || [ "$(cat "$CLEANUP_MARKER")" != "$TODAY" ]; then
  echo "$TODAY" > "$CLEANUP_MARKER"
  CUTOFF=$(date -v-3m +%Y-%m-%d)
  for dir in "$USAGE_DIR"/????-??-??; do
    [ -d "$dir" ] || continue
    [ "$(basename "$dir")" \< "$CUTOFF" ] && rm -rf "$dir"
  done
fi
```

- Data older than 3 months is removed
- The cutoff date is computed as 3 months before today using `date -v-3m` (macOS BSD date syntax)
- Only YYYY-MM-DD-named directories are removed (not `commander/` or other subdirectories)
- The marker file stores today's date string; the check runs once per calendar day

---

## StatuslineInstaller

`StatuslineInstaller.swift` manages installation, detection, and upgrade of the tracking code.

### Detection Flow

`isInstalled` property:
1. Reads `~/.claude/settings.json`
2. Extracts `statusLine.command`
3. Finds the `.sh` file path in the command string (reversed token search)
4. If the script path matches `defaultScriptURL` (`~/.claude/statusline-command.sh`):
   - Reads the bundled resource `statusline-command.sh` from `Bundle.module`
   - Returns `content == bundled` — exact byte-for-byte match
5. If a custom script path:
   - Returns `content.contains(trackingSnippet)` — checks for the exact tracking block

`needsUpgrade` property:
1. For bundled script: returns `!isInstalled` (file exists but content differs from bundle)
2. For custom script: returns `content.contains(trackingMarker) && !content.contains(trackingSnippet)` — the block exists but its content has changed

### Installation States

| State | `isInstalled` | `needsUpgrade` | Action taken |
|-------|---------------|----------------|--------------|
| No `settings.json` or no `statusLine.command` | `false` | `false` | `installFreshScript()` |
| Custom script with no tracking block | `false` | `false` | `injectTracking(into:)` |
| Custom script with outdated tracking block | `false` | `true` | `upgrade()` |
| Bundled script present but outdated | `false` | `true` | `installFreshScript()` (re-copy) |
| Bundled script exact match | `true` | `false` | No-op |
| Custom script with current tracking snippet | `true` | `false` | No-op |

### `install()` Logic

```
if isInstalled → return true (no-op)
if needsUpgrade → upgrade()
else if existing script path exists → injectTracking(into:)
else → installFreshScript()
```

### `installFreshScript()` (Bundled Script)

1. Copies bundled `statusline-command.sh` from `Bundle.module` to `~/.claude/statusline-command.sh`
2. Sets file permissions to `0o755`
3. Reads/creates `~/.claude/settings.json`
4. Sets `json["statusLine"] = {"type": "command", "command": "sh ~/.claude/statusline-command.sh"}`
5. Writes updated JSON with `.prettyPrinted`, `.sortedKeys`, `.withoutEscapingSlashes`

### `injectTracking(into:)` (Custom Script)

Injects the `trackingSnippet` into an existing user script:

1. If `input=$(cat)` line exists:
   - Inserts `\n{trackingSnippet}\n` immediately after the `input=$(cat)` line
2. If no `input=$(cat)` line:
   - Prepends `input=$(cat)\n{trackingSnippet}\n` after the shebang line (if present), or at the top
3. Writes back atomically

### `upgrade()` (Custom Script with Old Block)

1. Reads the script
2. If it's the bundled script: calls `installFreshScript()`
3. Otherwise:
   - Removes the existing block between `trackingMarker` and `trackingEndMarker` (inclusive, plus trailing newline)
   - Re-inserts new `trackingSnippet` after `input=$(cat)` (same logic as inject)
   - Writes back atomically

### Markers

```swift
private static let trackingMarker    = "# --- ClaudeUsageBar tracking ---"
private static let trackingEndMarker = "# --- end ClaudeUsageBar tracking ---"
```

These delimiters wrap the tracking block in custom scripts, enabling future upgrades to replace only the tracking code.

### Injected Snippet vs Bundled Script

The **injected snippet** (for custom scripts) is a minimal version that only writes the usage files. It does not produce terminal output and includes the `.tmp` → `mv` atomic write pattern.

The **bundled script** (`statusline-command.sh`) is a full-featured statusline that:
- Displays a colored context bar in the terminal
- Shows model name, working directory, git branch
- Displays period stats (day/week/month cost and lines)
- Includes the tracking block as a named section with markers

### Error Handling

- `install()` returns `Bool` — `false` indicates failure
- `PopoverView` shows `"Install failed — check jq is installed"` when `installError = true` (set when `install()` returns `false`)
- `jq` is a runtime dependency; if not installed, the shell script will silently fail to extract values (jq commands return empty strings/1 exit code)

---

## Bundled Script Display Output

The `statusline-command.sh` bundled script produces 4 lines of terminal output after each Claude Code response:

```
[Claude Sonnet 4.5] 📁 myproject | 🌿 main
████████░░  80% | $1.23 | ⏱️ 3m 15s
📊  Day: $1.23 | Wk: $8.45 | Mo: $42.10
✏️  Day: +850/-320 | Wk: +4.2K/-1.8K | Mo: +21K/-9K
```

The period stats in the terminal output use the same deduplication logic (awk) as the Swift `UsageData` class for consistency.

---

## Shell Script Details

### jq Field Extraction with Fallback

All fields are extracted from the JSON blob piped via stdin using `jq` with a fallback default:

```sh
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
MODEL=$(echo "$input" | jq -r '.model.display_name // ""')
```

The `// default` operator in jq returns the default when the left-hand side is `null` or `false`. Missing fields and explicit `null` values both fall through to the default. The `-r` flag outputs raw strings (no JSON quoting).

### PPID vs $$

The script uses `$PPID` (the parent PID of the current shell process) rather than `$$` (the PID of the current shell process itself):

```sh
# $PPID = the claude process that invoked this script
# $$ = the shell process running this script (not useful as a session ID)
```

When Claude Code fires the statusline command, it launches a shell to run the script. `$$` would be the PID of that shell, which is ephemeral and different on every invocation. `$PPID` is the PID of the claude process that spawned the shell — consistent across all statusline invocations for the same session.

### Atomic agent.json Write Pattern

The `.agent.json` file is written atomically using a temporary file and `mv`:

```sh
cat > "$AGENT_FILE.tmp" <<EOF
{ "pid": $PPID, "model": "$MODEL", ... }
EOF
mv "$AGENT_FILE.tmp" "$AGENT_FILE"
```

This prevents `AgentTracker` from reading a partially-written JSON file. If the Swift app reads the file while the `cat` is writing it, it reads either the old complete file (if mv has not happened yet) or the new complete file (after mv). It never reads a partial file because `mv` on the same filesystem is atomic.

### Color Output (ANSI Escape Codes)

The bundled script uses ANSI escape codes for colored terminal output:

```sh
\033[36m    # cyan (model name, directory)
\033[32m    # green (positive stats)
\033[33m    # yellow (warnings, context bar near full)
\033[0m     # reset (return to default terminal color)
```

### Context Bar Generation

The filled and empty block characters in the context bar are generated using `printf` and `tr`:

```sh
printf "%${FILLED}s" | tr ' ' '█'   # filled blocks
printf "%${EMPTY}s"  | tr ' ' '░'   # empty blocks
```

`printf "%Ns"` produces a string of N spaces. `tr ' ' 'X'` replaces every space with `X`. The combination produces a string of N block characters without a loop. `FILLED` and `EMPTY` are computed from the context percentage and total bar width.

### Duration Format

Session duration is formatted from milliseconds:

```sh
MINS=$(( DURATION_MS / 60000 ))
SECS=$(( (DURATION_MS % 60000) / 1000 ))
echo "${MINS}m ${SECS}s"
```

For sessions over an hour, the display switches to `"NhNm"` format.

### Period Aggregation with awk

The shell script computes day/week/month period stats using a single `awk` pass over all `.dat` files:

```sh
awk '...' "$USAGE_DIR"/????-??-??/*.dat 2>/dev/null
```

The awk program reads all `.dat` files in one pass, tracking day/week/month sums inline. Each file's path is used to extract the date (`FILENAME`), and a deduplication map keyed by PID (filename without path and extension) tracks the latest and previous entry per PID — mirroring the Swift `UsageData` deduplication algorithm.

### Week Start Calculation

The week start (Monday) is computed using BSD `date`:

```sh
DOW=$(date +%u)                          # Day of week: Monday=1, Sunday=7
WEEK_START=$(date -v-$(( DOW - 1 ))d +%Y-%m-%d)
```

`date +%u` returns the ISO weekday (Monday=1, Sunday=7). Subtracting `DOW - 1` days from today gives the most recent Monday.

### Month Start Calculation

```sh
MONTH_START=$(date +%Y-%m-01)
```

Simple string construction — always the first day of the current calendar month.

### Deduplication Algorithm in awk

The awk deduplication mirrors the Swift `UsageData` logic:

```awk
{
    pid = FILENAME  # extract PID from filename
    # Remove directory path and .dat extension to get PID string
    # Track latest and previous entry per PID
    if (pid in latest) {
        prev_cost[pid] = latest_cost[pid]
        prev_day[pid] = latest_day[pid]
    }
    latest_cost[pid] = $1   # first field: cost
    latest_la[pid]   = $2   # second field: linesAdded
    latest_lr[pid]   = $3   # third field: linesRemoved
    latest_day[pid]  = dir_date
}
```

After processing all files, the awk `END` block computes incremental costs for day/week using the same rules as the Swift implementation: subtract the previous entry's cost when the session spans a period boundary.

### Cleanup: Once Per Day via Marker File

```sh
CLEANUP_MARKER="$USAGE_DIR/.last_cleanup"
if [ ! -f "$CLEANUP_MARKER" ] || [ "$(cat "$CLEANUP_MARKER")" != "$TODAY" ]; then
    echo "$TODAY" > "$CLEANUP_MARKER"
    # ... run cleanup
fi
```

The marker file stores today's date string. The cleanup only runs when the file is absent or its content differs from today's date. This ensures cleanup runs at most once per calendar day regardless of how many times the statusline fires.

### 3-Month Retention

```sh
CUTOFF=$(date -v-3m +%Y-%m-%d)
for dir in "$USAGE_DIR"/????-??-??; do
    [ -d "$dir" ] || continue
    [ "$(basename "$dir")" \< "$CUTOFF" ] && rm -rf "$dir"
done
```

`date -v-3m` uses BSD date's relative date syntax to compute the date 3 months before today. The glob `????-??-??` matches only date-named directories, leaving `commander/` and other subdirectories untouched. String comparison (`\<`) works correctly for ISO date strings because the format is lexicographically ordered.

---

## Future Improvement: Tool Usage Tracking for CLI Sessions

### Current Limitation
The statusline JSON from Claude Code does not expose tool usage counts (e.g. how many times `Read`, `Edit`, `Bash` were called in a session). Tool counts are therefore unavailable for CLI sessions in the current implementation.

### Feasible Approach
CLI sessions have their own JSONL conversation files at:
```
~/.claude/projects/{encodeProjectPath(workingDir)}/{session_id}.jsonl
```
Both `session_id` and `working_dir` are already captured in `{pid}.agent.json` (via `AgentFileData`). The same `JSONLParser` tool-counting logic used for Commander sessions and subagents applies identically to CLI parent JSONL files.

### Implementation Path
In `AgentTracker.writeSubagentFiles`, for CLI agents:
1. Resolve JSONL path: `~/.claude/projects/{encoded}/{sessionID}.jsonl`
2. Parse tool_use entries using existing `JSONLEntry` + `ToolCall` decoder
3. Store `toolCounts: [String: Int]` in `AgentFileData` (field already exists in struct, currently unused for CLI)
4. Display in agent detail view alongside subagent tool chips

### Constraints
- JSONL can be large (50MB+) for long sessions — parsing should run on a background thread
- Parsing should be mtime-cached (same pattern as subagent scanning) to avoid re-reading unchanged files
- Only meaningful for today's active sessions; historical CLI tool data is not recoverable without this change being deployed while the session is live
