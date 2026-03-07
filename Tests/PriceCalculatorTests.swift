import Testing
@testable import ClaudeUsageBarLib

@Suite("PriceCalculator")
struct PriceCalculatorTests {

    @Test("Zero tokens produce zero cost")
    func zeroTokens() {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
        let cost = PriceCalculator.cost(for: usage, model: .opus4_6)
        #expect(cost == 0)
    }

    @Test("Opus pricing applies correct rates")
    func opusPricing() {
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationTokens: 0, cacheReadTokens: 0)
        let cost = PriceCalculator.cost(for: usage, model: .opus4_6)
        // input: 1M * $5/M = $5, output: 1M * $25/M = $25
        #expect(cost == 30.0)
    }

    @Test("Sonnet pricing applies correct rates")
    func sonnetPricing() {
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationTokens: 0, cacheReadTokens: 0)
        let cost = PriceCalculator.cost(for: usage, model: .sonnet4_6)
        // input: 1M * $3/M = $3, output: 1M * $15/M = $15
        #expect(cost == 18.0)
    }

    @Test("Haiku pricing applies correct rates")
    func haikuPricing() {
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000, cacheCreationTokens: 0, cacheReadTokens: 0)
        let cost = PriceCalculator.cost(for: usage, model: .haiku4_5)
        // input: 1M * $1/M = $1, output: 1M * $5/M = $5
        #expect(cost == 6.0)
    }

    @Test("Cache tokens priced correctly")
    func cacheTokens() {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 1_000_000, cacheReadTokens: 1_000_000)
        let cost = PriceCalculator.cost(for: usage, model: .opus4_6)
        // cacheWrite: 1M * $6.25/M = $6.25, cacheRead: 1M * $0.50/M = $0.50
        #expect(cost == 6.75)
    }

    @Test("All token types combined")
    func allTokenTypes() {
        let usage = TokenUsage(inputTokens: 500_000, outputTokens: 100_000, cacheCreationTokens: 200_000, cacheReadTokens: 300_000)
        let cost = PriceCalculator.cost(for: usage, model: .sonnet4_6)
        // Sonnet unchanged: input: 0.5M * $3 = $1.50, output: 0.1M * $15 = $1.50
        // cacheWrite: 0.2M * $3.75 = $0.75, cacheRead: 0.3M * $0.30 = $0.09
        let expected = 1.50 + 1.50 + 0.75 + 0.09
        #expect(abs(cost - expected) < 0.001)
    }
}
