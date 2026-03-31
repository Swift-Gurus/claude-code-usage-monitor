import Foundation

/**
 solid-name: SkillToolStateProviding
 solid-category: abstraction
 solid-description: Contract for readable state of a skill tool detail view. Exposes the parsed tool name, arguments, status, and expansion toggle state. Used by SkillToolView to read display data without depending on a concrete ViewModel.
 */
protocol SkillToolStateProviding {
    var toolName: String { get }
    var arguments: String { get }
    var status: String { get }
    var isExpanded: Bool { get }
}

/**
 solid-name: SkillToolActing
 solid-category: abstraction
 solid-description: Contract for actions triggered by the skill tool detail view. Provides a toggle for expand/collapse state. Used by SkillToolView to dispatch user interactions without depending on a concrete ViewModel.
 */
protocol SkillToolActing {
    func toggleExpanded()
}

/**
 solid-name: SkillToolViewModel
 solid-category: viewmodel
 solid-description: Drives the skill tool detail view by holding parsed skill tool data and expand/collapse state. Conforms to SkillToolStateProviding for readable properties and SkillToolActing for view-triggered methods. Initialized from a SkillToolData value.
 */
@Observable
final class SkillToolViewModel: SkillToolStateProviding, SkillToolActing {
    let toolName: String
    let arguments: String
    let status: String
    var isExpanded: Bool

    init(data: SkillToolData, expanded: Bool = false) {
        self.toolName = data.name
        self.arguments = data.arguments
        self.status = data.status
        self.isExpanded = expanded
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }
}
