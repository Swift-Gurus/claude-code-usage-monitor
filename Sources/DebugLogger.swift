import Foundation

/// Protocol for debug logging. Inject into components that need logging.
public protocol DebugLogging {
    func log(_ msg: String, category: String)
}

extension DebugLogging {
    public func log(_ msg: String) { log(msg, category: "General") }
}

/// File-based debug logger. Disabled by default.
public final class FileDebugLogger: DebugLogging {
    public var isEnabled = false

    private let path: String

    public init(path: String? = nil) {
        self.path = path ?? NSHomeDirectory() + "/.claude/usage/debug.log"
    }

    public func log(_ msg: String, category: String = "General") {
        guard isEnabled else { return }
        let line = "[\(Date())] [\(category)] \(msg)\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
        }
    }
}

/// No-op logger for when logging isn't needed.
public struct NullLogger: DebugLogging {
    public init() {}
    public func log(_ msg: String, category: String) {}
}
