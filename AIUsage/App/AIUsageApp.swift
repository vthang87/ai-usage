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
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    AppWindowFocus.bringSettingsToFront()
                }
        }
    }
}

@MainActor
enum AppWindowFocus {
    static func bringSettingsToFront() {
        NSApp.activate(ignoringOtherApps: true)
        orderSettingsFront()
        // Settings window is created asynchronously the first time.
        DispatchQueue.main.async {
            orderSettingsFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            orderSettingsFront()
        }
    }

    private static func orderSettingsFront() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.filter(isSettingsWindow).forEach(orderFront)
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window.frameAutosaveName.contains("Settings") { return true }
        if window.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true { return true }
        if window.title.localizedCaseInsensitiveContains("settings") { return true }
        return false
    }

    private static func orderFront(_ window: NSWindow) {
        window.collectionBehavior.insert([.moveToActiveSpace, .fullScreenAuxiliary])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
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
