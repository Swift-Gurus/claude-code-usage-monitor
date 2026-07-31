public struct ReadToolData {
    public let filePath: String
    public let offset: Int?
    public let limit: Int?

    public var lineRange: String? {
        guard let limit else { return nil }
        let start = offset ?? 0
        return "lines \(start)–\(start + limit)"
    }
}
