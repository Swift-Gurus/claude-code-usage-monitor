import Foundation

/**
 solid-name: JSONLFixtureProviding
 solid-category: abstraction
 solid-description: Contract for supplying isolated temporary JSONL fixtures to tests.
 */
protocol JSONLFixtureProviding {
    func withFixture<Result>(
        content: String,
        perform: (URL) throws -> Result
    ) throws -> Result
}
