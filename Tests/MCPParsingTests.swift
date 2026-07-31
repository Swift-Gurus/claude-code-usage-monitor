import XCTest
@testable import ClaudeUsageBarLib

final class MCPParsingTests: XCTestCase {

    // MARK: - Helpers

    private func writeTempJSONL(_ content: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jsonl")
        try! content.data(using: .utf8)!.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private let assistantHeader = """
    {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[
    """

    // MARK: - MCPToolData Parsing

    func testMCPToolNameParsesServerAndToolName() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_1","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_1","name":"mcp__plugin_solid-coder_docs__load_rules","input":{"tags":"swiftui"}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        let tc = msgs.first?.toolCalls.first
        XCTAssertNotNil(tc, "Expected a tool call")

        guard case .mcp(let data) = tc?.data else {
            XCTFail("Expected .mcp, got \(String(describing: tc?.data))")
            return
        }
        XCTAssertEqual(data.serverName, "plugin_solid-coder_docs")
        XCTAssertEqual(data.toolName, "load_rules")
    }

    func testMCPToolNameWithSimpleServer() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_2","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_2","name":"mcp__ide__getDiagnostics","input":{"uri":"file:///foo.swift"}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        guard case .mcp(let data) = msgs.first?.toolCalls.first?.data else {
            XCTFail("Expected .mcp")
            return
        }
        XCTAssertEqual(data.serverName, "ide")
        XCTAssertEqual(data.toolName, "getDiagnostics")
    }

    func testMCPToolNameWithMultipleUnderscoreSegments() {
        // mcp__plugin_solid-coder_apple-build__get_test_failures → server: plugin_solid-coder_apple-build, tool: get_test_failures
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_3","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_3","name":"mcp__plugin_solid-coder_apple-build__get_test_failures","input":{}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        guard case .mcp(let data) = msgs.first?.toolCalls.first?.data else {
            XCTFail("Expected .mcp")
            return
        }
        XCTAssertEqual(data.serverName, "plugin_solid-coder_apple-build")
        XCTAssertEqual(data.toolName, "get_test_failures")
    }

    // MARK: - MCPToolData Summary

    func testMCPToolSummaryShowsServerAndToolName() {
        let data = MCPToolData(serverName: "ide", toolName: "getDiagnostics", input: [:])
        XCTAssertEqual(ToolData.mcp(data).summary, "ide · getDiagnostics")
    }

    func testMCPToolHasDetail() {
        let data = MCPToolData(serverName: "ide", toolName: "getDiagnostics", input: [:])
        XCTAssertTrue(ToolData.mcp(data).hasDetail)
    }

    func testMCPToolDoesNotNeedPrompt() {
        let data = MCPToolData(serverName: "ide", toolName: "getDiagnostics", input: [:])
        XCTAssertFalse(ToolData.mcp(data).needsPrompt)
    }

    // MARK: - Tool Result Capture

    func testMCPToolResultContentCaptured() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_4","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_4","name":"mcp__ide__getDiagnostics","input":{"uri":"file:///foo.swift"}}]}}
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_4","content":[{"type":"text","text":"No diagnostics found"}]}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        let userMsg = msgs.first { $0.role == .user }
        XCTAssertNotNil(userMsg, "Expected a user message")
        XCTAssertEqual(userMsg?.toolResultContents["toolu_4"], "No diagnostics found")
    }

    func testMCPToolResultIDRegistered() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_5","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_5","name":"mcp__ide__getDiagnostics","input":{}}]}}
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_5","content":[{"type":"text","text":"Done"}]}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        let userMsg = msgs.first { $0.role == .user }
        XCTAssertTrue(userMsg?.toolResultIDs.contains("toolu_5") == true,
                      "tool result ID should be registered in toolResultIDs")
    }

    // MARK: - MCP Input Capture

    func testMCPToolInputCaptured() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_6","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_6","name":"mcp__plugin_solid-coder_docs__load_rules","input":{"tags":"swiftui,testing","profile":"review"}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        guard case .mcp(let data) = msgs.first?.toolCalls.first?.data else {
            XCTFail("Expected .mcp")
            return
        }
        XCTAssertEqual(data.input["tags"], "swiftui,testing")
        XCTAssertEqual(data.input["profile"], "review")
    }

    // MARK: - Non-MCP Tools Not Affected

    func testNonMCPToolStillParsesCorrectly() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_7","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_7","name":"Bash","input":{"command":"echo hello","description":"test"}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        guard case .bash(let data) = msgs.first?.toolCalls.first?.data else {
            XCTFail("Expected .bash")
            return
        }
        XCTAssertEqual(data.command, "echo hello")
    }

    func testUnknownToolFallsToOther() {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_8","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_8","name":"SomeUnknownTool","input":{"foo":"bar"}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        guard case .other(let raw) = msgs.first?.toolCalls.first?.data else {
            XCTFail("Expected .other")
            return
        }
        XCTAssertEqual(raw["foo"], "bar")
    }

    // MARK: - Mutation Guard

    /// Verify that if we break MCP detection the test fails.
    /// (This test is verified manually during mutation testing.)
    func testMCPPrefixIsRequired() {
        // A tool named exactly "mcp" (no double-underscore) should NOT parse as .mcp
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_9","model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":20},"content":[{"type":"tool_use","id":"toolu_9","name":"mcp","input":{}}]}}
        """
        let msgs = LogParser().parseMessages(at: writeTempJSONL(jsonl))

        let tc = msgs.first?.toolCalls.first
        if case .mcp(_) = tc?.data {
            XCTFail("Tool named 'mcp' alone should not parse as .mcp — needs mcp__ prefix with server and tool")
        }
        // Should fall through to .other or some non-mcp case
    }
}
