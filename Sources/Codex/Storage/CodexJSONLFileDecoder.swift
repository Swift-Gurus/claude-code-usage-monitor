import Foundation

protocol CodexJSONLDecoding {
    func decodeLines<Row: Decodable>(at url: URL, as type: Row.Type) -> [Row]
}

struct CodexJSONLFileDecoder: CodexJSONLDecoding {
    func decodeLines<Row: Decodable>(at url: URL, as type: Row.Type) -> [Row] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        let decoder = JSONDecoder()
        return content.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(type, from: data)
        }
    }
}
