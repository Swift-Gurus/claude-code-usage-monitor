import Foundation

/**
 solid-name: JSONValueDictionaryConverter
 solid-category: service
 solid-description: Converts structured JSON values into dictionary values.
 */
struct JSONValueDictionaryConverter: JSONValueDictionaryConverting {
    func dictionary(from values: [String: JSONValue]) -> [String: Any] {
        values.compactMapValues(convert)
    }

    private func convert(_ value: JSONValue) -> Any? {
        switch value {
        case .null:
            return nil
        case .boolean(let value):
            return value
        case .integer(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.compactMap(convert)
        case .object(let values):
            return values.compactMapValues(convert)
        }
    }
}
