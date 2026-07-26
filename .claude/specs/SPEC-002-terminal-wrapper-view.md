---
number: SPEC-002
feature: terminal-wrapper-view
type: feature
status: draft
blocked-by: []
blocking: []
parent: ~
---

## Description

A generic SwiftUI terminal wrapper view (`TerminalView<VM: TerminalContract>`) backed by a protocol
`TerminalContract<Input, Output>` that abstracts the underlying terminal library. A concrete adapter
(e.g. `SwiftTermAdapter`) implements `TerminalContract` and wraps SwiftTerm's AppKit `TerminalView`
via `NSViewRepresentable`. `LogViewModel` conforms to `TerminalContract` acting as a mediator
façade — it holds an injected concrete adapter, delegates all protocol calls to it, and bridges
terminal events to the rest of the UI. `LogView` creates `TerminalView<LogViewModel>` and has no
knowledge of the underlying library. Resize is handled automatically by the `NSViewRepresentable`
frame mechanism (SwiftTerm overrides `setFrameSize` internally); explicit resize forwarding is only
needed if the library requires it.

## Input / Output

| Direction | Type | Format | Notes |
|-----------|------|--------|-------|
| In — send | `VM.Input` | Generic associated type | Data sent into the terminal (e.g. keystrokes, stdin bytes) |
| Out — receive | `VM.Output` | Generic associated type | Data/events emitted by the terminal (e.g. output bytes, delegate events) |
| In — resize | automatic | NSViewRepresentable frame | SwiftTerm handles via `setFrameSize`; no explicit protocol call needed unless library requires it |

## Architecture

```
Caller (scene / navigation)
  │ creates and injects adapter
  ▼
LogViewModel: TerminalContract<Input, Output>    ← mediator + protocol façade
  │ holds: adapter: any TerminalContract<Input, Output>
  │ delegates all protocol calls to adapter
  │ bridges output stream to LogView
  │ is held by
  ▼
LogView
  │ creates TerminalView<LogViewModel>
  ▼
TerminalView<VM: TerminalContract>               ← generic SwiftUI view
  │ wraps NSViewRepresentable container
  ▼
SwiftTermAdapter: TerminalContract               ← concrete implementation
  │ implements TerminalViewDelegate
  │ wraps
  ▼
SwiftTerm.TerminalView (NSView)                  ← actual renderer + input handler
```

## SwiftTerm Integration Notes

- `SwiftTerm.TerminalView` is an AppKit `NSView` → must be wrapped with `NSViewRepresentable`
- Resize is automatic: SwiftTerm overrides `setFrameSize`; AppKit layout propagates container frame
- `TerminalViewDelegate.send(source:data:ArraySlice<UInt8>)` → emitted when terminal produces output (bytes to forward to process / consumer)
- `SwiftTermAdapter` will conform to `TerminalViewDelegate` to capture these events and publish them as `Output`
- Input (e.g. sending data back to the terminal) is via `TerminalView.feed(byteArray:)` or `feed(text:)`

## Workflow

- Phase 1.1 Define `TerminalContract<Input, Output>` protocol
  - `associatedtype Input`
  - `associatedtype Output`
  - `func send(_ message: Input)` — send data into terminal
  - Observable/published output stream for `Output` events
  - Optional: `func resize(to size: CGSize)` — for libraries that require explicit size updates
- Phase 1.2 Define `TerminalView<VM: TerminalContract>` SwiftUI view
  - Init takes `vm: VM`
  - Embeds `NSViewRepresentable` for AppKit-based backends
  - Forwards `send` and output subscription to the VM
- Phase 1.3 Implement `SwiftTermAdapter: TerminalContract, TerminalViewDelegate`
  - Wraps `SwiftTerm.TerminalView` inside `NSViewRepresentable`
  - Routes delegate callbacks to the `Output` stream
  - Routes `send(_:)` to `SwiftTerm.TerminalView.feed(…)`
- Phase 1.4 Implement `LogViewModel: TerminalContract`
  - Holds `adapter: any TerminalContract<Input, Output>` (injected)
  - Delegates all `TerminalContract` calls to adapter
  - Publishes output to `LogView` via `@Published` / `@Observable`
- Phase 2.1 Update `LogView` to create `TerminalView<LogViewModel>`
- Phase 2.2 Wire input path — input view calls `logViewModel.send(_:)`
- Phase 3.1 Stub adapter for testing without SwiftTerm dependency
- Phase 3.2 Integration and unit tests

## Connects To

| Direction | Component | Notes |
|-----------|-----------|-------|
| Upstream | `LogView` | Creates `TerminalView`; passes `LogViewModel` as VM |
| Upstream | `LogViewModel` | Mediator façade; holds and bridges adapter |
| Upstream | Input view (TBD) | Calls `logViewModel.send(_:)` directly |
| Downstream | `SwiftTermAdapter` | Concrete `TerminalContract` wrapping SwiftTerm |
| Downstream | SwiftTerm `TerminalView` | AppKit renderer, embedded via `NSViewRepresentable` |

## Edge Cases

- Rapid resize events during live window drag — SwiftTerm handles internally; only debounce if custom resize forwarding is added
- `Input` / `Output` types unknown at spec time — kept as open associated types
- SwiftTerm `send` delegate callback is bytes, not structured events — adapter decides how to model `Output`
- Multiple subscribers to output stream — must be multicast-safe
- `NSViewRepresentable` lifecycle (`makeNSView` / `updateNSView`) must not re-create terminal on each SwiftUI redraw

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| `LogViewModel` conforms to `TerminalContract` (not just holds it) | Enables passing VM directly to `TerminalView<LogViewModel>`; VM is both mediator and protocol entry point |
| Separate `SwiftTermAdapter` | Keeps SwiftTerm details out of `LogViewModel`; easy to swap library |
| `NSViewRepresentable` inside `SwiftTermAdapter` | SwiftTerm is AppKit-only; wrapping at adapter level keeps the SwiftUI view library-agnostic |
| Resize via AppKit frame propagation (not explicit protocol) | SwiftTerm handles it internally; explicit resize only added if needed |

## Definition of Done

- [ ] `TerminalContract<Input, Output>` protocol defined
- [ ] `TerminalView<VM: TerminalContract>` SwiftUI view compiles
- [ ] `SwiftTermAdapter` wraps SwiftTerm and conforms to `TerminalContract` + `TerminalViewDelegate`
- [ ] `LogViewModel` conforms to `TerminalContract` and delegates to injected adapter
- [ ] `LogView` creates `TerminalView<LogViewModel>` without knowledge of SwiftTerm
- [ ] Terminal renders inside `LogView` without hardcoded dimensions
- [ ] Input view can call `logViewModel.send(_:)`
- [ ] Output events observable from `LogViewModel`
- [ ] Stub adapter enables testing without SwiftTerm
