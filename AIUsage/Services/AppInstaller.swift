import AppKit
import Foundation

enum AppInstaller {
    static let expectedBundleID = "com.thangdang.AIUsage"
    static let appFileName = "AI Usage.app"

    static func destinationURL() -> URL {
        let running = Bundle.main.bundleURL
        let path = running.path
        if path.contains("/DerivedData/")
            || path.contains("/.derivedData/")
            || path.contains("/Build/Products/") {
            return URL(fileURLWithPath: "/Applications/\(appFileName)")
        }
        return running
    }

    static func prepareApp(from package: URL) throws -> URL {
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-usage-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        _ = try? ProcessCapture.run(
            executable: URL(fileURLWithPath: "/usr/bin/xattr"),
            arguments: ["-cr", package.path],
            timeout: 10
        )
        let app = try extract(package, into: work)
        try verify(app)
        return app
    }

    static func scheduleReplaceAndRelaunch(newApp: URL) throws {
        let dest = destinationURL()
        let folder = newApp.deletingLastPathComponent()
        let replace = folder.appendingPathComponent("replace.sh")
        let wait = folder.appendingPathComponent("install-update.sh")
        try replaceText(destination: dest, newApp: newApp)
            .write(to: replace, atomically: true, encoding: .utf8)
        try waitText(
            destination: dest,
            replaceScript: replace,
            pid: ProcessInfo.processInfo.processIdentifier
        )
        .write(to: wait, atomically: true, encoding: .utf8)
        for script in [replace, wait] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        }

        let log = FileManager.default.temporaryDirectory.appendingPathComponent("ai-usage-update.log")
        let launch = "nohup /bin/bash \(shQuote(wait.path)) >>\(shQuote(log.path)) 2>&1 &"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", launch]
        process.standardInput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw CollectorError.processFailed("Could not start the updater")
        }
    }

    private static func extract(_ package: URL, into work: URL) throws -> URL {
        let name = package.lastPathComponent.lowercased()
        if name.hasSuffix(".dmg") {
            return try extractDMG(package, into: work)
        }
        if name.hasSuffix(".zip") {
            return try extractZip(package, into: work)
        }
        throw CollectorError.unexpectedResponse("Unsupported update package")
    }

    private static func extractDMG(_ package: URL, into work: URL) throws -> URL {
        let mount = work.appendingPathComponent("mnt", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { _ = try? ProcessCapture.run(
            executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
            arguments: ["detach", mount.path, "-force"],
            timeout: 20
        ) }
        _ = try ProcessCapture.run(
            executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
            arguments: ["attach", package.path, "-nobrowse", "-readonly", "-mountpoint", mount.path],
            timeout: 40
        )
        let staged = work.appendingPathComponent(appFileName)
        try FileManager.default.copyItem(at: findApp(in: mount), to: staged)
        return staged
    }

    private static func extractZip(_ package: URL, into work: URL) throws -> URL {
        let unzipped = work.appendingPathComponent("zip", isDirectory: true)
        try FileManager.default.createDirectory(at: unzipped, withIntermediateDirectories: true)
        _ = try ProcessCapture.run(
            executable: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", package.path, unzipped.path],
            timeout: 40
        )
        let staged = work.appendingPathComponent(appFileName)
        try FileManager.default.copyItem(at: findApp(in: unzipped), to: staged)
        return staged
    }

    private static func findApp(in folder: URL) throws -> URL {
        let items = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        if let match = items.first(where: { $0.lastPathComponent == appFileName }) {
            return match
        }
        if let anyApp = items.first(where: { $0.pathExtension == "app" }) {
            return anyApp
        }
        throw CollectorError.unexpectedResponse("Update package did not contain \(appFileName)")
    }

    private static func verify(_ app: URL) throws {
        let info = app.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: info) else {
            throw CollectorError.unexpectedResponse("Update is missing Info.plist")
        }
        let identifier = plist["CFBundleIdentifier"] as? String
        guard identifier == expectedBundleID else {
            throw CollectorError.unexpectedResponse("Update bundle id did not match")
        }
        let executable = (plist["CFBundleExecutable"] as? String) ?? "AI Usage"
        let binary = app.appendingPathComponent("Contents/MacOS/\(executable)")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw CollectorError.unexpectedResponse("Update is missing its executable")
        }
    }

    private static func replaceText(destination: URL, newApp: URL) -> String {
        """
        #!/bin/bash
        set -euo pipefail
        DEST=\(shQuote(destination.path))
        NEW=\(shQuote(newApp.path))
        rm -rf "$DEST"
        /usr/bin/ditto "$NEW" "$DEST"
        /usr/bin/xattr -cr "$DEST" || true
        """
    }

    private static func waitText(destination: URL, replaceScript: URL, pid: Int32) -> String {
        let destQ = shQuote(destination.path)
        let replaceQ = shQuote(replaceScript.path)
        return """
        #!/bin/bash
        set -euo pipefail
        DEST=\(destQ)
        REPLACE=\(replaceQ)
        PID=\(pid)

        for _ in $(seq 1 80); do
          if ! kill -0 "$PID" 2>/dev/null; then
            break
          fi
          sleep 0.25
        done
        if kill -0 "$PID" 2>/dev/null; then
          echo "AI Usage is still running" >&2
          exit 1
        fi

        PARENT="$(dirname "$DEST")"
        if [ -w "$PARENT" ] && { [ ! -e "$DEST" ] || [ -w "$DEST" ]; }; then
          /bin/bash "$REPLACE"
        else
          /usr/bin/osascript -e "do shell script \\"/bin/bash \(replaceQ)\\" with administrator privileges"
        fi
        /usr/bin/open "$DEST"
        """
    }

    private static func shQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
