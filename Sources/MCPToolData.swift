public struct MCPToolData {
    public let serverName: String
    public let toolName: String
    /// String-valued input parameters (non-string values are stringified).
    public let input: [String: String]
}
