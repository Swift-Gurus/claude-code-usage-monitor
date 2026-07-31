import Foundation

/**
 solid-name: HookCallFactoring
 solid-category: abstraction
 solid-description: Contract for wrapping hook tracking data in a tool call representation.
 */
protocol HookCallFactoring {
    func make(_ hookData: HookToolData, uuid: String?, suffix: String) -> LogToolCall
}

/**
 solid-name: HookCallFactory
 solid-category: service
 solid-description: Wraps hook tracking data in a tool call representation.
 */
struct HookCallFactory: HookCallFactoring {
    func make(_ hookData: HookToolData, uuid: String?, suffix: String = "") -> LogToolCall {
        LogToolCall(id: "hook-\(uuid ?? UUID().uuidString)\(suffix)", name: "Hook", data: .hook(hookData))
    }
}
