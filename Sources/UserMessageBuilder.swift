import Foundation

/**
 solid-name: UserMessageBuilding
 solid-category: abstraction
 solid-description: Contract for building LogMessage from user message content including tool interaction data.
 */
protocol UserMessageBuilding {
    func build(
        contentArr: [[String: Any]], toolUseResult: Any?, timestamp: Date?,
        messageIndex: Int, promptToolIDs: Set<String>
    ) -> LogMessage?
}

/**
 solid-name: UserMessageBuilder
 solid-category: service
 solid-description: Builds LogMessage from user message content including tool interaction data; returns nil when there's nothing displayable.
 */
struct UserMessageBuilder: UserMessageBuilding {
    func build(
        contentArr: [[String: Any]], toolUseResult: Any?, timestamp: Date?,
        messageIndex: Int, promptToolIDs: Set<String>
    ) -> LogMessage? {
        var texts: [String] = []
        var resultIDs: Set<String> = []
        var responses: [String: ToolResponse] = [:]
        var resultContents: [String: String] = [:]

        for item in contentArr {
            let itemType = item["type"] as? String ?? ""
            if itemType == "text", let t = item["text"] as? String, !t.isEmpty {
                texts.append(t)
            } else if itemType == "tool_result", let tid = item["tool_use_id"] as? String {
                resultIDs.insert(tid)
                let isError = item["is_error"] as? Bool ?? false

                if let contentStr = item["content"] as? String, !contentStr.isEmpty {
                    resultContents[tid] = contentStr
                } else if let contentArr = item["content"] as? [[String: Any]] {
                    let joined = contentArr.compactMap { $0["text"] as? String }.joined(separator: "\n")
                    if !joined.isEmpty { resultContents[tid] = joined }
                }

                if isError {
                    if let tur = toolUseResult as? String,
                       let range = tur.range(of: "the user said:\n") {
                        let feedback = String(tur[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        responses[tid] = .rejected(feedback: feedback)
                        texts.append(feedback)
                    } else {
                        responses[tid] = .rejected(feedback: "")
                    }
                } else if let tur = toolUseResult as? [String: Any],
                          let answers = tur["answers"] as? [String: String] {
                    responses[tid] = .answered(answers)
                    let answerText = answers.values.joined(separator: ", ")
                    texts.append(answerText)
                } else if let tur = toolUseResult as? [String: Any],
                          tur["plan"] != nil {
                    responses[tid] = .approved
                    texts.append("Plan approved")
                } else if promptToolIDs.contains(tid) {
                    responses[tid] = .approved
                    texts.append("Allowed")
                }
            }
        }

        guard !texts.isEmpty || !resultIDs.isEmpty else { return nil }
        return LogMessage(
            id: "user-\(messageIndex)", role: .user, model: nil,
            timestamp: timestamp, thinking: nil, textContent: texts, toolCalls: [],
            toolResultIDs: resultIDs, toolResponses: responses,
            toolResultContents: resultContents
        )
    }
}
