import Foundation

public struct GitHubRelease: Equatable, Sendable {
    public let tagName: String
    public let htmlURL: URL

    public init(tagName: String, htmlURL: URL) {
        self.tagName = tagName
        self.htmlURL = htmlURL
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
        return GitHubRelease(tagName: tag, htmlURL: url)
    }
}
