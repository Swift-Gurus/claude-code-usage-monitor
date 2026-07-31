extension Dictionary where Key == String, Value == String {
    /// Sorted "key: value" lines, one per entry — the shared display format for raw tool-input dictionaries.
    func formattedKeyValuePairs() -> String {
        sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}
