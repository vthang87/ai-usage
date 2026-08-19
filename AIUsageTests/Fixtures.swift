import Foundation

enum Fixtures {
    static func jsonObject(named name: String) throws -> Any {
        let data = try data(named: name)
        return try JSONSerialization.jsonObject(with: data)
    }

    static func data(named name: String) throws -> Data {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try Data(contentsOf: fileURL)
        }

        let bundle = Bundle(for: BundleToken.self)
        let resourceName = (name as NSString).deletingPathExtension
        let resourceExt = (name as NSString).pathExtension
        if let url = bundle.url(forResource: resourceName, withExtension: resourceExt, subdirectory: "Fixtures")
            ?? bundle.url(forResource: resourceName, withExtension: resourceExt) {
            return try Data(contentsOf: url)
        }

        throw NSError(domain: "AIUsageTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Missing fixture \(name)",
        ])
    }
}

private final class BundleToken {}
