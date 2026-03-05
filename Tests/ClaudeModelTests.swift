import Testing
@testable import ClaudeUsageBarLib

@Suite("ClaudeModel")
struct ClaudeModelTests {

    // MARK: - Model ID Matching

    @Test("Matches Opus 4.6 model IDs")
    func matchOpus46() {
        #expect(ClaudeModel.from(modelID: "claude-opus-4-6") == .opus4_6)
        #expect(ClaudeModel.from(modelID: "claude-opus-4-6-20250515") == .opus4_6)
        #expect(ClaudeModel.from(modelID: "claude-opus-4.6") == .opus4_6)
    }

    @Test("Matches Opus 4.5 model IDs")
    func matchOpus45() {
        #expect(ClaudeModel.from(modelID: "claude-opus-4-5-20250120") == .opus4_5)
        #expect(ClaudeModel.from(modelID: "claude-opus-4.5") == .opus4_5)
    }

    @Test("Matches Sonnet 4.6 model IDs")
    func matchSonnet46() {
        #expect(ClaudeModel.from(modelID: "claude-sonnet-4-6-20250514") == .sonnet4_6)
        #expect(ClaudeModel.from(modelID: "claude-sonnet-4.6") == .sonnet4_6)
    }

    @Test("Matches Sonnet 4.5 model IDs")
    func matchSonnet45() {
        #expect(ClaudeModel.from(modelID: "claude-sonnet-4-5-20250120") == .sonnet4_5)
    }

    @Test("Matches Haiku 4.5 model IDs")
    func matchHaiku() {
        #expect(ClaudeModel.from(modelID: "claude-haiku-4-5-20251001") == .haiku4_5)
        #expect(ClaudeModel.from(modelID: "claude-haiku-4.5") == .haiku4_5)
    }

    // MARK: - Fallback Behavior

    @Test("Unknown opus falls back to opus4_6")
    func fallbackOpus() {
        #expect(ClaudeModel.from(modelID: "some-opus-model") == .opus4_6)
    }

    @Test("Unknown haiku falls back to haiku4_5")
    func fallbackHaiku() {
        #expect(ClaudeModel.from(modelID: "some-haiku-model") == .haiku4_5)
    }

    @Test("Completely unknown model falls back to sonnet4_6")
    func fallbackUnknown() {
        #expect(ClaudeModel.from(modelID: "unknown-model") == .sonnet4_6)
    }

    // MARK: - Display Names

    @Test("Display name for empty string returns Claude")
    func displayNameEmpty() {
        #expect(ClaudeModel.displayName(for: "") == "Claude")
    }

    @Test("Display names don't include context window")
    func displayNamesNoContext() {
        #expect(ClaudeModel.opus4_6.displayName == "Opus 4.6")
        #expect(ClaudeModel.sonnet4_6.displayName == "Sonnet 4.6")
        #expect(ClaudeModel.haiku4_5.displayName == "Haiku 4.5")
    }

    // MARK: - Context Window Sizes

    @Test("Opus models have 1M context")
    func opusContext() {
        #expect(ClaudeModel.opus4_6.contextWindowSize == 1_000_000)
        #expect(ClaudeModel.opus4_5.contextWindowSize == 1_000_000)
    }

    @Test("Non-opus models have 200K context")
    func nonOpusContext() {
        #expect(ClaudeModel.sonnet4_6.contextWindowSize == 200_000)
        #expect(ClaudeModel.sonnet4_5.contextWindowSize == 200_000)
        #expect(ClaudeModel.sonnet4.contextWindowSize == 200_000)
        #expect(ClaudeModel.haiku4_5.contextWindowSize == 200_000)
    }

    // MARK: - Pattern Uniqueness

    @Test("No two models share the same ID pattern")
    func patternsUnique() {
        let allPatterns = ClaudeModel.allCases.flatMap(\.idPatterns)
        #expect(Set(allPatterns).count == allPatterns.count)
    }
}
