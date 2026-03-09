import Darwin
import Foundation


/// Spawns a Claude Code session under a hidden PTY for bidirectional communication.
/// Reads from the master fd to detect activity (triggering JSONL reloads).
/// Writes to the master fd to send user prompts.
public final class TTYBridge {
    private var masterFD: Int32 = -1
    private var process: Process?
    private var readSource: DispatchSourceRead?
    public private(set) var isAttached = false
    public private(set) var childPID: Int = 0
    private let logger: DebugLogging

    /// Called on the main queue when the PTY has output (Claude is responding).
    public var onActivity: (() -> Void)?

    /// Called on the main queue when the child process exits.
    public var onExit: ((Int32) -> Void)?

    public init(logger: DebugLogging = NullLogger()) {
        self.logger = logger
    }

    deinit {
        detach()
    }

    // MARK: - Lifecycle

    /// Spawn a fresh `claude` session under a hidden PTY.
    @discardableResult
    public func spawn(workingDir: String) -> Bool {
        return spawnProcess(arguments: [], workingDir: workingDir)
    }

    /// Spawn `claude --resume <sessionID>` under a hidden PTY.
    @discardableResult
    public func spawn(sessionID: String, workingDir: String) -> Bool {
        return spawnProcess(arguments: ["--resume", sessionID], workingDir: workingDir)
    }

    private func spawnProcess(arguments: [String], workingDir: String) -> Bool {
        guard !isAttached else { return true }

        var master: Int32 = 0
        var slave: Int32 = 0
        guard openpty(&master, &slave, nil, nil, nil) == 0 else { return false }

        var ws = winsize()
        ws.ws_col = 200
        ws.ws_row = 50
        _ = ioctl(master, TIOCSWINSZ, &ws)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/claude")
        proc.arguments = arguments
        proc.currentDirectoryURL = URL(fileURLWithPath: workingDir)

        // Strip Claude nesting-detection env vars so the child doesn't refuse to start
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDECODE")
        env.removeValue(forKey: "CLAUDE_CODE_ENTRYPOINT")
        proc.environment = env

        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        proc.standardInput = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError = slaveHandle

        do {
            try proc.run()
        } catch {
            close(master)
            close(slave)
            return false
        }

        close(slave)

        masterFD = master
        process = proc
        childPID = Int(proc.processIdentifier)

        // Monitor master fd for activity
        var trustHandled = false
        let source = DispatchSource.makeReadSource(fileDescriptor: master, queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self, self.masterFD >= 0 else { return }
            var buf = [UInt8](repeating: 0, count: 8192)
            let n = read(self.masterFD, &buf, buf.count)
            guard n > 0 else { return }

            let output = String(bytes: buf[0..<n], encoding: .utf8) ?? ""
            logger.log("read \(n)b: \(output.prefix(200).debugDescription)")

            // Auto-respond to "trust this folder" prompt
            if !trustHandled {
                if output.contains("trust") || output.contains("Yes,") {
                    "\r".data(using: .utf8)!.withUnsafeBytes { ptr in
                        _ = Darwin.write(self.masterFD, ptr.baseAddress!, ptr.count)
                    }
                    logger.log("auto-responded to trust prompt")
                    trustHandled = true
                    return
                }
                trustHandled = true
            }

            DispatchQueue.main.async { self.onActivity?() }
        }
        source.setCancelHandler { [master] in
            close(master)
        }
        source.resume()
        readSource = source

        let log = logger
        proc.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            let reason = proc.terminationReason
            log.log("process exited status=\(status) reason=\(reason.rawValue)")
            DispatchQueue.main.async {
                self?.onExit?(status)
                self?.isAttached = false
            }
        }

        isAttached = true
        let pid = childPID, fd = masterFD
        logger.log("spawned PID=\(pid) masterFD=\(fd) workingDir=\(workingDir)")
        return true
    }

    /// Stop the child process and clean up.
    public func detach() {
        let pid = childPID, running = process?.isRunning ?? false
        logger.log("detach called pid=\(pid) running=\(running)")
        readSource?.cancel()
        readSource = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        masterFD = -1
        childPID = 0
        isAttached = false
    }

    // MARK: - Communication

    /// Send text to Claude's stdin via the PTY master fd.
    /// Types each character individually then sends carriage return to submit
    /// (Claude's TUI uses raw terminal mode, not line-buffered).
    public func send(_ text: String) {
        guard isAttached, masterFD >= 0 else {
            let att = isAttached, fd = masterFD
            logger.log("send failed: isAttached=\(att) masterFD=\(fd)")
            return
        }
        let fd = masterFD, pid = childPID

        // Write the text as a bulk paste, then send Enter (\r) separately
        // The TUI receives the paste as input text, then \r triggers submit
        if let textData = text.data(using: .utf8) {
            textData.withUnsafeBytes { ptr in
                _ = Darwin.write(fd, ptr.baseAddress!, ptr.count)
            }
        }
        // Small delay between text and Enter so TUI processes the paste first
        usleep(50_000)
        var cr: UInt8 = 0x0D
        _ = Darwin.write(fd, &cr, 1)

        logger.log("send '\(text.prefix(50))' (\(text.utf8.count) chars + CR) masterFD=\(fd) childPID=\(pid)")
    }

    /// Send a raw string without appending newline (for permission responses like "y").
    public func sendRaw(_ text: String) {
        guard isAttached, masterFD >= 0,
              let data = text.data(using: .utf8)
        else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(masterFD, ptr.baseAddress!, ptr.count)
        }
    }
}
