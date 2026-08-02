import AppKit
import ClaudeUsageBarLib
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dependencies: AppDependencies!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Menu bar accessory apps have no visible menu bar. Removing the main menu
        // prevents a macOS crash triggered when accessibility tools inspect the
        // Apple menu's "Open Recent" item (nil deref in
        // initkLSSharedFileListRecentApplicationItems, macOS 26.3 rdar://147282034).
        // Deferred one run-loop tick so SwiftUI finishes its own menu setup first.
        DispatchQueue.main.async { NSApp.mainMenu = nil }

        let dependencies = AppAssembler().assemble()
        self.dependencies = dependencies

        dependencies.uiController.setup()
        dependencies.refreshCoordinator.startMonitoring(onTick: dependencies.refreshTitle)
        dependencies.refreshTitle()
        dependencies.settingsObserver.start()
    }
}

@main
struct ClaudeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {}
    }
}
