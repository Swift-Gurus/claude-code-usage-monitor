import Foundation

/**
 solid-name: TemporaryDirectoryProviding
 solid-category: abstraction
 solid-stack: [structured-concurrency]
 solid-description: Contract for supplying isolated temporary directories to tests.
 */
protocol TemporaryDirectoryProviding {
    func withDirectory<Result>(perform: (URL) throws -> Result) throws -> Result
    func withDirectory<Result>(perform: (URL) async throws -> Result) async throws -> Result
}
