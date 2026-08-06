import Foundation

/**
 solid-name: JSONDataDecoding
 solid-category: abstraction
 solid-description: Contract for decoding typed values from JSON data.
 */
protocol JSONDataDecoding {
    func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value
}
