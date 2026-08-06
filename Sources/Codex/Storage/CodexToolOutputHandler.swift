import Foundation

/**
 solid-name: CodexToolOutputHandler
 solid-category: service
 solid-description: Normalizes and attaches Codex tool-output response items.
 */
struct CodexToolOutputHandler: CodexResponseItemHandling {
    private let jsonDecoder: JSONDictionaryDecoding
    private let textContentResolver: CodexTextContentResolving
    private let contentNormalizer: CodexEventContentNormalizing
    private let resultAttacher: CodexToolResultAttaching

    init(
        jsonDecoder: JSONDictionaryDecoding = JSONDictionaryDecoder(),
        textContentResolver: CodexTextContentResolving = CodexTextContentResolver(),
        contentNormalizer: CodexEventContentNormalizing = CodexEventContentNormalizer(),
        resultAttacher: CodexToolResultAttaching = CodexToolResultAttacher()
    ) {
        self.jsonDecoder = jsonDecoder
        self.textContentResolver = textContentResolver
        self.contentNormalizer = contentNormalizer
        self.resultAttacher = resultAttacher
    }

    func handle(_ rollout: CodexTimestampedRollout, state: CodexLogParseState) {
        let rawOutput = textContentResolver.text(from: rollout.payload.output)
        let content = contentNormalizer.toolResult(
            from: rawOutput,
            decodedObject: jsonDecoder.decode(rawOutput)
        )
        resultAttacher.attach(
            content,
            callID: rollout.payload.callID,
            messages: state.messages,
            toolCalls: state.toolCalls
        )
    }
}
