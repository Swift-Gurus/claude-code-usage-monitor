/**
 solid-name: TruncatedFirstLine
 solid-category: model
 solid-description: Provides a truncated first line from a text block.
 */
struct TruncatedFirstLine {
    let value: String

    init(of text: String) {
        let prefix = String(text.prefix(100))
        let line = prefix.components(separatedBy: "\n").first ?? prefix
        value = line + "..."
    }
}
