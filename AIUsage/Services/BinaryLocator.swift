import Foundation

enum BinaryLocator {
    static func find(names: [String]) -> URL? {
        var directories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/.local/bin",
            "/usr/bin",
            "/bin",
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map(String.init))
        }

        var seen = Set<String>()
        let fileManager = FileManager.default
        for directory in directories where seen.insert(directory).inserted {
            for name in names {
                let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
                if fileManager.isExecutableFile(atPath: url.path) {
                    return url
                }
            }
        }
        return nil
    }

    static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/.local/bin",
        ]
        let path = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = (extras + [path]).joined(separator: ":")
        environment["HOME"] = NSHomeDirectory()
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        environment["CI"] = "1"
        return environment
    }
}
