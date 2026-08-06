import Foundation

/**
 solid-name: JSONDictionaryDecoder
 solid-category: service
 solid-description: Decodes JSON object text into dictionary values.
 */
struct JSONDictionaryDecoder: JSONDictionaryDecoding {
    private let dataDecoder: JSONDataDecoding
    private let valueConverter: JSONValueDictionaryConverting

    init(
        dataDecoder: JSONDataDecoding = JSONDecoder(),
        valueConverter: JSONValueDictionaryConverting = JSONValueDictionaryConverter()
    ) {
        self.dataDecoder = dataDecoder
        self.valueConverter = valueConverter
    }

    func decode(_ rawValue: String?) -> [String: Any]? {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let values = try? dataDecoder.decode([String: JSONValue].self, from: data)
        else { return nil }

        return valueConverter.dictionary(from: values)
    }
}
