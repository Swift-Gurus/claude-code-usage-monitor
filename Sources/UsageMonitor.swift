import CoreServices
import Foundation

public final class UsageMonitor {
    private var stream: FSEventStreamRef?
    private var pollTimer: Timer?
    private let onChange: () -> Void
    private var watchedPaths: [String]

    public init(accounts: [Account] = [.default], onChange: @escaping () -> Void) {
        self.onChange = onChange
        self.watchedPaths = accounts.map { $0.usageDir.path }
        startFSEvents()
        startPolling()
    }

    deinit {
        stopFSEvents()
        pollTimer?.invalidate()
    }

    /// Update watched paths when accounts change. Recreates the FSEvents stream.
    public func updateAccounts(_ accounts: [Account]) {
        let newPaths = accounts.map { $0.usageDir.path }
        guard newPaths != watchedPaths else { return }
        watchedPaths = newPaths
        stopFSEvents()
        startFSEvents()
    }

    // MARK: - FSEvents (for terminal sessions writing to usage directories)

    private func startFSEvents() {
        // Ensure directories exist so FSEvents can watch them
        for path in watchedPaths {
            try? FileManager.default.createDirectory(
                atPath: path, withIntermediateDirectories: true
            )
        }

        guard !watchedPaths.isEmpty else { return }

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
            watchedPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0, // 2s latency — batches rapid writes to reduce reload frequency
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
