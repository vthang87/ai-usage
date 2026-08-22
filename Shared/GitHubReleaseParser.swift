import Foundation

public struct GitHubRelease: Equatable, Sendable {
    public let tagName: String
    public let htmlURL: URL
    public let downloadURL: URL?

    public init(tagName: String, htmlURL: URL, downloadURL: URL? = nil) {
        self.tagName = tagName
        self.htmlURL = htmlURL
        self.downloadURL = downloadURL
    }

    public var version: SemanticVersion? {
        SemanticVersion(tagName)
    }
}

public enum GitHubReleaseParser {
    public static func latest(from data: Data) throws -> GitHubRelease {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw ParseError.unexpectedShape("GitHub release root was not an object")
        }
        guard let tag = root["tag_name"] as? String, !tag.isEmpty else {
            throw ParseError.unexpectedShape("GitHub release was missing tag_name")
        }
        guard let urlString = root["html_url"] as? String, let url = URL(string: urlString) else {
            throw ParseError.unexpectedShape("GitHub release was missing html_url")
        }
        return GitHubRelease(tagName: tag, htmlURL: url, downloadURL: packageURL(from: root))
    }

    public static func packageURL(from root: [String: Any]) -> URL? {
        guard let assets = root["assets"] as? [[String: Any]] else { return nil }
        let named: [(String, URL)] = assets.compactMap { asset in
            guard let name = asset["name"] as? String,
                  let raw = asset["browser_download_url"] as? String,
                  let url = URL(string: raw)
            else { return nil }
            return (name.lowercased(), url)
        }
        if let dmg = named.first(where: { $0.0.hasSuffix(".dmg") }) {
            return dmg.1
        }
        return named.first(where: { $0.0.hasSuffix(".zip") })?.1
    }

    public static func isTrustedDownload(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "github.com"
            || host.hasSuffix(".github.com")
            || host.hasSuffix(".githubusercontent.com")
    }
}
