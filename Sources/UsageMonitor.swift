import CoreServices
import Foundation

final class UsageMonitor {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        startFSEvents()
    }

    deinit {
        stopFSEvents()
    }

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
            monitor.onChange()
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
}
