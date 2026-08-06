import Foundation

/**
 solid-name: TemporaryJSONLFixtureProvider
 solid-category: test-fixture
 solid-description: Supplies isolated temporary JSONL files and removes them after each test scenario.
 */
struct TemporaryJSONLFixtureProvider: JSONLFixtureProviding {
    func withFixture<Result>(
        content: String,
        perform: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("fixture.jsonl")
        try Data(content.utf8).write(to: url)
        return try perform(url)
    }
}
