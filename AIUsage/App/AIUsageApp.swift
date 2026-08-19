import AppKit
import SwiftUI

@MainActor
enum AppServices {
    static let collector = UsageCollector()
}

@main
struct AIUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(AppServices.collector)
        } label: {
            MenuBarLabel(snapshot: AppServices.collector.snapshot)
        }
        .menuBarExtraStyle(.window)

        Window("Dashboard", id: "dashboard") {
            DashboardView()
                .environment(AppServices.collector)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 360)

        Settings {
            SettingsView()
                .environment(AppServices.collector)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppServices.collector.start()
    }
}
