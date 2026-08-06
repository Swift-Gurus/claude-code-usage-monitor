import Foundation

/**
 solid-name: IsolatedTemporaryDirectoryProvider
 solid-category: test-fixture
 solid-stack: [structured-concurrency]
 solid-description: Supplies isolated temporary directories and removes them after each test scenario.
 */
struct IsolatedTemporaryDirectoryProvider: TemporaryDirectoryProviding {
    func withDirectory<Result>(perform: (URL) throws -> Result) throws -> Result {
        let directory = try makeDirectory()
        defer { removeDirectory(directory) }
        return try perform(directory)
    }

    func withDirectory<Result>(perform: (URL) async throws -> Result) async throws -> Result {
        let directory = try makeDirectory()
        defer { removeDirectory(directory) }
        return try await perform(directory)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}
