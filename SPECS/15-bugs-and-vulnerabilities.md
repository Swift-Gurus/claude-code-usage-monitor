# SPEC 15: Bugs & Vulnerabilities

This file documents all known bugs, security vulnerabilities, and race conditions
identified through code review. Each issue includes severity, affected file(s), a
description of the problem, and a recommended fix.

Severity scale: **Critical** > **High** > **Medium** > **Low**

---

## Issue 1: Shell injection in statusline JSON heredoc

**Severity:** Critical
**Category:** Security
**File:** `Sources/StatuslineInstaller.swift:12-37`, `Sources/Resources/statusline-command.sh:130-132`

**Description:** The tracking snippet constructs a JSON object via shell string
interpolation inside a heredoc:

```bash
cat > "$_CUB_DIR/$_CUB_TODAY/$PPID.agent.json.tmp" <<AGENTEOF
{"pid":$PPID,"model":"$MODEL","agent_name":"$AGENT_NAME",...,"working_dir":"$DIR",...}
AGENTEOF
```

The values `$MODEL`, `$AGENT_NAME`, `$DIR`, and `$SESSION_ID` are extracted via
`jq -r` and interpolated unescaped. If any value contains a double-quote (`"`),
backslash, or newline, it will:
1. Break the JSON output, causing downstream decoding failures.
2. Allow a crafted `working_dir` or `agent_name` to inject arbitrary keys or values
   into the `.agent.json` file.

**Fix:** Use `jq` to construct the output JSON object directly instead of string
interpolation:
```bash
echo "$input" | jq '{pid: (env.PPID|tonumber), model: .model.display_name, ...}' > "$file.tmp"
```
Alternatively, pipe each value through `jq -R -s` to escape before interpolation.

---

## Issue 2: Auto-trust bypasses Claude Code security prompt

**Severity:** High
**Category:** Security
**File:** `Sources/TTYBridge.swift:98-109`

**Description:** TTYBridge automatically sends a carriage return (`\r`) when it
detects the words "trust" or "Yes," in PTY output:

```swift
if output.contains("trust") || output.contains("Yes,") {
    "\r".data(using: .utf8)!.withUnsafeBytes { ptr in
        _ = Darwin.write(self.masterFD, ptr.baseAddress!, ptr.count)
    }
}
```

This auto-approves Claude Code's "Do you trust this project folder?" security prompt
without user interaction. The pattern matching is extremely loose — any PTY output
containing the word "trust" (even in code, comments, or file content) triggers it.

**Fix:** Remove the auto-trust behavior entirely and let users confirm via the TTY.
If auto-trust is desired, require an explicit user opt-in via settings and use a much
more specific pattern match (e.g., the exact Claude prompt string).

---

## Issue 3: TTYBridge thread-unsafe mutable state

**Severity:** High
**Category:** Race Condition
**File:** `Sources/TTYBridge.swift:9-150`

**Description:** `TTYBridge` is a plain class with mutable properties (`masterFD`,
`isAttached`, `process`, `readSource`, `childPID`) accessed from multiple threads
without synchronization:

- `masterFD` is read in the `DispatchSource` event handler (background queue) and
  `send()` (potentially any thread).
- `isAttached` is set to `true` on the calling thread of `spawn()`, set to `false`
  on main queue in the termination handler, and read in `send()` and `detach()`.
- `detach()` sets `masterFD = -1` while the dispatch source event handler may
  concurrently read it and call `Darwin.read()` on the now-closed fd.

**Fix:** Convert `TTYBridge` to an actor, or protect all mutable state with
`os_unfair_lock`. Ensure `detach()` cancels the dispatch source and waits for
in-flight handlers to complete before closing the fd.

---

## Issue 4: Use-after-free in FSEvents callback

**Severity:** High
**Category:** Memory Safety
**File:** `Sources/UsageMonitor.swift:31-35`

**Description:** The FSEvents callback captures `self` via
`Unmanaged.passUnretained(self)`. If `UsageMonitor` is deallocated while the stream
is still dispatching events, `takeUnretainedValue()` dereferences a dangling pointer.

```swift
context.info = Unmanaged.passUnretained(self).toOpaque()
// ...
let monitor = Unmanaged<UsageMonitor>.fromOpaque(info).takeUnretainedValue()
```

Although `deinit` calls `stopFSEvents()`, a callback may already be queued on
`DispatchQueue.main.async` before `stopFSEvents` runs.

**Fix:** Use `Unmanaged.passRetained(self)` to hold a strong reference, and release
it in `stopFSEvents()`. Alternatively, use a weak-reference wrapper pattern in the
async dispatch.

---

## Issue 5: AgentTracker cache race condition

**Severity:** High
**Category:** Race Condition
**File:** `Sources/AgentTracker.swift:265-291`

**Description:** `AgentTracker` has `subagentCache` and `parentToolCache` dictionaries
written on `subagentQueue` (background) but potentially readable from the main thread
when `reload()` is called concurrently. The `@Observable` pattern does not provide
thread safety.

```swift
subagentQueue.async { [weak self] in
    self?.writeSubagentFiles(agents: agentsSnapshot, todayStr: todayStr)
}
// Inside writeSubagentFiles — background queue:
guard subagentCache[agent.sessionID]?.mtime != maxMtime else { continue }
subagentCache[agent.sessionID] = (mtime: maxMtime, stats: stats)
```

**Fix:** Make `AgentTracker` `@MainActor`-isolated, performing only file I/O on
background queues and returning results to main for state mutation. Alternatively,
ensure all cache access is confined to `subagentQueue`.

---

## Issue 6: SessionScanner unsynchronized static cache

**Severity:** High
**Category:** Race Condition
**File:** `Sources/Commander/SessionScanner.swift:25-66`

**Description:** `cachedSessions` and `cacheTime` are `static var` on a
non-thread-safe enum. `findActiveSessions()` can be called from multiple threads
simultaneously, leading to concurrent reads and writes:

```swift
private static var cachedSessions: [ActiveSession] = []
private static var cacheTime: Date = .distantPast
```

**Fix:** Protect the cache with a serial `DispatchQueue`, `os_unfair_lock`, or
convert to an actor. Alternatively, enforce single-thread access by documenting and
guarding that `findActiveSessions()` is only called from one specific queue.

---

## Issue 7: `refreshInFlight` data race

**Severity:** High
**Category:** Race Condition
**File:** `Sources/App/ClaudeUsageBarApp.swift:80-101`

**Description:** `refreshInFlight` is read/written from both the main actor context
(in `scheduleRefresh()`) and from `refreshQueue.async`. Additionally,
`togglePopover`/`toggleWindow` dispatch independent refreshes to
`DispatchQueue.global(qos: .userInitiated)`, bypassing the `refreshInFlight` guard
entirely.

**Fix:** Route all refresh logic through a single serial queue, or use
`refreshInFlight` consistently across all refresh paths. Ensure the flag is only
accessed from the main thread.

---

## Issue 8: `@Observable` UsageData mutated off main thread

**Severity:** Medium
**Category:** Race Condition
**File:** `Sources/UsageData.swift:60-173`

**Description:** `UsageData` is `@Observable` and its `reload()` method mutates
`day`, `week`, `month`, `modelHistories`, and `subagentStats`. `reload()` is called
from `DispatchQueue.global(qos: .userInitiated)` while SwiftUI may be reading the
properties concurrently. `@Observable` does not provide thread safety.

**Fix:** Compute results on a background thread but assign to published properties
only on the main thread. Or mark the class `@MainActor`.

---

## Issue 9: `waitUntilExit()` with no timeout can freeze UI

**Severity:** Medium
**Category:** Bug / Availability
**File:** `Sources/Commander/SessionScanner.swift:205`, `Sources/AgentTracker.swift:365`

**Description:** `runCommand` calls `process.waitUntilExit()` with no timeout. If
`ps` or `lsof` hangs (e.g., stuck NFS mount), the calling thread blocks indefinitely.
Since this can be called from the refresh path, it can freeze the app.

**Fix:** Add a timeout — for example, use `DispatchQueue.asyncAfter` to terminate
the process if it hasn't exited within 5 seconds:
```swift
DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
    if process.isRunning { process.terminate() }
}
```

---

## Issue 10: Unbounded memory for large JSONL files

**Severity:** Medium
**Category:** Bug / Denial of Service
**File:** `Sources/Commander/JSONLParser.swift:162-163` (+ 4 more sites)

**Description:** Entire JSONL files are read into memory as `Data`, converted to
`String`, then split into lines — up to 3x the file size in memory. Long-running
sessions can produce JSONL files of hundreds of megabytes, potentially causing the
menu bar app to be killed by the OS.

Affected call sites: `parseSession`, `parseParentTools`, `parseSubagents`,
`parseSubagentDetails`, `parseSubagentMeta`.

**Fix:** Use streaming/line-by-line reading via `FileHandle`, or set a maximum file
size before reading (e.g., skip files larger than 100 MB).

---

## Issue 11: Hardcoded claude executable path

**Severity:** Medium
**Category:** Bug
**File:** `Sources/TTYBridge.swift:57`

**Description:** The claude path is hardcoded to `/opt/homebrew/bin/claude`:
```swift
proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/claude")
```

This fails on Intel Macs (`/usr/local/bin`), npm/nvm installs, and any
non-Homebrew installation.

**Fix:** Use `Process` with `/usr/bin/env` to resolve `claude` from `$PATH`, or
search common locations at runtime, or use `which claude`.

---

## Issue 12: settings.json round-trip may lose data

**Severity:** Medium
**Category:** Bug
**File:** `Sources/StatuslineInstaller.swift:206-227`

**Description:** `installFreshScript()` reads `settings.json`, parses it with
`JSONSerialization`, overwrites the `statusLine` key, and writes it back.

1. If `settings.json` contains JSON5 features (comments, trailing commas),
   `JSONSerialization` will fail to parse or strip them silently.
2. Re-serialization reorders keys and changes formatting.
3. No file locking — concurrent writes by Claude Code or another instance can cause
   data loss (TOCTOU race).

**Fix:** Use atomic read-modify-write with `NSFileCoordinator`, or perform a minimal
text-level edit instead of a full JSON round-trip. Document that the operation may
strip comments.

---

## Issue 13: Script injection without robust validation

**Severity:** Medium
**Category:** Security
**File:** `Sources/StatuslineInstaller.swift:151-182`

**Description:** `injectTracking(into:)` modifies a user's existing shell script by
searching for `input=$(cat)` and inserting the tracking snippet. Problems:

1. The search may match inside a comment, string literal, or heredoc.
2. The fallback prepends `input=$(cat)` plus the snippet, changing script semantics.
3. If the script path is a symlink to a shared location, the injection modifies the
   shared file.

**Fix:** Check that the script is not a symlink to a location outside `~/.claude/`.
Use a more robust insertion strategy (e.g., verify `input=$(cat)` appears at the
top level). Consider adding a sentinel comment to avoid double-injection.

---

## Issue 14: No validation on `.dat` file values

**Severity:** Medium
**Category:** Data Integrity
**File:** `Sources/UsageData.swift:334-343`

**Description:** `.dat` file parsing accepts any numeric value without range
validation. `NaN`, `Inf`, or extremely large negative values from malformed or
tampered files propagate through cost calculations.

```swift
let cost = Double(parts.first ?? "0") ?? 0
let la = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
```

**Fix:** Clamp values: `max(0, cost)`, `max(0, la)`, `max(0, lr)`. Reject
non-finite values: `cost.isFinite ? cost : 0`.

---

## Issue 15: Force-unwrap on calendar date computation

**Severity:** Medium
**Category:** Bug
**File:** `Sources/UsageData.swift:110-111`

**Description:** `calendar.date(byAdding:)` and `calendar.date(from:)` return
optionals that are force-unwrapped:

```swift
let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
```

While unlikely to fail for typical calendar systems, these will crash in edge cases.

**Fix:** Use `guard let` with a fallback or early return.

---

## Issue 16: SessionManager not @MainActor-isolated

**Severity:** Medium
**Category:** Race Condition
**File:** `Sources/SessionManager.swift`

**Description:** `SessionManager` is `@Observable` with implicit thread-safety
relying on TTYBridge dispatching `onExit` on the main queue. If TTYBridge changes
its dispatch behavior, `sessions` dictionary mutations will silently race.

**Fix:** Mark `SessionManager` as `@MainActor` to make the thread-safety requirement
explicit and compiler-enforced.

---

## Issue 17: PID reuse TOCTOU in cleanup

**Severity:** Medium
**Category:** Security / Race Condition
**File:** `Sources/Commander/CommanderSupport.swift:80`, `Sources/AgentTracker.swift:159`

**Description:** `kill(pid, 0)` checks process liveness, but between the check and
subsequent use, the PID can be reused by a different process.
`CommanderSupport.cleanupDeadPIDs` only uses `kill()` — it doesn't verify the new
process is actually `claude`, unlike `AgentTracker.verifyClaudePIDs`.

**Fix:** Use the `verifyClaudePIDs` approach (checking `ps` output for "claude")
in `CommanderSupport.cleanupDeadPIDs` as well.

---

## Issue 18: Fragile model ID matching depends on iteration order

**Severity:** Low
**Category:** Bug
**File:** `Sources/Commander/JSONLParser.swift:95`

**Description:** The `.sonnet4` pattern `"sonnet-4-"` matches `"sonnet-4-5"` and
`"sonnet-4-6"` as substrings. It only works because `.sonnet4_6` and `.sonnet4_5`
are checked first via `CaseIterable` iteration order, which is not formally
guaranteed by the Swift specification.

**Fix:** Use a more specific pattern that won't match versioned variants, or
implement an explicit priority-ordered matching strategy.

---

## Issue 19: Dead code in parseSubagentMeta first pass

**Severity:** Low
**Category:** Code Quality
**File:** `Sources/Commander/JSONLParser.swift:427-444`

**Description:** The first pass of `parseSubagentMeta` iterates all lines, decodes
items, and extracts tool calls, but discards the result with `_ = tc`. This is
dead code that wastes CPU on every subagent scan.

**Fix:** Remove the first pass entirely. Combine the second and third passes into a
single pass.

---

## Issue 20: No PID range validation before kill()

**Severity:** Low
**Category:** Bug
**File:** `Sources/AgentTracker.swift:159`

**Description:** `json.pid` is an `Int` decoded from JSON. If it contains a negative
value or exceeds `Int32.max`, the `Int32()` conversion truncates or wraps.
`kill(-1, 0)` signals all processes the user can signal; `kill(0, 0)` signals the
process group.

**Fix:** Validate `json.pid > 0 && json.pid <= Int(Int32.max)` before calling `kill`.

---

## Issue 21: Symlink following in directory cleanup

**Severity:** Low
**Category:** Security
**File:** `Sources/Commander/CommanderSupport.swift:64-68`

**Description:** `cleanupOldData` deletes directories under
`~/.claude/usage/commander/` whose names parse as dates older than 3 months. If a
symlink with a date-like name is placed there, `removeItem(at:)` follows the symlink
and deletes the target.

**Fix:** Check that the URL is a real directory (not a symlink) using
`URLResourceValues` with `.isSymbolicLinkKey` before removing.

---

## Issue 22: Script path extraction doesn't handle spaces

**Severity:** Low
**Category:** Bug
**File:** `Sources/StatuslineInstaller.swift:94-109`

**Description:** `currentScriptPath()` splits the `command` string on spaces to find
the `.sh` path. Quoted paths with spaces (e.g., `"/Users/John Doe/script.sh"`) are
not handled — only the last fragment is returned.

**Fix:** Use a proper shell argument parser, or handle quoted paths. Alternatively,
document that script paths with spaces are unsupported.

---

## Issue 23: Force unwrap in debug logger

**Severity:** Low
**Category:** Bug
**File:** `Sources/DebugLogger.swift:27`

**Description:** `handle.write(line.data(using: .utf8)!)` force-unwraps in a logging
utility. While Swift String → UTF-8 should never fail, a crash in the logger itself
would be difficult to diagnose.

**Fix:** Use `guard let data = line.data(using: .utf8) else { return }`.

---

## Issue 24: `usleep` blocks main thread in TTYBridge.send()

**Severity:** Low
**Category:** Code Quality
**File:** `Sources/TTYBridge.swift:173`

**Description:** `send()` calls `usleep(50_000)` (50ms) between writing text and
sending a carriage return. If called from the main thread (via `LogViewerView`),
this blocks the UI for 50ms.

**Fix:** Dispatch the write + CR to a background queue, or use
`DispatchQueue.asyncAfter` for the delayed CR.

---

## Summary Table

| # | Severity | Category | File | Issue |
|---|----------|----------|------|-------|
| 1 | Critical | Security | StatuslineInstaller / statusline-command.sh | Shell injection in JSON heredoc |
| 2 | High | Security | TTYBridge.swift | Auto-trust bypasses security prompt |
| 3 | High | Race Condition | TTYBridge.swift | Thread-unsafe mutable state |
| 4 | High | Memory Safety | UsageMonitor.swift | Use-after-free in FSEvents callback |
| 5 | High | Race Condition | AgentTracker.swift | Unsynchronized cache access across queues |
| 6 | High | Race Condition | SessionScanner.swift | Unsynchronized static cache |
| 7 | High | Race Condition | ClaudeUsageBarApp.swift | `refreshInFlight` data race |
| 8 | Medium | Race Condition | UsageData.swift | `@Observable` mutated off main thread |
| 9 | Medium | Bug | SessionScanner / AgentTracker | `waitUntilExit()` no timeout |
| 10 | Medium | Bug / DoS | JSONLParser.swift | Unbounded memory for large JSONL files |
| 11 | Medium | Bug | TTYBridge.swift | Hardcoded `/opt/homebrew/bin/claude` path |
| 12 | Medium | Bug | StatuslineInstaller.swift | settings.json round-trip loses data |
| 13 | Medium | Security | StatuslineInstaller.swift | Script injection without validation |
| 14 | Medium | Data Integrity | UsageData.swift | No validation on `.dat` file values |
| 15 | Medium | Bug | UsageData.swift | Force-unwrap on calendar computation |
| 16 | Medium | Race Condition | SessionManager.swift | Not `@MainActor`-isolated |
| 17 | Medium | Security | CommanderSupport / AgentTracker | PID reuse TOCTOU in cleanup |
| 18 | Low | Bug | JSONLParser.swift | Model ID matching depends on iteration order |
| 19 | Low | Code Quality | JSONLParser.swift | Dead code in `parseSubagentMeta` |
| 20 | Low | Bug | AgentTracker.swift | No PID range validation before `kill()` |
| 21 | Low | Security | CommanderSupport.swift | Symlink following in cleanup |
| 22 | Low | Bug | StatuslineInstaller.swift | Script path doesn't handle spaces |
| 23 | Low | Bug | DebugLogger.swift | Force unwrap in logger |
| 24 | Low | Code Quality | TTYBridge.swift | `usleep` blocks main thread |
