import Foundation

/**
 solid-name: SkillToolParsing
 solid-category: abstraction
 solid-description: Contract for extracting skill tool calls from parsed log messages. Accepts an array of LogMessage and returns the SkillToolData values found within tool calls.
 */
protocol SkillToolParsing {
    func extractSkillTools(from messages: [LogMessage]) -> [SkillToolData]
}

/**
 solid-name: SkillToolParser
 solid-category: service
 solid-description: Extracts SkillToolData values from an array of LogMessage by filtering tool calls for the skill case. Delegates JSONL parsing to the existing LogParser infrastructure and focuses solely on skill tool extraction.
 */
struct SkillToolParser: SkillToolParsing {
    func extractSkillTools(from messages: [LogMessage]) -> [SkillToolData] {
        messages.flatMap(\.toolCalls).compactMap { toolCall in
            if case .skill(let data) = toolCall.data {
                return data
            }
            return nil
        }
    }
}
