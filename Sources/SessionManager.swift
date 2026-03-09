import Foundation

/// Central registry of Claude Code sessions spawned by the app via PTY.
/// Shared across views so LogViewerView can check if it owns a session's input.
@Observable
public final class SessionManager {
    /// Active PTY bridges keyed by child PID.
    public var sessions: [Int: TTYBridge] = [:]
    private let logger: DebugLogging

    public init(logger: DebugLogging = NullLogger()) {
        self.logger = logger
    }

    /// Spawn a fresh `claude` session in the given directory.
    /// Returns the TTYBridge on success, nil on failure.
    @discardableResult
    public func spawn(workingDir: String) -> TTYBridge? {
        let bridge = TTYBridge(logger: logger)
        guard bridge.spawn(workingDir: workingDir) else { return nil }

        let pid = bridge.childPID
        sessions[pid] = bridge

        bridge.onExit = { [weak self] _ in
            self?.sessions.removeValue(forKey: pid)
        }

        return bridge
    }

    /// Get the bridge for a PID (if this app spawned it).
    public func bridge(for pid: Int) -> TTYBridge? {
        sessions[pid]
    }

    /// Clean up dead sessions.
    public func cleanup() {
        for (pid, bridge) in sessions where !bridge.isAttached {
            bridge.detach()
            sessions.removeValue(forKey: pid)
        }
    }

    /// Detach all sessions (called on app termination).
    public func detachAll() {
        for (_, bridge) in sessions {
            bridge.detach()
        }
        sessions.removeAll()
    }
}
