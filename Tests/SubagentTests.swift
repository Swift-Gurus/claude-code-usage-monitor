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

        // 1M input + 1M output on Opus: $15 + $75 = $90
        try writeJSONL([
            assistantLine(msgID: "msg1", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-abc.jsonl")

        let result = JSONLParser.parseSubagents(in: dir)
        #expect(result.keys.count == 1)
        #expect(abs((result["Opus 4.6"]?.cost ?? 0) - 90.0) < 0.01)
    }

    @Test("Multiple subagent files — costs aggregated per model")
    func multipleSubagentFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Agent 1: Opus, 1M input + 1M output = $90
        try writeJSONL([
            assistantLine(msgID: "m1", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-1.jsonl")

        // Agent 2: Sonnet, 1M input + 1M output = $18
        try writeJSONL([
            assistantLine(msgID: "m2", model: "claude-sonnet-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-2.jsonl")

        // Agent 3: Also Opus, same cost = $90
        try writeJSONL([
            assistantLine(msgID: "m3", model: "claude-opus-4-6", input: 1_000_000, output: 1_000_000)
        ], to: dir, name: "agent-3.jsonl")

        let result = JSONLParser.parseSubagents(in: dir)
        #expect(result.keys.count == 2)
        // Opus: $90 + $90 = $180
        #expect(abs((result["Opus 4.6"]?.cost ?? 0) - 180.0) < 0.01)
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
        #expect(abs(details[0].cost - 90.0) < 0.01)
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
        // Opus ($90) should come first (sorted by cost desc)
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

    @Test("AppSettings defaults subagentContextBudget to 1M")
    func settingsDefaultBudget() {
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.subagentContextBudget")
        let settings = AppSettings()
        #expect(settings.subagentContextBudget == .m1)
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.subagentContextBudget")
    }

    @Test("AppSettings persists subagentContextBudget")
    func settingsPersistsBudget() {
        let settings = AppSettings()
        settings.subagentContextBudget = .k200
        #expect(UserDefaults.standard.string(forKey: "ClaudeUsageBar.subagentContextBudget") == "k200")
        let settings2 = AppSettings()
        #expect(settings2.subagentContextBudget == .k200)
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.subagentContextBudget")
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
