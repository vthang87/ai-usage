import Foundation

public struct UsageWindow: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var label: String
    public var usedPercent: Double?
    public var quotaDescription: String?
    public var resetsAt: Date?

    public var id: String { label }

    public init(label: String, usedPercent: Double? = nil, quotaDescription: String? = nil, resetsAt: Date? = nil) {
        self.label = label
        self.usedPercent = usedPercent
        self.quotaDescription = quotaDescription
        self.resetsAt = resetsAt
    }
}

public struct ProviderUsage: Codable, Sendable, Equatable {
    public var name: String
    public var isAvailable: Bool
    public var isOnline: Bool
    public var windows: [UsageWindow]
    public var lastError: String?
    public var resetCreditsAvailable: Int?
    public var nextResetCreditExpiresAt: Date?

    public init(
        name: String,
        isAvailable: Bool,
        isOnline: Bool,
        windows: [UsageWindow],
        lastError: String?,
        resetCreditsAvailable: Int? = nil,
        nextResetCreditExpiresAt: Date? = nil
    ) {
        self.name = name
        self.isAvailable = isAvailable
        self.isOnline = isOnline
        self.windows = windows
        self.lastError = lastError
        self.resetCreditsAvailable = resetCreditsAvailable
        self.nextResetCreditExpiresAt = nextResetCreditExpiresAt
    }

    public var primaryPercent: Double? {
        windows.compactMap(\.usedPercent).max()
    }

    public static func unavailable(name: String, message: String) -> ProviderUsage {
        ProviderUsage(
            name: name,
            isAvailable: false,
            isOnline: false,
            windows: [],
            lastError: message
        )
    }

    public static func offline(name: String, message: String) -> ProviderUsage {
        ProviderUsage(
            name: name,
            isAvailable: true,
            isOnline: false,
            windows: [],
            lastError: message
        )
    }
}

public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var codex: ProviderUsage?
    public var cursor: ProviderUsage?
    public var claude: ProviderUsage?
    public var updatedAt: Date

    public init(
        codex: ProviderUsage?,
        cursor: ProviderUsage?,
        claude: ProviderUsage? = nil,
        updatedAt: Date
    ) {
        self.codex = codex
        self.cursor = cursor
        self.claude = claude
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        codex = try container.decodeIfPresent(ProviderUsage.self, forKey: .codex)
        cursor = try container.decodeIfPresent(ProviderUsage.self, forKey: .cursor)
        claude = try container.decodeIfPresent(ProviderUsage.self, forKey: .claude)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(codex, forKey: .codex)
        try container.encodeIfPresent(cursor, forKey: .cursor)
        try container.encodeIfPresent(claude, forKey: .claude)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case codex
        case cursor
        case claude
        case updatedAt
    }

    public static var empty: UsageSnapshot {
        UsageSnapshot(codex: nil, cursor: nil, updatedAt: .distantPast)
    }

    public var providers: [(name: String, usage: ProviderUsage?)] {
        [("Codex", codex), ("Cursor", cursor), ("Claude", claude)]
    }

    public var headlinePercent: Int? {
        let percents = providers.compactMap { $0.usage?.primaryPercent }
        guard let highest = percents.max() else { return nil }
        return Int(highest.rounded())
    }

    public static var placeholder: UsageSnapshot {
        UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [
                    UsageWindow(label: "5 Hour", usedPercent: 72, quotaDescription: nil, resetsAt: Date().addingTimeInterval(3_600)),
                    UsageWindow(label: "Weekly", usedPercent: 43, quotaDescription: nil, resetsAt: Date().addingTimeInterval(259_200)),
                ],
                lastError: nil,
                resetCreditsAvailable: 2,
                nextResetCreditExpiresAt: Date().addingTimeInterval(864_000)
            ),
            cursor: ProviderUsage(
                name: "Cursor",
                isAvailable: true,
                isOnline: true,
                windows: [
                    UsageWindow(
                        label: "Usage",
                        usedPercent: 61,
                        quotaDescription: nil,
                        resetsAt: Date().addingTimeInterval(1_036_800)
                    ),
                ],
                lastError: nil
            ),
            updatedAt: Date()
        )
    }
}
