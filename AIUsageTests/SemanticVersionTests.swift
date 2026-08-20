#if canImport(AIUsageCore)
import AIUsageCore
#endif
import XCTest

final class SemanticVersionTests: XCTestCase {
    func testParsesPrefixedAndPartialVersions() {
        XCTAssertEqual(SemanticVersion("v0.0.2"), SemanticVersion("0.0.2"))
        XCTAssertEqual(SemanticVersion("1.2")?.string, "1.2.0")
        XCTAssertEqual(SemanticVersion("0.0.2-beta")?.string, "0.0.2")
        XCTAssertNil(SemanticVersion("not-a-version"))
    }

    func testComparesSemverOrdering() {
        XCTAssertGreaterThan(SemanticVersion("0.0.3")!, SemanticVersion("0.0.2")!)
        XCTAssertGreaterThan(SemanticVersion("1.0.0")!, SemanticVersion("0.9.9")!)
        XCTAssertFalse(SemanticVersion("0.0.2")! > SemanticVersion("v0.0.2")!)
    }

    func testParsesGitHubLatestRelease() throws {
        let data = Data(#"{"tag_name":"v0.0.3","html_url":"https://github.com/vthang87/ai-usage/releases/tag/v0.0.3"}"#.utf8)
        let release = try GitHubReleaseParser.latest(from: data)
        XCTAssertEqual(release.tagName, "v0.0.3")
        XCTAssertEqual(release.version?.string, "0.0.3")
        XCTAssertEqual(release.htmlURL.absoluteString, "https://github.com/vthang87/ai-usage/releases/tag/v0.0.3")
    }
}
