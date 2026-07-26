import Foundation

/**
 solid-name: ToolDataParsing
 solid-category: abstraction
 solid-description: Contract for decoding structured tool arguments into display-ready ToolData used by the shared log viewer.
 */
protocol ToolDataParsing {
    func parseToolData(name: String, input: [String: Any]) -> ToolData
}

/**
 solid-name: ToolDataParser
 solid-category: service
 solid-description: Shared decoder for tool/function-call argument dictionaries used by both Claude and Codex log parsers so the same expandable chip UI can render their requests and results consistently.
 */
struct ToolDataParser: ToolDataParsing {
    func parseToolData(name: String, input: [String: Any]) -> ToolData {
        let str = { (key: String) -> String in input[key] as? String ?? "" }

        switch name {
        case "Edit":
            return .edit(EditToolData(
                filePath: str("file_path"),
                oldString: str("old_string"),
                newString: str("new_string"),
                replaceAll: input["replace_all"] as? Bool ?? false
            ))
        case "Write":
            return .write(WriteToolData(filePath: str("file_path"), content: str("content")))
        case "Read":
            return .read(ReadToolData(
                filePath: str("file_path"),
                offset: input["offset"] as? Int,
                limit: input["limit"] as? Int
            ))
        case "Bash", "exec_command":
            return .bash(BashToolData(
                command: str("cmd").isEmpty ? str("command") : str("cmd"),
                description: str("description"),
                timeout: input["timeout"] as? Int
            ))
        case "Grep":
            return .grep(GrepToolData(pattern: str("pattern"), path: str("path")))
        case "Glob":
            return .glob(GlobToolData(pattern: str("pattern"), path: str("path")))
        case "Agent":
            return .agent(AgentToolData(
                description: str("description"), prompt: str("prompt"),
                subagentType: str("subagent_type")
            ))
        case "TaskCreate":
            return .taskCreate(TaskCreateToolData(
                subject: str("subject"), description: str("description"),
                activeForm: str("activeForm")
            ))
        case "TaskUpdate":
            return .taskUpdate(TaskUpdateToolData(taskId: str("taskId"), status: str("status")))
        case "TodoWrite":
            var items: [TodoWriteToolData.TodoItem] = []
            if let todos = input["todos"] as? [[String: Any]] {
                for todo in todos {
                    items.append(TodoWriteToolData.TodoItem(
                        content: todo["content"] as? String ?? "",
                        status: todo["status"] as? String ?? "pending"
                    ))
                }
            }
            return .todoWrite(TodoWriteToolData(todos: items))
        case "Skill":
            return .skill(SkillToolData(name: str("skill"), arguments: str("args"), status: str("status")))
        case "WebSearch":
            return .webSearch(WebSearchToolData(query: str("query")))
        case "WebFetch":
            return .webFetch(WebFetchToolData(url: str("url"), prompt: str("prompt")))
        case "AskUserQuestion":
            var questions: [AskUserQuestionToolData.Question] = []
            if let qArr = input["questions"] as? [[String: Any]] {
                for q in qArr {
                    var options: [AskUserQuestionToolData.Option] = []
                    if let opts = q["options"] as? [[String: Any]] {
                        for o in opts {
                            options.append(AskUserQuestionToolData.Option(
                                label: o["label"] as? String ?? "",
                                description: o["description"] as? String ?? ""
                            ))
                        }
                    }
                    questions.append(AskUserQuestionToolData.Question(
                        question: q["question"] as? String ?? "",
                        header: q["header"] as? String ?? "",
                        options: options,
                        multiSelect: q["multiSelect"] as? Bool ?? false
                    ))
                }
            }
            return .askUserQuestion(AskUserQuestionToolData(questions: questions))
        case "ExitPlanMode":
            return .exitPlanMode(ExitPlanModeToolData(plan: str("plan")))
        default:
            if name.hasPrefix("mcp__") {
                let body = String(name.dropFirst(5))
                if let sep = body.range(of: "__") {
                    let serverName = String(body[body.startIndex..<sep.lowerBound])
                    let toolName = String(body[sep.upperBound...])
                    if !serverName.isEmpty && !toolName.isEmpty {
                        var raw: [String: String] = [:]
                        for (key, val) in input {
                            if let s = val as? String { raw[key] = s }
                            else if let n = val as? NSNumber { raw[key] = n.stringValue }
                        }
                        return .mcp(MCPToolData(serverName: serverName, toolName: toolName, input: raw))
                    }
                }
            }

            var raw: [String: String] = [:]
            for (key, val) in input {
                if let s = val as? String { raw[key] = s }
                else if let n = val as? NSNumber { raw[key] = n.stringValue }
                else if let arr = val as? [[String: Any]] {
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
}
