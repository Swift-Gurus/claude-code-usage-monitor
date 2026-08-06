import Foundation

/**
 solid-name: CodexToolResultFormatter
 solid-category: service
 solid-description: Formats Codex tool output and metadata as display text.
 */
struct CodexToolResultFormatter: CodexToolResultFormatting {
    private let textNormalizer: OptionalTextNormalizing
    private let metadataRenderer: MetadataTextRendering

    init(
        textNormalizer: OptionalTextNormalizing = WhitespaceTextNormalizer(),
        metadataRenderer: MetadataTextRendering = MetadataTextRenderer()
    ) {
        self.textNormalizer = textNormalizer
        self.metadataRenderer = metadataRenderer
    }

    func format(rawValue: String?, decodedObject: [String: Any]?) -> String? {
        guard let rawValue = textNormalizer.normalize(rawValue) else { return nil }
        guard let decodedObject else { return rawValue }

        if let output = textNormalizer.normalize(decodedObject["output"] as? String) {
            return output
        }
        guard let metadata = metadataRenderer.render(decodedObject["metadata"] as? [String: Any]) else {
            return rawValue
        }
        if let output = decodedObject["output"] as? String, !output.isEmpty {
            return output + "\n\n" + metadata
        }
        return metadata
    }
}
