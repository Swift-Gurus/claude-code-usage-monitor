import Foundation

/**
 solid-name: CodexRolloutReader
 solid-category: service
 solid-description: Reads timestamped Codex rollout payloads from storage.
 */
struct CodexRolloutReader: CodexTimestampedRolloutReading {
    private let lineDecoder: CodexJSONLDecoding
    private let dateParser: CodexDateParsing

    init(
        lineDecoder: CodexJSONLDecoding = CodexJSONLFileDecoder(),
        dateParser: CodexDateParsing = CodexDateParser()
    ) {
        self.lineDecoder = lineDecoder
        self.dateParser = dateParser
    }

    func readRollouts(at url: URL) -> [CodexTimestampedRollout] {
        lineDecoder.decodeLines(at: url, as: CodexRolloutLine.self).enumerated().compactMap {
            offset, line in
            guard let payload = line.payload else { return nil }
            return CodexTimestampedRollout(
                type: line.type,
                payload: payload,
                offset: offset,
                timestamp: line.timestamp.flatMap(dateParser.parse)
            )
        }
    }
}
