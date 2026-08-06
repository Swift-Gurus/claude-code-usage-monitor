import Foundation

/**
 solid-name: CodexLogParser
 solid-category: service
 solid-description: Coordinates Codex rollout reading and message parsing.
 */
struct CodexLogParser: LogMessageParsing {
    private let rolloutReader: CodexTimestampedRolloutReading
    private let responseItemParser: CodexResponseItemParsing
    private let eventParser: CodexEventParsing
    private let stateBuilder: CodexLogParseStateBuilding

    init(
        rolloutReader: CodexTimestampedRolloutReading = CodexRolloutReader(),
        responseItemParser: CodexResponseItemParsing = CodexResponseItemParser(),
        eventParser: CodexEventParsing = CodexEventParser(),
        stateBuilder: CodexLogParseStateBuilding = CodexLogParseStateBuilder()
    ) {
        self.rolloutReader = rolloutReader
        self.responseItemParser = responseItemParser
        self.eventParser = eventParser
        self.stateBuilder = stateBuilder
    }

    func parseMessages(at url: URL) -> [LogMessage] {
        let rollouts = rolloutReader.readRollouts(at: url)
        let state = stateBuilder.makeState(rollouts: rollouts)
        for rollout in rollouts {
            switch rollout.type {
            case "response_item":
                responseItemParser.parse(rollout, state: state)
            case "event_msg":
                eventParser.parse(rollout, state: state)
            default:
                continue
            }
        }
        return state.messages.parsedMessages
    }
}
