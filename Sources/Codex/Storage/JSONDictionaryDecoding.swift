import Foundation

/**
 solid-name: JSONDictionaryDecoding
 solid-category: abstraction
 solid-description: Contract for decoding JSON object text into dictionary values.
 */
protocol JSONDictionaryDecoding {
    func decode(_ rawValue: String?) -> [String: Any]?
}
