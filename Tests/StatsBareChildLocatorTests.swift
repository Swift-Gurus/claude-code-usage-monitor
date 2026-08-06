import Foundation
import Testing
@testable import ClaudeUsageBarLib

/**
 solid-name: StatsBareChildLocatorTests
 solid-category: unit-test
 solid-description: Verifies spawned session files are indexed by parent session identifier.
 */
@Suite("Stats Bare Child Locator")
struct StatsBareChildLocatorTests {
    private let directoryProvider: TemporaryDirectoryProviding = IsolatedTemporaryDirectoryProvider()
    private var sut: DefaultStatsBareChildFileLocator { DefaultStatsBareChildFileLocator() }

    @Test("Existing spawned session is indexed by parent")
    func indexesExistingSpawnedSession() throws {
        try directoryProvider.withDirectory { directory in
            let child = directory.appendingPathComponent("child.jsonl")
            try Data("""
            {"type":"user","entrypoint":"sdk-cli","message":{"content":"# spawned-by: parent-1\\nDo work"}}
            """.utf8).write(to: child)

            let located = sut.files(parentSessionID: "parent-1", in: directory)

            #expect(located.count == 1)
            #expect(located.first?.lastPathComponent == child.lastPathComponent)
        }
    }

    @Test("Unrelated parent has no spawned sessions")
    func excludesUnrelatedParent() throws {
        try directoryProvider.withDirectory { directory in
            try Data("""
            {"type":"user","entrypoint":"sdk-cli","message":{"content":"# spawned-by: parent-1\\nDo work"}}
            """.utf8).write(to: directory.appendingPathComponent("child.jsonl"))

            let located = sut.files(parentSessionID: "parent-2", in: directory)

            #expect(located.isEmpty)
        }
    }

    @Test("New spawned session refreshes the index")
    func refreshesAfterNewSpawnedSession() throws {
        try directoryProvider.withDirectory { directory in
            let locator = sut
            _ = locator.files(parentSessionID: "parent-2", in: directory)
            let child = directory.appendingPathComponent("second-child.jsonl")
            try Data("""
            {"type":"user","entrypoint":"sdk-cli","message":{"content":"# spawned-by: parent-2\\nDo more work"}}
            """.utf8).write(to: child)

            let refreshed = locator.files(parentSessionID: "parent-2", in: directory)

            #expect(refreshed.first?.lastPathComponent == child.lastPathComponent)
        }
    }
}
