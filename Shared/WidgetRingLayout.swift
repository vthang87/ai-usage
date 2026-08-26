import Foundation

public struct WidgetRingItem: Equatable, Sendable, Identifiable {
    public let id: String
    public let provider: String
    public let windowLabel: String
    public let percent: Double?
    public let isOnline: Bool
    public let resetsAt: Date?

    public init(
        id: String,
        provider: String,
        windowLabel: String,
        percent: Double?,
        isOnline: Bool,
        resetsAt: Date?
    ) {
        self.id = id
        self.provider = provider
        self.windowLabel = windowLabel
        self.percent = percent
        self.isOnline = isOnline
        self.resetsAt = resetsAt
    }
}

public enum WidgetRingLayout {
    public static func items(from snapshot: UsageSnapshot, capacity: Int) -> [WidgetRingItem] {
        let all = windows(in: snapshot)
        guard capacity > 0 else { return [] }
        if all.count <= capacity {
            return all
        }

        var picked: [WidgetRingItem] = []
        var remaining = all
        for provider in ["Codex", "Cursor"] {
            guard picked.count < capacity, let preferred = preferredWindow(in: remaining, provider: provider) else {
                continue
            }
            picked.append(preferred)
            remaining.removeAll { $0.id == preferred.id }
        }
        for item in remaining {
            guard picked.count < capacity else { break }
            picked.append(item)
        }
        return picked
    }

    private static func windows(in snapshot: UsageSnapshot) -> [WidgetRingItem] {
        var items: [WidgetRingItem] = []
        for (name, usage) in [("Codex", snapshot.codex), ("Cursor", snapshot.cursor)] {
            guard let usage else { continue }
            if usage.windows.isEmpty {
                items.append(
                    WidgetRingItem(
                        id: name,
                        provider: name,
                        windowLabel: name,
                        percent: usage.primaryPercent,
                        isOnline: usage.isOnline,
                        resetsAt: nil
                    )
                )
                continue
            }
            for window in usage.windows {
                items.append(
                    WidgetRingItem(
                        id: "\(name)|\(window.label)",
                        provider: name,
                        windowLabel: window.label,
                        percent: window.usedPercent,
                        isOnline: usage.isOnline,
                        resetsAt: window.resetsAt
                    )
                )
            }
        }
        return items
    }

    private static func preferredWindow(in items: [WidgetRingItem], provider: String) -> WidgetRingItem? {
        let mine = items.filter { $0.provider == provider }
        if let fiveHour = mine.first(where: { $0.windowLabel == "5 Hour" }) {
            return fiveHour
        }
        return mine.min { lhs, rhs in
            (lhs.resetsAt ?? .distantFuture) < (rhs.resetsAt ?? .distantFuture)
        }
    }
}
