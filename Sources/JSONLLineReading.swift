import Foundation

/// Shared JSONL line-reading algorithm: read the file, split on newlines, and parse
/// each line with the caller-supplied closure, dropping lines that fail to parse.
/// Used by both JSONLRawLineReader (raw dictionaries) and CodexJSONLFileDecoder
/// (typed Decodable rows) so the file-reading/splitting logic isn't duplicated.
func readJSONLLines<T>(at url: URL, parseLine: (String) -> T?) -> [T] {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8) else { return [] }

    return content.split(separator: "\n").compactMap { parseLine(String($0)) }
}
