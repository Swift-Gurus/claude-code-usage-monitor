import Foundation

/// Per-subagent stats for the detail drill-down view.
public struct SubagentInfo: Codable, Identifiable {
    public let agentID: String       // e.g. "agent-abc123"
    public let model: String         // display name e.g. "Opus 4.6"
    public let cost: Double
    public let lastInputTokens: Int  // last message's total input tokens (for context %)

    public var id: String { agentID }

    public init(agentID: String, model: String, cost: Double, lastInputTokens: Int) {
        self.agentID = agentID
        self.model = model
        self.cost = cost
        self.lastInputTokens = lastInputTokens
    }
}

public struct SessionUsage {
    public let model: String
    public let displayModel: String
    public let costUSD: Double
    public let contextPercent: Int
    public let linesAdded: Int
    public let linesRemoved: Int
    public let sessionID: String
    public let workingDir: String
    public let agentName: String
    public let startedAt: Date
    public let lastUpdatedAt: Date

    public init(
        model: String, displayModel: String, costUSD: Double, contextPercent: Int,
        linesAdded: Int = 0, linesRemoved: Int = 0,
        sessionID: String, workingDir: String, agentName: String,
        startedAt: Date, lastUpdatedAt: Date
    ) {
        self.model = model
        self.displayModel = displayModel
        self.costUSD = costUSD
        self.contextPercent = contextPercent
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.sessionID = sessionID
        self.workingDir = workingDir
        self.agentName = agentName
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

// MARK: - Model Registry

/// Single source of truth for model metadata: display name, pricing, context window.
/// To add a new model: add a case and fill in all properties.
public enum ClaudeModel: CaseIterable {
    case opus4_6
    case opus4_5
    case sonnet4_6
    case sonnet4_5
    case sonnet4
    case haiku4_5

    /// Substring(s) to match in raw model ID (e.g. "claude-opus-4-6")
    public var idPatterns: [String] {
        switch self {
        case .opus4_6:   return ["opus-4-6", "opus-4.6"]
        case .opus4_5:   return ["opus-4-5", "opus-4.5"]
        case .sonnet4_6: return ["sonnet-4-6", "sonnet-4.6"]
        case .sonnet4_5: return ["sonnet-4-5", "sonnet-4.5"]
        case .sonnet4:   return ["sonnet-4-", "sonnet-4["]
        case .haiku4_5:  return ["haiku-4-5", "haiku-4.5"]
        }
    }

    public var displayName: String {
        switch self {
        case .opus4_6:   return "Opus 4.6"
        case .opus4_5:   return "Opus 4.5"
        case .sonnet4_6: return "Sonnet 4.6"
        case .sonnet4_5: return "Sonnet 4.5"
        case .sonnet4:   return "Sonnet 4"
        case .haiku4_5:  return "Haiku 4.5"
        }
    }

    /// Effective pricing used for JSONL cost estimation.
    /// These are intentionally higher than Anthropic's listed API prices because
    /// JSONL usage fields don't include all tokens (system prompt, tool definitions,
    /// internal context). The higher rates compensate for the missing tokens to
    /// produce estimates closer to Claude Code's actual reported costs.
    public var pricing: ModelPricing {
        switch self {
        case .opus4_6, .opus4_5:
            return ModelPricing(inputPerMTok: 15.0, outputPerMTok: 75.0, cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50)
        case .sonnet4_6, .sonnet4_5, .sonnet4:
            return ModelPricing(inputPerMTok: 3.0, outputPerMTok: 15.0, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
        case .haiku4_5:
            return ModelPricing(inputPerMTok: 0.80, outputPerMTok: 4.0, cacheWritePerMTok: 1.0, cacheReadPerMTok: 0.08)
        }
    }

    public var contextWindowSize: Int {
        switch self {
        case .opus4_6, .opus4_5: return 1_000_000
        case .sonnet4_6, .sonnet4_5, .sonnet4, .haiku4_5: return 200_000
        }
    }

    /// Match a raw model ID string (e.g. "claude-opus-4-6") to a known model.
    public static func from(modelID: String) -> ClaudeModel {
        for model in allCases {
            if model.idPatterns.contains(where: { modelID.contains($0) }) {
                return model
            }
        }
        if modelID.contains("opus") { return .opus4_6 }
        if modelID.contains("haiku") { return .haiku4_5 }
        return .sonnet4_6
    }

    public static func displayName(for modelID: String) -> String {
        if modelID.isEmpty { return "Claude" }
        return from(modelID: modelID).displayName
    }
}

// MARK: - JSONL Parser

/// Parses Claude Code JSONL conversation files to extract token usage and compute costs.
public enum JSONLParser {

    /// Parse a session JSONL file and return aggregated usage data.
    public static func parseSession(at url: URL, sessionID: String, workingDir: String) -> SessionUsage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        var modelID = ""
        let agentName = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var linesAdded = 0
        var linesRemoved = 0

        // Collect per-message usage. JSONL contains streaming partials AND final
        // entries for the same message ID — keep only the last (final) one.
        struct MsgUsage {
            let input: Int; let output: Int; let cacheCreation: Int; let cacheRead: Int
        }
        var usageByMsgID: [String: MsgUsage] = [:]
        var lastInputTokens = 0
        var maxInputTokens = 0

        let decoder = JSONDecoder()

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8) else { continue }
            guard let entry = try? decoder.decode(JSONLEntry.self, from: lineData) else { continue }

            if let ts = entry.parsedTimestamp {
                if firstTimestamp == nil { firstTimestamp = ts }
                lastTimestamp = ts
            }

            // Count line changes from Edit/Write tool calls
            if entry.type == "assistant", let message = entry.message {
                for toolCall in message.toolCalls ?? [] {
                    switch toolCall.name {
                    case "Edit":
                        let oldLines = (toolCall.input.old_string ?? "").components(separatedBy: "\n").count
                        let newLines = (toolCall.input.new_string ?? "").components(separatedBy: "\n").count
                        let delta = newLines - oldLines
                        if delta > 0 { linesAdded += delta } else { linesRemoved += -delta }
                    case "Write":
                        linesAdded += (toolCall.input.content ?? "").components(separatedBy: "\n").count
                    default:
                        break
                    }
                }
            }

            guard entry.type == "assistant",
                  let message = entry.message,
                  let usage = message.usage,
                  let msgID = message.id
            else { continue }

            if let m = message.model, !m.isEmpty { modelID = m }

            let inp = usage.input_tokens ?? 0
            let out = usage.output_tokens ?? 0
            let cc = usage.cache_creation_input_tokens ?? 0
            let cr = usage.cache_read_input_tokens ?? 0

            // Overwrite — last entry per message ID wins (the final with stop_reason)
            usageByMsgID[msgID] = MsgUsage(input: inp, output: out, cacheCreation: cc, cacheRead: cr)
            let totalIn = inp + cc + cr
            lastInputTokens = totalIn
            maxInputTokens = max(maxInputTokens, totalIn)
        }

        // Sum across unique messages
        var totalInput = 0, totalOutput = 0, totalCacheCreation = 0, totalCacheRead = 0
        for (_, mu) in usageByMsgID {
            totalInput += mu.input
            totalOutput += mu.output
            totalCacheCreation += mu.cacheCreation
            totalCacheRead += mu.cacheRead
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

        // Add subagent costs to the total
        let subagentsByModel = parseSubagents(sessionID: sessionID, workingDir: workingDir)
        let subagentCost = subagentsByModel.values.reduce(0.0) { $0 + $1.cost }

        return SessionUsage(
            model: modelID,
            displayModel: resolved.displayName,
            costUSD: PriceCalculator.cost(for: usage, model: resolved) + subagentCost,
            contextPercent: contextPct,
            linesAdded: linesAdded,
            linesRemoved: linesRemoved,
            sessionID: sessionID,
            workingDir: workingDir,
            agentName: agentName,
            startedAt: firstTimestamp ?? Date(),
            lastUpdatedAt: lastTimestamp ?? Date()
        )
    }

    /// Parse all subagent JSONL files for a session, returning per-model cost.
    /// Subagents are stored in ~/.claude/projects/{encoded_path}/{sessionID}/subagents/
    public static func parseSubagents(sessionID: String, workingDir: String) -> [String: SourceModelStats] {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let encoded = SessionScanner.encodeProjectPath(workingDir)
        let subagentsDir = projectsDir
            .appendingPathComponent(encoded)
            .appendingPathComponent(sessionID)
            .appendingPathComponent("subagents")

        return parseSubagents(in: subagentsDir)
    }

    /// Parse all JSONL files in a subagents directory, returning per-model cost.
    public static func parseSubagents(in dir: URL) -> [String: SourceModelStats] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return [:]
        }

        var result: [String: SourceModelStats] = [:]
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "jsonl" {
            guard let data = try? Data(contentsOf: file),
                  let content = String(data: data, encoding: .utf8) else { continue }

            struct MsgUsage {
                let model: String; let input: Int; let output: Int
                let cacheCreation: Int; let cacheRead: Int
            }
            var usageByMsgID: [String: MsgUsage] = [:]

            for line in content.split(separator: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let entry = try? decoder.decode(JSONLEntry.self, from: lineData),
                      entry.type == "assistant",
                      let message = entry.message,
                      let usage = message.usage,
                      let msgID = message.id,
                      let model = message.model, !model.isEmpty
                else { continue }

                usageByMsgID[msgID] = MsgUsage(
                    model: model,
                    input: usage.input_tokens ?? 0,
                    output: usage.output_tokens ?? 0,
                    cacheCreation: usage.cache_creation_input_tokens ?? 0,
                    cacheRead: usage.cache_read_input_tokens ?? 0
                )
            }

            for (_, mu) in usageByMsgID {
                let resolved = ClaudeModel.from(modelID: mu.model)
                let tokenUsage = TokenUsage(
                    inputTokens: mu.input, outputTokens: mu.output,
                    cacheCreationTokens: mu.cacheCreation, cacheReadTokens: mu.cacheRead
                )
                let cost = PriceCalculator.cost(for: tokenUsage, model: resolved)
                let key = resolved.displayName
                result[key, default: SourceModelStats()].cost += cost
            }
        }

        return result
    }

    /// Parse all subagent JSONL files in a directory, returning one SubagentInfo per file.
    public static func parseSubagentDetails(in dir: URL) -> [SubagentInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }

        var results: [SubagentInfo] = []
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "jsonl" {
            guard let data = try? Data(contentsOf: file),
                  let content = String(data: data, encoding: .utf8) else { continue }

            struct MsgUsage {
                let model: String; let input: Int; let output: Int
                let cacheCreation: Int; let cacheRead: Int
            }
            var usageByMsgID: [String: MsgUsage] = [:]
            var lastInputTokens = 0

            for line in content.split(separator: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let entry = try? decoder.decode(JSONLEntry.self, from: lineData),
                      entry.type == "assistant",
                      let message = entry.message,
                      let usage = message.usage,
                      let msgID = message.id,
                      let model = message.model, !model.isEmpty
                else { continue }

                let totalIn = (usage.input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0)
                usageByMsgID[msgID] = MsgUsage(
                    model: model,
                    input: usage.input_tokens ?? 0,
                    output: usage.output_tokens ?? 0,
                    cacheCreation: usage.cache_creation_input_tokens ?? 0,
                    cacheRead: usage.cache_read_input_tokens ?? 0
                )
                lastInputTokens = totalIn
            }

            guard !usageByMsgID.isEmpty else { continue }

            // Use the most common model and sum cost across all messages
            var modelCounts: [String: Int] = [:]
            var totalCost = 0.0
            for (_, mu) in usageByMsgID {
                modelCounts[mu.model, default: 0] += 1
                let resolved = ClaudeModel.from(modelID: mu.model)
                totalCost += PriceCalculator.cost(for: TokenUsage(
                    inputTokens: mu.input, outputTokens: mu.output,
                    cacheCreationTokens: mu.cacheCreation, cacheReadTokens: mu.cacheRead
                ), model: resolved)
            }
            let dominantModel = modelCounts.max(by: { $0.value < $1.value })?.key ?? ""
            let displayModel = ClaudeModel.from(modelID: dominantModel).displayName
            let agentID = file.deletingPathExtension().lastPathComponent

            results.append(SubagentInfo(
                agentID: agentID,
                model: displayModel,
                cost: totalCost,
                lastInputTokens: lastInputTokens
            ))
        }

        return results.sorted { $0.cost > $1.cost }
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
            let id: String?
            let model: String?
            let usage: Usage?
            let content: [ContentItem]?

            var toolCalls: [ToolCall]? {
                content?.compactMap {
                    if case .toolCall(let t) = $0 { return t }
                    return nil
                }
            }

            enum ContentItem: Decodable {
                case toolCall(ToolCall)
                case other

                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    let type = try? c.decode(String.self, forKey: .type)
                    if type == "tool_use" {
                        self = .toolCall(try ToolCall(from: decoder))
                    } else {
                        self = .other
                    }
                }

                enum CodingKeys: String, CodingKey { case type }
            }
        }

        struct ToolCall: Decodable {
            let name: String
            let input: ToolInput

            struct ToolInput: Decodable {
                let old_string: String?
                let new_string: String?
                let content: String?
            }
        }

        struct Usage: Decodable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
        }
    }
}
