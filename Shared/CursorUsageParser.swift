import Foundation

public enum CursorUsageParser {
    public static func windows(from payload: Any) throws -> [UsageWindow] {
        guard let root = payload as? [String: Any] else {
            throw ParseError.unexpectedShape("Cursor usage root was not an object")
        }

        guard let plan = root["planUsage"] as? [String: Any] else {
            throw ParseError.unexpectedShape("Cursor usage payload was missing planUsage")
        }

        let reset = FlexibleJSONDate.parse(root["billingCycleEnd"])
        let quota = quotaDescription(from: plan)
        var windows: [UsageWindow] = []

        if let auto = FlexibleJSONNumber.double(from: plan["autoPercentUsed"]) {
            windows.append(
                UsageWindow(
                    label: "Cursor Models",
                    usedPercent: auto,
                    quotaDescription: quota,
                    resetsAt: reset
                )
            )
        }
        if let api = FlexibleJSONNumber.double(from: plan["apiPercentUsed"]) {
            windows.append(
                UsageWindow(
                    label: "Other Models",
                    usedPercent: api,
                    quotaDescription: nil,
                    resetsAt: reset
                )
            )
        }
        if windows.isEmpty {
            let percent = FlexibleJSONNumber.double(from: plan["totalPercentUsed"])
            guard let percent else {
                throw ParseError.unexpectedShape("Cursor usage payload was missing percent used")
            }
            windows.append(
                UsageWindow(
                    label: "Usage",
                    usedPercent: percent,
                    quotaDescription: quota,
                    resetsAt: reset
                )
            )
        }
        return windows
    }

    private static func quotaDescription(from plan: [String: Any]) -> String? {
        let used = FlexibleJSONNumber.double(from: plan["includedSpend"])
            ?? FlexibleJSONNumber.double(from: plan["totalSpend"])
        let limit = FlexibleJSONNumber.double(from: plan["limit"])
        guard let used, let limit, limit > 0 else { return nil }
        return String(format: "%.0f / %.0f", used, limit)
    }
}
