import Foundation

/**
 solid-name: CodexMCPFailureFormatter
 solid-category: service
 solid-description: Formats failed MCP result content and status.
 */
struct CodexMCPFailureFormatter: CodexMCPFailureFormatting {
    private let jsonRenderer: JSONValueTextRendering

    init(jsonRenderer: JSONValueTextRendering = JSONValueTextRenderer()) {
        self.jsonRenderer = jsonRenderer
    }

    func format(_ failure: JSONValue) -> [String] {
        ["error: " + jsonRenderer.render(failure), "status: failed"]
    }
}
