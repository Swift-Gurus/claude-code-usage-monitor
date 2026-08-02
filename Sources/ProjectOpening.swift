import Foundation

/// Prompts for a project directory and spawns a session in it.
protocol ProjectOpening {
    func openProject() -> AgentInfo?
}

extension PopoverProjectOpener: ProjectOpening {}
