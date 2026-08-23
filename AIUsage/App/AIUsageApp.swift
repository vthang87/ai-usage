import AppKit
import SwiftUI

@MainActor
enum AppServices {
    static let collector = UsageCollector()
    static let updates = UpdateChecker()
}

@main
struct AIUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(AppServices.collector)
                .environment(AppServices.updates)
        } label: {
            MenuBarLabel()
                .environment(AppServices.collector)
        }
        .menuBarExtraStyle(.window)

        Window("Dashboard", id: "dashboard") {
            DashboardView()
                .environment(AppServices.collector)
                .environment(AppServices.updates)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 360)

        Settings {
            SettingsView()
                .environment(AppServices.collector)
                .environment(AppServices.updates)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppServices.collector.start()
        Task { await AppServices.updates.checkIfNeeded() }
    }
}
