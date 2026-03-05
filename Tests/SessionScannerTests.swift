import Testing
@testable import ClaudeUsageBarLib

@Suite("SessionScanner")
struct SessionScannerTests {

    @Test("Encodes slashes to dashes")
    func encodesSlashes() {
        #expect(SessionScanner.encodeProjectPath("/Users/foo/bar") == "-Users-foo-bar")
    }

    @Test("Encodes dots to dashes")
    func encodesDots() {
        #expect(SessionScanner.encodeProjectPath(".hidden") == "-hidden")
    }

    @Test("Encodes underscores to dashes")
    func encodesUnderscores() {
        #expect(SessionScanner.encodeProjectPath("my_project") == "my-project")
    }

    @Test("Encodes all special characters together")
    func encodesAll() {
        #expect(SessionScanner.encodeProjectPath("/Users/foo/.ai_rules") == "-Users-foo--ai-rules")
    }

    @Test("Empty string stays empty")
    func emptyString() {
        #expect(SessionScanner.encodeProjectPath("") == "")
    }

    @Test("Plain alphanumeric unchanged")
    func plainText() {
        #expect(SessionScanner.encodeProjectPath("myproject") == "myproject")
    }
}
