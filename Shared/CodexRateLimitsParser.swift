import Foundation

enum FlexibleJSONNumber {
    static func double(from value: Any?) -> Double? {
        switch value {
        case let number as Double: return number
        case let number as Int: return Double(number)
        case let number as NSNumber: return number.doubleValue
        case let text as String: return Double(text)
        default: return nil
        }
    }

    static func int(from value: Any?) -> Int? {
        switch value {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let number as NSNumber: return number.intValue
        case let text as String: return Int(text)
        default: return nil
        }
    }
}

enum FlexibleJSONDate {
    static func parse(_ value: Any?) -> Date? {
        if let number = FlexibleJSONNumber.double(from: value) {
            return fromUnix(number)
        }
        if let text = value as? String {
            if let number = Double(text) {
                return fromUnix(number)
            }
            return ISO8601DateFormatter().date(from: text)
        }
        return nil
    }

    private static func fromUnix(_ value: Double) -> Date {
        if value > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: value / 1_000)
        }
        return Date(timeIntervalSince1970: value)
    }
}

public enum CodexRateLimitsParser {
    public static func windows(from result: Any) throws -> [UsageWindow] {
        guard let root = result as? [String: Any] else {
            throw ParseError.unexpectedShape("Codex rate limits root was not an object")
        }

        let limits: [String: Any]
        if let nested = root["rateLimits"] as? [String: Any] {
            limits = nested
        } else if root["primary"] != nil {
            limits = root
        } else {
            throw ParseError.unexpectedShape("Codex rate limits payload was missing primary/secondary windows")
        }

        var windows: [UsageWindow] = []
        if let primary = limits["primary"] as? [String: Any], let window = window(from: primary) {
            windows.append(window)
        }
        if let secondary = limits["secondary"] as? [String: Any], let window = window(from: secondary) {
            windows.append(window)
        }
        if windows.isEmpty {
            throw ParseError.unexpectedShape("Codex rate limits payload had no usable windows")
        }
        return windows
    }

    private static func window(from object: [String: Any]) -> UsageWindow? {
        let minutes = FlexibleJSONNumber.int(from: object["windowDurationMins"])
        let percent = FlexibleJSONNumber.double(from: object["usedPercent"])
        let reset = FlexibleJSONDate.parse(object["resetsAt"])
        guard percent != nil || reset != nil else { return nil }
        return UsageWindow(
            label: label(forMinutes: minutes),
            usedPercent: percent,
            quotaDescription: minutes.map { "\($0) min window" },
            resetsAt: reset
        )
    }

    public static func label(forMinutes minutes: Int?) -> String {
        guard let minutes else { return "Usage" }
        if (240...360).contains(minutes) { return "5 Hour" }
        if (9_000...11_000).contains(minutes) { return "Weekly" }
        if minutes >= 60 && minutes % 60 == 0 {
            return "\(minutes / 60) Hour"
        }
        return "\(minutes) min"
    }
}

public enum ParseError: LocalizedError {
    case unexpectedShape(String)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedShape(message): message
        }
    }
}
