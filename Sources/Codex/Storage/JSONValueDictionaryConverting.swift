import Foundation

/**
 solid-name: JSONValueDictionaryConverting
 solid-category: abstraction
 solid-description: Contract for converting structured JSON values into dictionary values.
 */
protocol JSONValueDictionaryConverting {
    func dictionary(from values: [String: JSONValue]) -> [String: Any]
}
