import Darwin
import Foundation

public enum UsagePaths {
    public static let folderName = "com.thangdang.AIUsage"
    public static let widgetBundleId = "com.thangdang.AIUsage.widget"

    /// Process home: real `~` in the app, widget container in the extension.
    public static var processSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(folderName)", isDirectory: true)
    }

    public static var snapshotFile: URL {
        processSupportDirectory.appendingPathComponent("snapshot.json")
    }

    public static var settingsFile: URL {
        processSupportDirectory.appendingPathComponent("settings.json")
    }

    /// Host writes here so the sandboxed widget can read without a file-access exception.
    public static var widgetContainerSupportDirectory: URL {
        realHomeDirectory.appendingPathComponent(
            "Library/Containers/\(widgetBundleId)/Data/Library/Application Support/\(folderName)",
            isDirectory: true
        )
    }

    public static var widgetContainerSnapshotFile: URL {
        widgetContainerSupportDirectory.appendingPathComponent("snapshot.json")
    }

    private static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
