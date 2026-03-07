# Threading Model Specification

## Overview

ClaudeUsageBar uses a hybrid threading model: all `@Observable` state mutations and UI operations happen on the main thread, while expensive I/O (process scanning, JSONL file reads) happens on a background thread. The design is deliberately asymmetric — writes to `@Observable` properties are always main-thread, but the background work that feeds those writes is dispatched explicitly.

---

## Main Thread (@MainActor) Operations

The following always run on the main thread:

- All mutations to `@Observable` properties (`usageData.day/week/month`, `agentTracker.activeAgents`, `settings.*`)
- All `NSStatusItem` operations (title update, button configuration)
- All `NSPopover` operations (show, performClose, delegate callbacks)
- `AppDelegate` itself is `@MainActor` — every method on it runs on the main thread
- `observeSettings()` — `withObservationTracking` subscriptions are registered and re-subscribed on the main thread
- `updateStatusItemTitle()` — reads `settings.statusBarPeriod` and `usageData.*`, writes `button.title`
- `UsageData.reload()` — all `@Observable` property writes (`day`, `week`, `month`) happen here, on main
- `AgentTracker.reload()` — all `activeAgents` writes happen here, on main

---

## Background Thread Operations

The following run on a background thread, explicitly dispatched in `togglePopover()`:

- `CommanderSupport.refreshFiles()` — the entire flow: `cleanupDeadPIDs`, `cleanupOldData`, `writeAgentData`
  - `SessionScanner.findActiveSessions()` — spawns `/bin/ps` and `/usr/sbin/lsof` via `Process`
  - `JSONLParser.parseSession()` — reads JSONL file from disk via `Data(contentsOf:)`
  - Writing `.dat` and `.agent.json` files to `~/.claude/usage/commander/YYYY-MM-DD/`

The background work is dispatched via:

```swift
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    guard let self else { return }
    CommanderSupport.refreshFiles()
    DispatchQueue.main.async {
        self.usageData.reload()
        self.agentTracker.reload()
        self.updateStatusItemTitle()
        self.settings.isLoading = false
    }
}
```

This pattern ensures:
1. `refreshFiles()` (the slow I/O and process spawning) does not block the main thread
2. All `@Observable` mutations still happen on the main thread, inside the nested `DispatchQueue.main.async`

---

## DispatchQueue.global(qos: .userInitiated).async in toggleUI

When the user clicks the status bar icon, `toggleUI()` dispatches to either `togglePopover()` or `toggleWindow()` based on `settings.displayMode`:

**Popover mode** (`togglePopover()`):
1. `settings.isLoading = true` is set immediately on the main thread (shows a loading indicator in the popover)
2. The popover is shown immediately with potentially stale data — the UI is responsive at once
3. A `DispatchQueue.global(qos: .userInitiated).async` block is dispatched for the heavy work
4. When `refreshFiles()` completes, a nested `DispatchQueue.main.async` dispatches the reload and UI update back to main

**Window mode** (`toggleWindow()`):
1. If the window is visible, `window.orderOut(nil)` hides it
2. If the window is not visible: `settings.isLoading = true`, `window.orderFront(nil)`, `NSApp.activate(ignoringOtherApps: true)`, then the same background refresh pattern as popover mode

The `.userInitiated` QoS signals to the OS that this work is in direct response to a user action and should be prioritized accordingly.

---

## DispatchQueue.main.async for FSEvents and Timer Callbacks

Both the FSEvents callback and the Timer callback use `DispatchQueue.main.async` to defer `onChange()` to the next run loop iteration:

**FSEvents callback (in `UsageMonitor.startFSEvents`):**
```swift
let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
    guard let info else { return }
    let monitor = Unmanaged<UsageMonitor>.fromOpaque(info).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.onChange()
    }
}
```

**Timer callback (in `UsageMonitor.startPolling`):**
```swift
pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
    DispatchQueue.main.async {
        self?.onChange()
    }
}
```

### Why This Deferral Is Critical

Without `DispatchQueue.main.async`, `onChange()` can be called while SwiftUI's `NSHostingView` is in the middle of a layout or display cycle. Calling `reload()` from inside a layout pass triggers re-entrant layout, which caused crashes in the original `MenuBarExtra`-based implementation. The `DispatchQueue.main.async` defers the call to the next run loop iteration — after the current layout cycle completes — preventing the re-entrant crash.

This is not a performance optimization; it is a correctness requirement. Both the FSEvents callback and the Timer callback wrap their `onChange()` call in `DispatchQueue.main.async` for this reason.

---

## withObservationTracking Pattern for Settings

`AppDelegate.observeSettings()` uses the `withObservationTracking` API to observe `AppSettings.statusBarPeriod` changes and update the status bar title:

```swift
private func observeSettings() {
    withObservationTracking {
        _ = self.settings.statusBarPeriod
    } onChange: { [weak self] in
        Task { @MainActor in
            self?.updateStatusItemTitle()
            self?.observeSettings()  // re-subscribe for the next change
        }
    }
}
```

### Re-subscription Requirement

`withObservationTracking` fires its `onChange` closure exactly once per registration. After the closure fires, the tracking is consumed. To continue observing future changes, `observeSettings()` must call itself recursively at the end of the `onChange` closure. This re-subscribes for the next change before returning.

The `Task { @MainActor in ... }` wrapper ensures the recursive call and `updateStatusItemTitle()` execute on the main actor, even though the `onChange` closure itself may fire on any thread.

---

## Why NSStatusItem + NSPopover/NSPanel Replaced MenuBarExtra

The app originally used SwiftUI's `MenuBarExtra` scene for the menu bar presence. This was replaced with a manual `NSStatusItem` + `NSPopover` (or `NSPanel` in window mode) setup.

### The Re-entrant NSHostingView Crash

`MenuBarExtra` uses SwiftUI's own `NSHostingView` internally. When `@Observable` state changes trigger re-renders, SwiftUI may attempt a layout pass on the `NSHostingView` while it is already in a layout or display cycle (triggered by the same state change). This causes a re-entrant layout cycle that crashes.

The crash manifested specifically when `UsageMonitor.onChange()` was called from an FSEvents or Timer callback while the menu bar popover was visible — the callback triggered `reload()`, which mutated `@Observable` properties, which triggered SwiftUI's change propagation, which called into `NSHostingView.layout()` recursively.

### The Fix

By managing `NSStatusItem` and `NSPopover` manually via `AppDelegate`, the app controls exactly when `NSHostingView` receives layout requests. The `DispatchQueue.main.async` deferral in the FSEvents and Timer callbacks ensures `onChange()` is never called during an active layout cycle.

`NSHostingController` (used inside `NSPopover`) is more resilient than the `MenuBarExtra`-embedded `NSHostingView` because the popover lifecycle (show/hide) is explicitly managed, not tied to the SwiftUI scene lifecycle.

---

## NSPopoverDelegate.popoverDidShow makeKey()

```swift
extension AppDelegate: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        popover.contentViewController?.view.window?.makeKey()
    }
}
```

After the popover is shown, `makeKey()` is called on its window. Without this, the popover window is visible but does not become the key window. Keyboard events (e.g., arrow keys in list views, text field input in settings) would go to whichever window was key before the popover opened — typically nothing, since menu bar apps have no regular windows. Calling `makeKey()` ensures the popover window accepts keyboard input immediately after opening.

This is called in `popoverDidShow` (after the popover is fully presented) rather than immediately after `popover.show(...)` to ensure the window exists at call time.

---

## Thread Safety of File Writes

All file write operations follow a consistent pattern to minimize race conditions:

| File type | Writer | Write method | Atomicity |
|-----------|--------|--------------|-----------|
| `.dat` | `CommanderSupport.writeAgentData` (background) | `String.write(atomically: true, ...)` | Atomic (temp + rename) |
| `.agent.json` | `CommanderSupport.writeAgentData` (background) | `Data.write(options: .atomic)` | Atomic (temp + rename) |
| `.agent.json` | `statusline-command.sh` (shell, external) | `cat > .tmp && mv` | Atomic (manual temp + rename) |
| `.subagents.json` | `AgentTracker.writeSubagentFiles` (subagentQueue) | `Data.write(options: .atomic)` | Atomic (temp + rename) |
| `.subagent-details.json` | `AgentTracker.writeSubagentFiles` (subagentQueue) | `Data.write(options: .atomic)` | Atomic (temp + rename) |
| `.parent-tools.json` | `AgentTracker.writeSubagentFiles` (subagentQueue) | `Data.write(options: .atomic)` | Atomic (temp + rename) |

### Read/Write Ordering Guarantee

`CommanderSupport.refreshFiles()` always runs before `UsageData.reload()` and `AgentTracker.reload()`. This ordering is enforced in two places:

**In `setupMonitor()` (the `UsageMonitor` callback, triggered synchronously on main):**
```swift
monitor = UsageMonitor { [weak self] in
    guard let self else { return }
    CommanderSupport.refreshFiles()
    self.usageData.reload()
    self.agentTracker.reload()
    self.updateStatusItemTitle()
}
```

Note: In the monitor callback, `CommanderSupport.refreshFiles()` runs synchronously on the main thread (no background dispatch). The background dispatch is used only in `togglePopover()` where the responsiveness of the UI is critical. The monitor callback runs at 5-second intervals where a brief main-thread block is acceptable.

**In `togglePopover()` (user-initiated, background dispatch):**
`refreshFiles()` runs on the background thread; the `DispatchQueue.main.async` block that calls `reload()` is not dispatched until `refreshFiles()` returns.

This ordering guarantees `.dat` and `.agent.json` files exist in the commander directory before `UsageData` and `AgentTracker` attempt to read them.

---

## LogViewerView: Task.detached Polling with Mtime Cache

`LogViewerView.loadMessages()` uses `Task.detached(priority: .utility)` for file I/O, with mtime-based caching to skip re-parsing unchanged files:

```swift
private func loadMessages() async {
    let url = fileURL
    let cached = lastMtime
    let (msgs, mtime) = await Task.detached(priority: .utility) {
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

The polling loop is identical to `SubagentDetailView`: a `.task` modifier runs `loadMessages()` initially, then every 2 seconds. The mtime cache prevents re-reading the JSONL file on most polls when the file has not changed.

---

## SubagentDetailView: Task.detached Polling

`SubagentDetailView.loadFromFile()` uses `Task.detached(priority: .utility)` for file I/O, keeping the main thread free during JSON reads:

```swift
private func loadFromFile() async {
    let details = await Task.detached(priority: .utility) {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([SubagentInfo].self, from: data)
        else { return [SubagentInfo]() }
        return decoded
    }.value
    if !details.isEmpty { subagents = details }  // MainActor: @State mutation
}
```

The `.value` `await` suspends the calling task (attached to the view's `.task` modifier, which runs on the `MainActor`) until the detached work completes. The result is returned to the `MainActor` implicitly — the `subagents = details` assignment happens on the main thread because `SubagentDetailView` is a SwiftUI `View` and `@State` mutations are always on main.

**Polling loop:**

```swift
.task {
    await loadFromFile()
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2))
        await loadFromFile()
    }
}
```

- Polling interval: 2 seconds between each file read
- Task cancellation: SwiftUI cancels the `.task` automatically when the view disappears (standard `.task` lifetime semantics). `Task.isCancelled` is checked before each `loadFromFile()` call; `Task.sleep` also throws on cancellation (caught by `try?`), which exits the loop.
- Priority: `.utility` — lower than the default `.userInitiated` of the `.task` modifier itself. The detached task signals to the scheduler that this work is background I/O, not time-sensitive.

---

## AgentTracker: Main Thread + Background Queue

`AgentTracker.reload()` runs partially on the main thread and partially on a dedicated serial background queue:

**Main thread work:**
- The `kill(pid, 0)` liveness checks are synchronous main-thread syscalls (fast, no I/O)
- The `ps -p {pid} -o %cpu=` process spawn for CPU usage is a synchronous main-thread `Process.run()` + `waitUntilExit()` call
- JSONL mtime checks for idle detection (checking parent and subagent JSONL modification dates)
- With 1–3 agents, this is typically 3–6 `ps` invocations per `reload()`, each completing in under 10ms

**Background queue work** (`subagentQueue`, serial, `.utility` QoS):
- `writeSubagentFiles()` is dispatched to `subagentQueue.async` — it calls `JSONLParser.parseSubagents()`, `JSONLParser.parseSubagentMeta()`, and `JSONLParser.parseSubagentDetails()` which read JSONL files
- `@Observable` property mutations (`subagentDetails`, `parentToolCounts`) are dispatched back to `DispatchQueue.main.async`

The mtime cache in `writeSubagentFiles()` prevents JSONL rescanning on most calls, keeping the hot path fast.

---

## FSEvents and Timer: Both Defer via DispatchQueue.main.async

A summary of all callbacks that trigger `onChange()` and their threading:

| Source | Dispatch queue | `onChange()` called on | Notes |
|--------|---------------|----------------------|-------|
| FSEventStream | `.main` (via `FSEventStreamSetDispatchQueue(stream, .main)`) | Main (deferred) | `DispatchQueue.main.async` adds one run loop hop |
| Timer (`pollTimer`) | Main run loop | Main (deferred) | `DispatchQueue.main.async` adds one run loop hop |

Both already fire on the main thread (FSEvents via `FSEventStreamSetDispatchQueue(.main)`, Timer via `RunLoop.main`). The additional `DispatchQueue.main.async` inside each callback adds one run loop hop — deferring `onChange()` to after the current run loop iteration completes. This is the critical mechanism that prevents re-entrant `NSHostingView` layout.

Without the deferral, `onChange()` → `reload()` → `@Observable` mutation → SwiftUI layout notification would all happen synchronously within the same run loop iteration that may already be executing a layout pass.
