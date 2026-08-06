import Foundation

/**
 solid-name: CodexLogParser
 solid-category: utility
 solid-description: Configures whether Codex token-count rollouts produce usage messages.
 */
extension CodexLogParser {
    init(includeTokenUsageMessages: Bool) {
        self.init(
            eventParser: CodexEventParser(
                tokenHandler: CodexTokenEventHandler(
                    messageBuilder: CodexTokenUsageMessageBuilder(
                        includesMessages: includeTokenUsageMessages
                    )
                )
            )
        )
    }
}
