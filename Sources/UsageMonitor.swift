import CoreServices
import Foundation

public final class UsageMonitor {
    private var stream: FSEventStreamRef?
    private var pollTimer: Timer?
    private let onChange: () -> Void

    public init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        startFSEvents()
        startPolling()
    }

    deinit {
        stopFSEvents()
        pollTimer?.invalidate()
    }

    // MARK: - FSEvents (for terminal sessions writing to ~/.claude/usage/)

    private func startFSEvents() {
        let usageDir = NSHomeDirectory() + "/.claude/usage"

        // Ensure directory exists so FSEvents can watch it
        try? FileManager.default.createDirectory(
            atPath: usageDir, withIntermediateDirectories: true
        )

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let monitor = Unmanaged<UsageMonitor>.fromOpaque(info).takeUnretainedValue()
            // Defer to next run loop iteration to avoid re-entrant layout cycles
            // when SwiftUI's NSHostingView is mid-display-cycle
            DispatchQueue.main.async {
                monitor.onChange()
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [usageDir] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // 500ms latency — fires quickly after writes
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    private func stopFSEvents() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    // MARK: - Polling (for Commander/pipe-mode sessions that don't write to usage/)

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            // Defer to next run loop iteration to avoid re-entrant layout cycles
            DispatchQueue.main.async {
                self?.onChange()
            }
        }
    }
}
