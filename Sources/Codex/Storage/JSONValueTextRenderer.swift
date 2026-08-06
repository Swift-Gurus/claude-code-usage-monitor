import Foundation

/**
 solid-name: JSONValueTextRenderer
 solid-category: utility
 solid-description: Renders structured JSON values as deterministic readable text.
 */
struct JSONValueTextRenderer: JSONValueTextRendering {
    func render(_ value: JSONValue) -> String {
        switch value {
        case .null:
            return "null"
        case .boolean(let value):
            return value ? "true" : "false"
        case .integer(let value):
            return String(value)
        case .number(let value):
            return String(value)
        case .string(let value):
            return String(reflecting: value)
        case .array(let values):
            return "[" + values.map(render).joined(separator: ", ") + "]"
        case .object(let values):
            let fields = values.sorted { $0.key < $1.key }.map {
                String(reflecting: $0.key) + ": " + render($0.value)
            }
            return "{" + fields.joined(separator: ", ") + "}"
        }
    }
}
