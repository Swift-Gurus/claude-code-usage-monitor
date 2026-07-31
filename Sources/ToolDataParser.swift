import Foundation

/**
 solid-name: ToolDataParsing
 solid-category: abstraction
 solid-description: Contract for parsing tool arguments into ToolData objects.
 */
protocol ToolDataParsing {
    func parseToolData(name: String, input: [String: Any]) -> ToolData
}

/// Converts String/NSNumber values in a tool-input dictionary to their string form,
/// dropping any other value kind. Shared by the MCP branch and the `.other` fallback.
private func stringValueMap(_ input: [String: Any]) -> [String: String] {
    var raw: [String: String] = [:]
    for (key, val) in input {
        if let s = val as? String { raw[key] = s }
        else if let n = val as? NSNumber { raw[key] = n.stringValue }
    }
    return raw
}

/**
 solid-name: ToolDataParser
 solid-category: service
 solid-description: Decodes tool and function-call argument dictionaries into structured ToolData objects.
 */
struct ToolDataParser: ToolDataParsing {
    private let decodersByName: [String: ([String: Any]) -> ToolData]

    init() {
        func str(_ input: [String: Any], _ key: String) -> String { input[key] as? String ?? "" }

        var decoders: [String: ([String: Any]) -> ToolData] = [:]

        decoders["Edit"] = { input in
            .edit(EditToolData(
                filePath: str(input, "file_path"),
                oldString: str(input, "old_string"),
                newString: str(input, "new_string"),
                replaceAll: input["replace_all"] as? Bool ?? false
            ))
        }
        decoders["Write"] = { input in
            .write(WriteToolData(filePath: str(input, "file_path"), content: str(input, "content")))
        }
        decoders["Read"] = { input in
            .read(ReadToolData(
                filePath: str(input, "file_path"),
                offset: input["offset"] as? Int,
                limit: input["limit"] as? Int
            ))
        }
        let bashDecoder: ([String: Any]) -> ToolData = { input in
            .bash(BashToolData(
                command: str(input, "cmd").isEmpty ? str(input, "command") : str(input, "cmd"),
                description: str(input, "description"),
                timeout: input["timeout"] as? Int
            ))
        }
        decoders["Bash"] = bashDecoder
        decoders["exec_command"] = bashDecoder
        decoders["Grep"] = { input in
            .grep(GrepToolData(pattern: str(input, "pattern"), path: str(input, "path")))
        }
        decoders["Glob"] = { input in
            .glob(GlobToolData(pattern: str(input, "pattern"), path: str(input, "path")))
        }
        decoders["Agent"] = { input in
            .agent(AgentToolData(
                description: str(input, "description"), prompt: str(input, "prompt"),
                subagentType: str(input, "subagent_type")
            ))
        }
        decoders["TaskCreate"] = { input in
            .taskCreate(TaskCreateToolData(
                subject: str(input, "subject"), description: str(input, "description"),
                activeForm: str(input, "activeForm")
            ))
        }
        decoders["TaskUpdate"] = { input in
            .taskUpdate(TaskUpdateToolData(taskId: str(input, "taskId"), status: str(input, "status")))
        }
        decoders["TodoWrite"] = { input in
            var items: [TodoItem] = []
            if let todos = input["todos"] as? [[String: Any]] {
                for todo in todos {
                    items.append(TodoItem(
                        content: todo["content"] as? String ?? "",
                        status: todo["status"] as? String ?? "pending"
                    ))
                }
            }
            return .todoWrite(TodoWriteToolData(todos: items))
        }
        decoders["Skill"] = { input in
            .skill(SkillToolData(name: str(input, "skill"), arguments: str(input, "args"), status: str(input, "status")))
        }
        decoders["WebSearch"] = { input in
            .webSearch(WebSearchToolData(query: str(input, "query")))
        }
        decoders["WebFetch"] = { input in
            .webFetch(WebFetchToolData(url: str(input, "url"), prompt: str(input, "prompt")))
        }
        decoders["AskUserQuestion"] = { input in
            var questions: [ToolQuestion] = []
            if let qArr = input["questions"] as? [[String: Any]] {
                for q in qArr {
                    var options: [ToolQuestionOption] = []
                    if let opts = q["options"] as? [[String: Any]] {
                        for o in opts {
                            options.append(ToolQuestionOption(
                                label: o["label"] as? String ?? "",
                                description: o["description"] as? String ?? ""
                            ))
                        }
                    }
                    questions.append(ToolQuestion(
                        question: q["question"] as? String ?? "",
                        header: q["header"] as? String ?? "",
                        options: options,
                        multiSelect: q["multiSelect"] as? Bool ?? false
                    ))
                }
            }
            return .askUserQuestion(AskUserQuestionToolData(questions: questions))
        }
        decoders["ExitPlanMode"] = { input in
            .exitPlanMode(ExitPlanModeToolData(plan: str(input, "plan")))
        }

        self.decodersByName = decoders
    }

    func parseToolData(name: String, input: [String: Any]) -> ToolData {
        if let decode = decodersByName[name] {
            return decode(input)
        }

        if name.hasPrefix("mcp__") {
            let body = String(name.dropFirst(5))
            if let sep = body.range(of: "__") {
                let serverName = String(body[body.startIndex..<sep.lowerBound])
                let toolName = String(body[sep.upperBound...])
                if !serverName.isEmpty && !toolName.isEmpty {
                    return .mcp(MCPToolData(serverName: serverName, toolName: toolName, input: stringValueMap(input)))
                }
            }
        }

        var raw = stringValueMap(input)
        for (key, val) in input {
            if let arr = val as? [[String: Any]] {
                let lines = arr.map { dict in
                    dict.sorted(by: { $0.key < $1.key })
                        .compactMap { k, v in (v as? String).map { "\(k): \($0)" } }
                        .joined(separator: ", ")
                }
                raw[key] = lines.joined(separator: "\n")
            }
        }
        return .other(raw: raw)
    }
}
