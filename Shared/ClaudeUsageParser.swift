import Foundation

public enum ClaudeUsageParser {
    public static func windows(from payload: Any) throws -> [UsageWindow] {
        guard let root = payload as? [String: Any] else {
            throw ParseError.unexpectedShape("Claude usage root was not an object")
        }

        if let limits = root["limits"] as? [Any] {
            let windows = limits.compactMap { item -> UsageWindow? in
                guard let object = item as? [String: Any] else { return nil }
                return window(fromLimit: object)
            }
            if !windows.isEmpty {
                return windows
            }
        }

        var windows: [UsageWindow] = []
        if let session = window(fromBucket: root["five_hour"], label: "Session") {
            windows.append(session)
        }
        if let week = window(fromBucket: root["seven_day"], label: "Weekly") {
            windows.append(week)
        }
        if windows.isEmpty {
            throw ParseError.unexpectedShape("Claude usage payload was missing limits")
        }
        return windows
    }

    private static func window(fromLimit item: [String: Any]) -> UsageWindow? {
        guard let kind = item["kind"] as? String else { return nil }
        let label: String
        switch kind {
        case "session":
            label = "Session"
        case "weekly_all":
            label = "Weekly"
        case "weekly_scoped":
            let model = ((item["scope"] as? [String: Any])?["model"] as? [String: Any])?["display_name"] as? String
            guard let model, !model.isEmpty else { return nil }
            let percent = FlexibleJSONNumber.double(from: item["percent"]) ?? 0
            let active = item["is_active"] as? Bool ?? false
            if percent == 0, !active { return nil }
            label = model
        default:
            return nil
        }
        return UsageWindow(
            label: label,
            usedPercent: FlexibleJSONNumber.double(from: item["percent"]),
            quotaDescription: nil,
            resetsAt: parseDate(item["resets_at"])
        )
    }

    private static func window(fromBucket value: Any?, label: String) -> UsageWindow? {
        guard let bucket = value as? [String: Any],
              let utilization = FlexibleJSONNumber.double(from: bucket["utilization"])
        else { return nil }
        let percent = utilization <= 1 ? utilization * 100 : utilization
        return UsageWindow(
            label: label,
            usedPercent: percent,
            quotaDescription: nil,
            resetsAt: parseDate(bucket["resets_at"])
        )
    }

    private static func parseDate(_ value: Any?) -> Date? {
        if let text = value as? String {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: text) {
                return date
            }
        }
        return FlexibleJSONDate.parse(value)
    }
}
