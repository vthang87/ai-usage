import Foundation

public enum UsageFormatting {
    public static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    public static func reset(_ date: Date?) -> String {
        guard let date else { return "—" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "soon" }
        let minutes = Int(remaining / 60)
        if minutes >= 1_440 {
            return "\(minutes / 1_440)d \((minutes % 1_440) / 60)h"
        }
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(max(minutes, 1))m"
    }

    public static func lastUpdated(_ date: Date) -> String {
        if date == .distantPast { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    public static func status(_ usage: ProviderUsage?) -> String {
        guard let usage else { return "Unknown" }
        if !usage.isAvailable { return "Unavailable" }
        if usage.isOnline { return "Online" }
        return "Offline"
    }
}
