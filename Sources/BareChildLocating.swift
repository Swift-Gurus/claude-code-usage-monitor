import Foundation

/**
 solid-name: BareChildLocating
 solid-category: abstraction
 solid-description: Contract for discovering bare child sessions linked to a parent session.
 */
protocol BareChildLocating {
    func parseBareChildren(parentSessionID: String, in projectDir: URL) -> [SubagentInfo]
}

/**
 solid-name: DefaultBareChildLocator
 solid-category: service
 solid-description: Discovers bare child sessions linked to a parent session.
 */
struct DefaultBareChildLocator: BareChildLocating {
    func parseBareChildren(parentSessionID: String, in projectDir: URL) -> [SubagentInfo] {
        JSONLParser.parseBareChildren(parentSessionID: parentSessionID, in: projectDir)
    }
}
