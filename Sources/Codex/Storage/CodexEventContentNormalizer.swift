import Foundation

/**
 solid-name: CodexEventContentNormalizer
 solid-category: service
 solid-description: Coordinates text normalization and event or tool-result rendering for Codex payloads.
 */
struct CodexEventContentNormalizer: CodexEventContentNormalizing {
    private let textNormalizer: OptionalTextNormalizing
    private let toolResultFormatter: CodexToolResultFormatting
    private let eventRenderer: CodexRolloutEventRendering

    init(
        textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer(),
        toolResultFormatter: CodexToolResultFormatting = CodexToolResultFormatter(),
        eventRenderer: CodexRolloutEventRendering = CodexRolloutEventRenderer()
    ) {
        self.textNormalizer = textNormalizer
        self.toolResultFormatter = toolResultFormatter
        self.eventRenderer = eventRenderer
    }

    func text(_ value: String?) -> String? {
        textNormalizer.normalize(value)
    }

    func toolResult(from rawValue: String?, decodedObject: [String: Any]?) -> String? {
        toolResultFormatter.format(rawValue: rawValue, decodedObject: decodedObject)
    }

    func eventResult(from payload: CodexRolloutPayload) -> String? {
        eventRenderer.resultText(from: payload)
    }

    func errorText(from payload: CodexRolloutPayload) -> String? {
        eventRenderer.errorText(from: payload)
    }

    func genericEventText(from payload: CodexRolloutPayload) -> String? {
        eventRenderer.genericText(from: payload)
    }
}
