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

    public init(
        name: String,
        isAvailable: Bool,
        isOnline: Bool,
        windows: [UsageWindow],
        lastError: String?
    ) {
        self.name = name
        self.isAvailable = isAvailable
        self.isOnline = isOnline
        self.windows = windows
        self.lastError = lastError
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
    public var updatedAt: Date

    public init(codex: ProviderUsage?, cursor: ProviderUsage?, updatedAt: Date) {
        self.codex = codex
        self.cursor = cursor
        self.updatedAt = updatedAt
    }

    public static var empty: UsageSnapshot {
        UsageSnapshot(codex: nil, cursor: nil, updatedAt: .distantPast)
    }

    public var headlinePercent: Int? {
        let percents = [codex?.primaryPercent, cursor?.primaryPercent].compactMap { $0 }
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
                lastError: nil
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
