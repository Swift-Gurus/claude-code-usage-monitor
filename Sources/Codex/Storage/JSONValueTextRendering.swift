import Foundation

/**
 solid-name: JSONValueTextRendering
 solid-category: abstraction
 solid-description: Contract for rendering structured JSON values as readable text.
 */
protocol JSONValueTextRendering {
    func render(_ value: JSONValue) -> String
}
