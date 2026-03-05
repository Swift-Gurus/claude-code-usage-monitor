import Foundation

struct SessionUsage {
    let model: String
    let displayModel: String
    let costUSD: Double
    let contextPercent: Int
    let sessionID: String
    let workingDir: String
    let agentName: String
    let startedAt: Date
    let lastUpdatedAt: Date
}

// MARK: - Model Registry

/// Single source of truth for model metadata: display name, pricing, context window.
/// To add a new model: add a case and fill in all properties.
enum ClaudeModel: CaseIterable {
    case opus4_6
    case opus4_5
    case sonnet4_6
    case sonnet4_5
    case sonnet4
    case haiku4_5

    /// Substring(s) to match in raw model ID (e.g. "claude-opus-4-6")
    var idPatterns: [String] {
        switch self {
        case .opus4_6:   return ["opus-4-6", "opus-4.6"]
        case .opus4_5:   return ["opus-4-5", "opus-4.5"]
        case .sonnet4_6: return ["sonnet-4-6", "sonnet-4.6"]
        case .sonnet4_5: return ["sonnet-4-5", "sonnet-4.5"]
        case .sonnet4:   return ["sonnet-4-", "sonnet-4["]
        case .haiku4_5:  return ["haiku-4-5", "haiku-4.5"]
        }
    }

    var displayName: String {
        switch self {
        case .opus4_6:   return "Opus 4.6 (1M context)"
        case .opus4_5:   return "Opus 4.5 (1M context)"
        case .sonnet4_6: return "Sonnet 4.6"
        case .sonnet4_5: return "Sonnet 4.5"
        case .sonnet4:   return "Sonnet 4"
        case .haiku4_5:  return "Haiku 4.5"
        }
    }

    var pricing: ModelPricing {
        switch self {
        case .opus4_6, .opus4_5:
            return ModelPricing(inputPerMTok: 5.0, outputPerMTok: 25.0, cacheWritePerMTok: 6.25, cacheReadPerMTok: 0.50)
        case .sonnet4_6, .sonnet4_5, .sonnet4:
            return ModelPricing(inputPerMTok: 3.0, outputPerMTok: 15.0, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
        case .haiku4_5:
            return ModelPricing(inputPerMTok: 1.0, outputPerMTok: 5.0, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.10)
        }
    }

    var contextWindowSize: Int {
        switch self {
        case .opus4_6, .opus4_5: return 1_000_000
        case .sonnet4_6, .sonnet4_5, .sonnet4, .haiku4_5: return 200_000
        }
    }

    /// Match a raw model ID string (e.g. "claude-opus-4-6") to a known model.
    static func from(modelID: String) -> ClaudeModel {
        for model in allCases {
            if model.idPatterns.contains(where: { modelID.contains($0) }) {
                return model
            }
        }
        if modelID.contains("opus") { return .opus4_6 }
        if modelID.contains("haiku") { return .haiku4_5 }
        return .sonnet4_6
    }

    static func displayName(for modelID: String) -> String {
        if modelID.isEmpty { return "Claude" }
        return from(modelID: modelID).displayName
    }
}

// MARK: - JSONL Parser

/// Parses Claude Code JSONL conversation files to extract token usage and compute costs.
enum JSONLParser {

    /// Parse a session JSONL file and return aggregated usage data.
    static func parseSession(at url: URL, sessionID: String, workingDir: String) -> SessionUsage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        var modelID = ""
        var totalInput = 0
        var totalOutput = 0
        var totalCacheCreation = 0
        var totalCacheRead = 0
        var lastInputTokens = 0
        var agentName = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?

        let decoder = JSONDecoder()

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8) else { continue }
            guard let entry = try? decoder.decode(JSONLEntry.self, from: lineData) else { continue }

            if let ts = entry.parsedTimestamp {
                if firstTimestamp == nil { firstTimestamp = ts }
                lastTimestamp = ts
            }

            if let slug = entry.slug, !slug.isEmpty { agentName = slug }

            guard entry.type == "assistant",
                  let message = entry.message,
                  let usage = message.usage
            else { continue }

            if let m = message.model, !m.isEmpty { modelID = m }

            let inp = usage.input_tokens ?? 0
            let out = usage.output_tokens ?? 0
            let cc = usage.cache_creation_input_tokens ?? 0
            let cr = usage.cache_read_input_tokens ?? 0

            totalInput += inp
            totalOutput += out
            totalCacheCreation += cc
            totalCacheRead += cr
            lastInputTokens = inp + cc + cr
        }

        guard totalOutput > 0 else { return nil }

        let resolved = ClaudeModel.from(modelID: modelID)

        let usage = TokenUsage(
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheCreationTokens: totalCacheCreation,
            cacheReadTokens: totalCacheRead
        )

        let contextPct = resolved.contextWindowSize > 0
            ? min(100, Int(Double(lastInputTokens) / Double(resolved.contextWindowSize) * 100))
            : 0

        return SessionUsage(
            model: modelID,
            displayModel: resolved.displayName,
            costUSD: PriceCalculator.cost(for: usage, model: resolved),
            contextPercent: contextPct,
            sessionID: sessionID,
            workingDir: workingDir,
            agentName: agentName,
            startedAt: firstTimestamp ?? Date(),
            lastUpdatedAt: lastTimestamp ?? Date()
        )
    }

    // MARK: - JSONL Decodable Types

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private struct JSONLEntry: Decodable {
        let type: String
        let message: MessageContent?
        let sessionId: String?
        let cwd: String?
        let slug: String?
        let timestamp: String?

        var parsedTimestamp: Date? {
            guard let ts = timestamp else { return nil }
            return JSONLParser.timestampFormatter.date(from: ts)
        }

        struct MessageContent: Decodable {
            let model: String?
            let usage: Usage?
        }

        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
        }
    }
}
