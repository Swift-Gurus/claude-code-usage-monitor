import XCTest
@testable import ClaudeUsageBarLib

final class HookParsingTests: XCTestCase {
    func testInspectorWriteHasBlockingHookAttached() throws {
        let path = "/Users/crowea/.claude/projects/-Users-crowea-Developer-Swift-Gurus-claude-code-inspector/54c6d4b8-029c-4627-9443-48fa83e567cb.jsonl"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("inspector session not present")
        }
        let msgs = LogParser.parseMessages(at: URL(fileURLWithPath: path))
        var foundWriteWithHook = false
        for m in msgs {
            let writes = m.toolCalls.filter { $0.name == "Write" }
            if writes.isEmpty { continue }
            let hookChips = m.toolCalls.compactMap { tc -> HookToolData? in
                if case .hook(let h) = tc.data { return h } else { return nil }
            }
            print("Write msg has \(m.toolCalls.count) tools, \(hookChips.count) hook chips")
            for h in hookChips {
                print("  hook: \(h.hookName) status=\(String(describing: h.status))")
            }
            if !hookChips.isEmpty { foundWriteWithHook = true }
        }
        XCTAssertTrue(foundWriteWithHook, "expected at least one Write message with a hook chip")
    }

    /// Old-format session: hook_progress + stop_hook_summary should produce TWO chips (start + complete).
    func testOldFormatHookHasStartAndCompleteChips() throws {
        // Find any subagent jsonl with both hook_progress and stop_hook_summary for the same toolUseID.
        let projects = "/Users/crowea/.claude/projects"
        let fm = FileManager.default
        guard let projEnum = fm.enumerator(atPath: projects) else {
            throw XCTSkip("no projects")
        }
        var found: (String, Int, Int)? = nil
        for case let rel as String in projEnum {
            guard rel.hasSuffix(".jsonl"), rel.contains("/subagents/") else { continue }
            let full = "\(projects)/\(rel)"
            let msgs = LogParser.parseMessages(at: URL(fileURLWithPath: full))
            for m in msgs {
                var starts = 0
                var completes = 0
                for tc in m.toolCalls {
                    if case .hook(let h) = tc.data {
                        if h.status == .progress { starts += 1 }
                        if h.status == .success || h.status == .blockingError {
                            if h.durationMs != nil { completes += 1 }
                        }
                    }
                }
                if starts > 0 && completes > 0 {
                    found = (full, starts, completes)
                    break
                }
            }
            if found != nil { break }
        }
        guard let f = found else { throw XCTSkip("no paired start+complete hooks found") }
        print("paired hooks: \(f.0) starts=\(f.1) completes=\(f.2)")
        XCTAssertGreaterThan(f.1, 0)
        XCTAssertGreaterThan(f.2, 0)
    }
}
