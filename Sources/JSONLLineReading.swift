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

/// Reads enough of a JSONL file to inspect its first few records without loading a
/// potentially very large transcript. The byte cap protects malformed files that do
/// not contain newlines.
func readJSONLPrefix(at url: URL, lineLimit: Int = 30, byteLimit: Int = 4 * 1024 * 1024) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }

    let chunkSize = 64 * 1024
    var data = Data()
    var newlineCount = 0

    while newlineCount < lineLimit, data.count < byteLimit {
        let requestedBytes = min(chunkSize, byteLimit - data.count)
        guard let chunk = try? handle.read(upToCount: requestedBytes), !chunk.isEmpty else { break }
        newlineCount += chunk.reduce(into: 0) { count, byte in
            if byte == 0x0A { count += 1 }
        }
        data.append(chunk)
    }

    return String(data: data, encoding: .utf8)
}
