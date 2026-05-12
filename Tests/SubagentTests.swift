import Foundation
import Testing
@testable import ClaudeUsageBarLib

@Suite("Subagents")
struct SubagentTests {

    private func makeTempDir() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubagentTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    private func writeJSONL(_ lines: [String], to dir: URL, name: String) throws {
        let content = lines.joined(separator: "\n")
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func assistantLine(msgID: String, model: String, input: Int, output: Int, cacheWrite: Int = 0, cacheRead: Int = 0) -> String {
        """
        {"type":"assistant","message":{"id":"\(msgID)","model":"\(model)","usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(cacheWrite),"cache_read_input_tokens":\(cacheRead)}}}
        """
    }

    // MARK: - JSONLParser.parseSubagents

    @Test("Empty directory returns empty map")
    func emptySubagentsDir() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = JSONLParser.parseSubagents(in: dir)
        #expect(result.isEmpty)
    }

    @Test("Single subagent file — correct per-model cost")
    func singleSubagentFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // 1M input + 1M output on Opus: $5 + $25 = $30
        try writeJSONL([
            assistantLine(msgID: "msg1", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-abc.jsonl")

        let result = JSONLParser.parseSubagents(in: dir)
        #expect(result.keys.count == 1)
        #expect(abs((result["Opus 4.6"]?.cost ?? 0) - 30.0) < 0.01)
    }

    @Test("Multiple subagent files — costs aggregated per model")
    func multipleSubagentFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Agent 1: Opus, 1M input + 1M output = $30
        try writeJSONL([
            assistantLine(msgID: "m1", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-1.jsonl")

        // Agent 2: Sonnet, 1M input + 1M output = $18
        try writeJSONL([
            assistantLine(msgID: "m2", model: "claude-sonnet-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-2.jsonl")

        // Agent 3: Also Opus, same cost = $30
        try writeJSONL([
            assistantLine(msgID: "m3", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-3.jsonl")

        let result = JSONLParser.parseSubagents(in: dir)
        #expect(result.keys.count == 2)
        // Opus: $30 + $30 = $60
        #expect(abs((result["Opus 4.6"]?.cost ?? 0) - 60.0) < 0.01)
        // Sonnet: $18
        #expect(abs((result["Sonnet 4.6"]?.cost ?? 0) - 18.0) < 0.01)
    }

    @Test("Duplicate message IDs — last entry wins (no double counting)")
    func duplicateMessageIDs() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Same message ID twice (streaming partial + final) — should count once
        try writeJSONL([
            assistantLine(msgID: "msg1", model: "claude-sonnet-4-6", input: 100, output: 50),
            assistantLine(msgID: "msg1", model: "claude-sonnet-4-6", input: 200, output: 100), // final wins
        ], to: dir, name: "agent-x.jsonl")

        let result = JSONLParser.parseSubagents(in: dir)
        // Only the last entry: 200 input + 100 output on Sonnet
        let expected = 200.0 * 3.0 / 1_000_000 + 100.0 * 15.0 / 1_000_000
        #expect(abs((result["Sonnet 4.6"]?.cost ?? 0) - expected) < 0.001)
    }

    @Test("Non-jsonl files are ignored")
    func nonJsonlFilesIgnored() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "some data".write(to: dir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        try writeJSONL([
            assistantLine(msgID: "m1", model: "claude-haiku-4-5-20251001", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-1.jsonl")

        let result = JSONLParser.parseSubagents(in: dir)
        #expect(result.keys.count == 1)
        #expect(result["Haiku 4.5"] != nil)
    }

    // MARK: - JSONLParser.parseSubagentDetails

    @Test("parseSubagentDetails — empty directory returns empty array")
    func parseDetailsEmptyDir() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(JSONLParser.parseSubagentDetails(in: dir).isEmpty)
    }

    @Test("parseSubagentDetails — returns one entry per file with correct model and cost")
    func parseDetailsSingleFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try writeJSONL([
            assistantLine(msgID: "m1", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-abc123.jsonl")

        let details = JSONLParser.parseSubagentDetails(in: dir)
        #expect(details.count == 1)
        #expect(details[0].agentID == "agent-abc123")
        #expect(details[0].model == "Opus 4.6")
        #expect(abs(details[0].cost - 30.0) < 0.01)
    }

    @Test("parseSubagentDetails — lastInputTokens reflects last message")
    func parseDetailsLastInputTokens() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Two messages — lastInputTokens should be from the second
        try writeJSONL([
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 10_000, output: 500),
            assistantLine(msgID: "m2", model: "claude-sonnet-4-6", input: 50_000, output: 1_000,
                         cacheWrite: 5_000, cacheRead: 20_000),
        ], to: dir, name: "agent-x.jsonl")

        let details = JSONLParser.parseSubagentDetails(in: dir)
        #expect(details.count == 1)
        // lastInputTokens = input + cacheWrite + cacheRead of last message = 50k + 5k + 20k = 75k
        #expect(details[0].lastInputTokens == 75_000)
    }

    @Test("parseSubagentDetails — multiple files sorted by cost descending")
    func parseDetailsMultipleFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Cheap agent: Haiku
        try writeJSONL([
            assistantLine(msgID: "m1", model: "claude-haiku-4-5-20251001", input: 100_000, output: 10_000)
        ], to: dir, name: "agent-cheap.jsonl")

        // Expensive agent: Opus
        try writeJSONL([
            assistantLine(msgID: "m2", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-expensive.jsonl")

        let details = JSONLParser.parseSubagentDetails(in: dir)
        #expect(details.count == 2)
        // Opus ($30) should come first (sorted by cost desc)
        #expect(details[0].model == "Opus 4.6")
        #expect(details[1].model == "Haiku 4.5")
    }

    // MARK: - SubagentContextBudget

    @Test("SubagentContextBudget token counts")
    func budgetTokens() {
        #expect(SubagentContextBudget.k200.tokens == 200_000)
        #expect(SubagentContextBudget.m1.tokens == 1_000_000)
    }

    @Test("SubagentContextBudget labels")
    func budgetLabels() {
        #expect(SubagentContextBudget.k200.label == "200K")
        #expect(SubagentContextBudget.m1.label == "1M")
    }

    // AppSettings persistence tests for subagentContextBudget are in AppSettingsTests.swift
    // (requires .serialized suite to avoid UserDefaults race conditions)

    // MARK: - JSONLParser.parseBareChildren

    private func bareUserLine(parentID: String, extra: String = "Some prompt") -> String {
        // JSON-encode the content to handle newlines correctly
        let content = "# spawned-by: \(parentID)\n\n\(extra)"
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return #"{"type":"user","entrypoint":"sdk-cli","message":{"role":"user","content":"\#(escaped)"}}"#
    }

    private func cliUserLine() -> String {
        #"{"type":"user","entrypoint":"cli","message":{"role":"user","content":"Hello"}}"#
    }

    @Test("parseBareChildren — bare session with matching parent ID is captured")
    func parseBareChildrenMatchingParent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"
        let bareID = "2687fd16-0000-0000-0000-000000000000"

        try writeJSONL([
            bareUserLine(parentID: parentID),
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 100_000, output: 10_000)
        ], to: dir, name: "\(bareID).jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.count == 1)
        #expect(results[0].agentID == bareID)
        #expect(results[0].sourceLabel == "Hook")
        #expect(results[0].model == "Sonnet 4.6")
    }

    @Test("parseBareChildren — session with different parent ID is excluded")
    func parseBareChildrenWrongParent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"
        let otherParent = "deadbeef-0000-0000-0000-000000000000"

        try writeJSONL([
            bareUserLine(parentID: otherParent),
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 100_000, output: 10_000)
        ], to: dir, name: "child-01.jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.isEmpty)
    }

    @Test("parseBareChildren — CLI session (not sdk-cli) is excluded")
    func parseBareChildrenCLISessionExcluded() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"

        try writeJSONL([
            cliUserLine(),
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 100_000, output: 10_000)
        ], to: dir, name: "main-session.jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.isEmpty)
    }

    @Test("parseBareChildren — parent session file is skipped")
    func parseBareChildrenSkipsParentFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"

        // Write a file with the parent's own ID — should be skipped
        try writeJSONL([
            bareUserLine(parentID: parentID),
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 100_000, output: 10_000)
        ], to: dir, name: "\(parentID).jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.isEmpty)
    }

    @Test("parseBareChildren — bare session with no assistant messages is skipped")
    func parseBareChildrenEmptySessionSkipped() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"

        try writeJSONL([
            bareUserLine(parentID: parentID)
            // no assistant lines — no usage
        ], to: dir, name: "empty-child.jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.isEmpty)
    }

    @Test("parseBareChildren — multiple bare children for same parent all captured")
    func parseBareChildrenMultipleChildren() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"

        try writeJSONL([
            bareUserLine(parentID: parentID),
            assistantLine(msgID: "m1", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "child-a.jsonl")

        try writeJSONL([
            bareUserLine(parentID: parentID),
            assistantLine(msgID: "m2", model: "claude-haiku-4-5-20251001", input: 500_000, output: 100_000)
        ], to: dir, name: "child-b.jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.count == 2)
        let ids = Set(results.map(\.agentID))
        #expect(ids.contains("child-a"))
        #expect(ids.contains("child-b"))
        #expect(results.allSatisfy { $0.sourceLabel == "Hook" })
    }

    @Test("parseBareChildren — queue-operation prefix lines before first user event are ignored")
    func parseBareChildrenWithQueueOperationPrefix() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"
        let queueEnqueue = #"{"type":"queue-operation","operation":"enqueue","timestamp":"2026-05-12T13:52:06.384Z","sessionId":"child-q","content":"..."}"#
        let queueDequeue = #"{"type":"queue-operation","operation":"dequeue","timestamp":"2026-05-12T13:52:06.386Z","sessionId":"child-q"}"#

        try writeJSONL([
            queueEnqueue,
            queueDequeue,
            bareUserLine(parentID: parentID),
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 50_000, output: 5_000)
        ], to: dir, name: "child-q.jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.count == 1)
        #expect(results[0].agentID == "child-q")
    }

    @Test("parseBareChildren — ai-title is captured as description")
    func parseBareChildrenAITitle() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let parentID = "ba4ea8bf-0000-0000-0000-000000000000"
        let titleLine = #"{"type":"ai-title","aiTitle":"Swift Frontmatter Correction","sessionId":"titled-child"}"#

        try writeJSONL([
            bareUserLine(parentID: parentID),
            titleLine,
            assistantLine(msgID: "m1", model: "claude-sonnet-4-6", input: 10_000, output: 1_000)
        ], to: dir, name: "titled-child.jsonl")

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: dir)
        #expect(results.count == 1)
        #expect(results[0].description == "Swift Frontmatter Correction")
    }

    @Test("parseBareChildren — real solid-coder session finds bare children (integration)")
    func parseBareChildrenRealData() throws {
        let projDir = URL(fileURLWithPath:
            "/Users/crowea/.claude/projects/-Users-crowea-Developer-Swift-Gurus-solid-coder")
        let parentID = "ba4ea8bf-57ad-4e40-bad0-f09aaaedc240"
        guard FileManager.default.fileExists(atPath: projDir.path),
              FileManager.default.fileExists(atPath: projDir.appendingPathComponent("\(parentID).jsonl").path)
        else { return }

        let results = JSONLParser.parseBareChildren(parentSessionID: parentID, in: projDir)
        #expect(results.count >= 2, "expected at least 2 bare children (ce89e1e4, 2687fd16)")
        #expect(results.allSatisfy { $0.sourceLabel == "Hook" })
        let ids = Set(results.map(\.agentID))
        #expect(ids.contains("2687fd16-33ff-4433-9197-249a79f550d1"))
        #expect(ids.contains("ce89e1e4-b5ca-4ac5-a7b2-c3db6807770c"))
    }

    // MARK: - UsageData.subagentsByModel

    @Test("UsageData reads .subagents.json and populates subagentsByModel")
    func usageDataReadsSubagentsFile() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("UsageDataSubagentTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let dayDir = tmp.appendingPathComponent(today)
        try FileManager.default.createDirectory(at: dayDir, withIntermediateDirectories: true)

        // Write .dat
        try "10.0 100 50 Opus 4.6".write(to: dayDir.appendingPathComponent("1234.dat"), atomically: true, encoding: .utf8)

        // Write .subagents.json
        let subagents: [String: SourceModelStats] = [
            "Opus 4.6": SourceModelStats(cost: 7.5, linesAdded: 0, linesRemoved: 0),
            "Sonnet 4.6": SourceModelStats(cost: 2.5, linesAdded: 0, linesRemoved: 0)
        ]
        let data = try JSONEncoder().encode(subagents)
        try data.write(to: dayDir.appendingPathComponent("1234.subagents.json"))

        let usageData = UsageData(testUsageDir: tmp)
        let subs = usageData.day.cli.subagentsByModel
        #expect(abs((subs["Opus 4.6"]?.cost ?? 0) - 7.5) < 0.001)
        #expect(abs((subs["Sonnet 4.6"]?.cost ?? 0) - 2.5) < 0.001)
    }
}
