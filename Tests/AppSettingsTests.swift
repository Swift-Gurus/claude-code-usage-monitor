import Foundation
import Testing
@testable import ClaudeUsageBarLib

@Suite("AppSettings", .serialized)
struct AppSettingsTests {

    init() {
        // Clean state before each test
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.statusBarPeriod")
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.agentSortOrder")
    }

    @Test("Defaults to day period and recentlyUpdated sort")
    func defaults() {

        let settings = AppSettings()
        #expect(settings.statusBarPeriod == .day)
        #expect(settings.agentSortOrder == .recentlyUpdated)
    }

    @Test("Persists statusBarPeriod to UserDefaults")
    func persistsPeriod() {
        let settings = AppSettings()
        settings.statusBarPeriod = .month
        #expect(UserDefaults.standard.string(forKey: "ClaudeUsageBar.statusBarPeriod") == "month")

        let settings2 = AppSettings()
        #expect(settings2.statusBarPeriod == .month)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.statusBarPeriod")
    }

    @Test("Persists agentSortOrder to UserDefaults")
    func persistsSort() {
        let settings = AppSettings()
        settings.agentSortOrder = .cost
        #expect(UserDefaults.standard.string(forKey: "ClaudeUsageBar.agentSortOrder") == "cost")

        let settings2 = AppSettings()
        #expect(settings2.agentSortOrder == .cost)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.agentSortOrder")
    }

    @Test("Invalid stored value falls back to default")
    func invalidFallback() {
        UserDefaults.standard.set("garbage", forKey: "ClaudeUsageBar.statusBarPeriod")
        UserDefaults.standard.set("nonsense", forKey: "ClaudeUsageBar.agentSortOrder")

        let settings = AppSettings()
        #expect(settings.statusBarPeriod == .day)
        #expect(settings.agentSortOrder == .recentlyUpdated)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.statusBarPeriod")
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.agentSortOrder")
    }

    @Test("SubagentContextBudget defaults to 1M")
    func subagentBudgetDefault() {
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.subagentContextBudget")
        let settings = AppSettings()
        #expect(settings.subagentContextBudget == .m1)
    }

    @Test("SubagentContextBudget persists")
    func subagentBudgetPersists() {
        let settings = AppSettings()
        settings.subagentContextBudget = .k200
        #expect(UserDefaults.standard.string(forKey: "ClaudeUsageBar.subagentContextBudget") == "k200")
        let settings2 = AppSettings()
        #expect(settings2.subagentContextBudget == .k200)
        UserDefaults.standard.removeObject(forKey: "ClaudeUsageBar.subagentContextBudget")
    }

    // MARK: - Enum properties

    @Test("StatusBarPeriod labels and prefixes")
    func periodLabels() {
        #expect(StatusBarPeriod.day.label == "Today")
        #expect(StatusBarPeriod.day.prefix == "D")
        #expect(StatusBarPeriod.week.label == "Week")
        #expect(StatusBarPeriod.week.prefix == "W")
        #expect(StatusBarPeriod.month.label == "Month")
        #expect(StatusBarPeriod.month.prefix == "M")
    }

    @Test("AgentSortOrder labels")
    func sortLabels() {
        #expect(AgentSortOrder.recentlyUpdated.label == "Recent")
        #expect(AgentSortOrder.cost.label == "Cost")
        #expect(AgentSortOrder.contextUsage.label == "Context")
    }
}
