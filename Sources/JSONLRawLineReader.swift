import Foundation

/**
 solid-name: JSONLRawLineReading
 solid-category: abstraction
 solid-description: Contract for reading a JSONL file into raw per-line dictionaries.
 */
protocol JSONLRawLineReading {
    func readLines(at url: URL) -> [[String: Any]]
}

/**
 solid-name: JSONLRawLineReader
 solid-category: service
 solid-description: Reads a JSONL file into raw per-line dictionaries.
 */
struct JSONLRawLineReader: JSONLRawLineReading {
    func readLines(at url: URL) -> [[String: Any]] {
        readJSONLLines(at: url) { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
        }
    }
}
