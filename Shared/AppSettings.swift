import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var refreshIntervalSeconds: TimeInterval
    public var unusedQuotaAlertsEnabled: Bool
    public var unusedRemainingThreshold: Double
    public var defaultResetLeadHours: Double
    public var fiveHourResetLeadHours: Double
    public var notifiedAlertKeys: [String]
    public var resetOccurredAlertsEnabled: Bool

    public static let `default` = AppSettings(
        refreshIntervalSeconds: 300,
        unusedQuotaAlertsEnabled: true,
        unusedRemainingThreshold: 70,
        defaultResetLeadHours: 12,
        fiveHourResetLeadHours: 2,
        notifiedAlertKeys: [],
        resetOccurredAlertsEnabled: true
    )

    public init(
        refreshIntervalSeconds: TimeInterval,
        unusedQuotaAlertsEnabled: Bool,
        unusedRemainingThreshold: Double,
        defaultResetLeadHours: Double,
        fiveHourResetLeadHours: Double,
        notifiedAlertKeys: [String],
        resetOccurredAlertsEnabled: Bool
    ) {
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.unusedQuotaAlertsEnabled = unusedQuotaAlertsEnabled
        self.unusedRemainingThreshold = unusedRemainingThreshold
        self.defaultResetLeadHours = defaultResetLeadHours
        self.fiveHourResetLeadHours = fiveHourResetLeadHours
        self.notifiedAlertKeys = notifiedAlertKeys
        self.resetOccurredAlertsEnabled = resetOccurredAlertsEnabled
    }

    public init(from decoder: Decoder) throws {
        let defaults = AppSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshIntervalSeconds)
            ?? defaults.refreshIntervalSeconds
        unusedQuotaAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .unusedQuotaAlertsEnabled)
            ?? defaults.unusedQuotaAlertsEnabled
        unusedRemainingThreshold = try container.decodeIfPresent(Double.self, forKey: .unusedRemainingThreshold)
            ?? defaults.unusedRemainingThreshold
        defaultResetLeadHours = try container.decodeIfPresent(Double.self, forKey: .defaultResetLeadHours)
            ?? defaults.defaultResetLeadHours
        fiveHourResetLeadHours = try container.decodeIfPresent(Double.self, forKey: .fiveHourResetLeadHours)
            ?? defaults.fiveHourResetLeadHours
        notifiedAlertKeys = try container.decodeIfPresent([String].self, forKey: .notifiedAlertKeys)
            ?? defaults.notifiedAlertKeys
        resetOccurredAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .resetOccurredAlertsEnabled)
            ?? defaults.resetOccurredAlertsEnabled
    }
}
