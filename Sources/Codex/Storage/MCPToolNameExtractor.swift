import Foundation

/**
 solid-name: MCPToolNameExtractor
 solid-category: service
 solid-description: Identifies MCP tool names embedded in Codex invocation text.
 */
struct MCPToolNameExtractor: MCPToolNameExtracting {
    private let marker = "tools."

    func names(in source: String?) -> [String] {
        guard let source else { return [] }

        var names: [String] = []
        var searchStart = source.startIndex

        while let markerRange = source.range(
            of: "tools.mcp__",
            range: searchStart..<source.endIndex
        ) {
            let nameStart = source.index(markerRange.lowerBound, offsetBy: marker.count)
            var nameEnd = nameStart

            while nameEnd < source.endIndex, isToolNameCharacter(source[nameEnd]) {
                nameEnd = source.index(after: nameEnd)
            }

            var expressionEnd = nameEnd
            while expressionEnd < source.endIndex, source[expressionEnd].isWhitespace {
                expressionEnd = source.index(after: expressionEnd)
            }

            let name = String(source[nameStart..<nameEnd])
            if expressionEnd < source.endIndex,
               source[expressionEnd] == "(",
               name.dropFirst("mcp__".count).contains("__") {
                names.append(name)
            }

            searchStart = nameEnd > markerRange.lowerBound
                ? nameEnd
                : source.index(after: markerRange.lowerBound)
        }

        return names
    }

    private func isToolNameCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-"
    }
}
