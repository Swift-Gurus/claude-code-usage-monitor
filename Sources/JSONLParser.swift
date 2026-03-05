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

/// Parses Claude Code JSONL conversation files to extract token usage and compute costs.
enum JSONLParser {

    /// Parse a session JSONL file and return aggregated usage data.
    static func parseSession(at url: URL, sessionID: String, workingDir: String) -> SessionUsage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        var model = ""
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheCreation = 0
        var totalCacheRead = 0
        var lastInputTokens = 0  // most recent call's input — approximates context size
        var resolvedCwd = workingDir
        var agentName = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?

        let decoder = JSONDecoder()

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8) else { continue }
            guard let entry = try? decoder.decode(JSONLEntry.self, from: lineData) else { continue }

            // Track timestamps for duration
            if let ts = entry.parsedTimestamp {
                if firstTimestamp == nil { firstTimestamp = ts }
                lastTimestamp = ts
            }

            // Pick up working directory and slug (agent name) from any message
            if let cwd = entry.cwd, !cwd.isEmpty { resolvedCwd = cwd }
            if let slug = entry.slug, !slug.isEmpty { agentName = slug }

            // Only assistant messages have token usage
            guard entry.type == "assistant",
                  let message = entry.message,
                  let usage = message.usage
            else { continue }

            if let m = message.model, !m.isEmpty { model = m }

            let inp = usage.input_tokens ?? 0
            let out = usage.output_tokens ?? 0
            let cc = usage.cache_creation_input_tokens ?? 0
            let cr = usage.cache_read_input_tokens ?? 0

            totalInputTokens += inp
            totalOutputTokens += out
            totalCacheCreation += cc
            totalCacheRead += cr
            lastInputTokens = inp + cc + cr  // full context for this call
        }

        // No assistant messages means no meaningful data
        guard totalOutputTokens > 0 else { return nil }

        let cost = computeCost(
            model: model,
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            cacheCreationTokens: totalCacheCreation,
            cacheReadTokens: totalCacheRead
        )

        let contextLimit = contextWindowSize(for: model)
        let contextPct = contextLimit > 0
            ? min(100, Int(Double(lastInputTokens) / Double(contextLimit) * 100))
            : 0

        return SessionUsage(
            model: model,
            displayModel: displayName(for: model),
            costUSD: cost,
            contextPercent: contextPct,
            sessionID: sessionID,
            workingDir: resolvedCwd,
            agentName: agentName,
            startedAt: firstTimestamp ?? Date(),
            lastUpdatedAt: lastTimestamp ?? Date()
        )
    }

    // MARK: - Cost Computation

    private struct Pricing {
        let inputPerToken: Double
        let outputPerToken: Double
        let cacheCreationPerToken: Double
        let cacheReadPerToken: Double
    }

    private static func computeCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) -> Double {
        let p = pricing(for: model)
        return Double(inputTokens) * p.inputPerToken
            + Double(outputTokens) * p.outputPerToken
            + Double(cacheCreationTokens) * p.cacheCreationPerToken
            + Double(cacheReadTokens) * p.cacheReadPerToken
    }

    private static func pricing(for model: String) -> Pricing {
        if model.contains("opus") {
            return Pricing(
                inputPerToken: 15.0 / 1_000_000,
                outputPerToken: 75.0 / 1_000_000,
                cacheCreationPerToken: 18.75 / 1_000_000,
                cacheReadPerToken: 1.50 / 1_000_000
            )
        } else if model.contains("haiku") {
            return Pricing(
                inputPerToken: 0.80 / 1_000_000,
                outputPerToken: 4.0 / 1_000_000,
                cacheCreationPerToken: 1.0 / 1_000_000,
                cacheReadPerToken: 0.08 / 1_000_000
            )
        } else {
            // Sonnet (default)
            return Pricing(
                inputPerToken: 3.0 / 1_000_000,
                outputPerToken: 15.0 / 1_000_000,
                cacheCreationPerToken: 3.75 / 1_000_000,
                cacheReadPerToken: 0.30 / 1_000_000
            )
        }
    }

    // MARK: - Model Metadata

    private static func contextWindowSize(for model: String) -> Int {
        // Models with [1m] suffix have extended 1M context
        if model.contains("opus") { return 1_000_000 }
        if model.contains("sonnet") { return 200_000 }
        if model.contains("haiku") { return 200_000 }
        return 200_000
    }

    static func displayName(for model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        if model.isEmpty { return "Claude" }
        return model
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
