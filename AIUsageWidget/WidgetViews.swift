import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let snapshot: UsageSnapshot
    var showExactResetDateTime = false

    var body: some View {
        UsageRingRow(
            slots: UsageRingSlot.slots(from: snapshot, capacity: 2, showExactResetDateTime: showExactResetDateTime),
            ringSize: 54,
            lineWidth: 5
        )
    }
}

struct MediumWidgetView: View {
    let snapshot: UsageSnapshot
    var showExactResetDateTime = false

    var body: some View {
        UsageRingRow(
            slots: UsageRingSlot.slots(from: snapshot, capacity: 4, showExactResetDateTime: showExactResetDateTime),
            ringSize: 48,
            lineWidth: 4.5
        )
    }
}

private struct UsageRingRow: View {
    let slots: [UsageRingSlot]
    let ringSize: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(slots) { slot in
                UsageRingCell(slot: slot, ringSize: ringSize, lineWidth: lineWidth)
                    .frame(maxWidth: .infinity)
                    .opacity(slot.showsGlyph ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct UsageRingCell: View {
    let slot: UsageRingSlot
    let ringSize: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)

                if let fraction = slot.fraction, fraction > 0 {
                    Circle()
                        .trim(from: 0.018, to: max(0.018, fraction))
                        .stroke(
                            slot.ringColor.opacity(0.95),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }

                if slot.showsGlyph {
                    Image(slot.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: ringSize * 0.52, height: ringSize * 0.52)
                        .clipShape(RoundedRectangle(cornerRadius: ringSize * 0.13, style: .continuous))
                        .opacity(0.92)
                }
            }
            .frame(width: ringSize, height: ringSize)

            Text(slot.percentLabel)
                .font(.system(size: 12, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(Color.primary.opacity(slot.showsGlyph ? 0.92 : 0))
                .frame(height: 14)

            Text(slot.resetLabel)
                .font(.system(size: 10, weight: .regular))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Color.secondary.opacity(slot.showsGlyph ? 0.85 : 0))
                .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slot.accessibilityLabel)
    }

    private var trackColor: Color {
        slot.showsGlyph ? slot.ringColor.opacity(0.22) : Color.primary.opacity(0.12)
    }
}

private struct UsageRingSlot: Identifiable {
    let id: String
    let assetName: String
    let percent: Double?
    let isOnline: Bool
    let showsGlyph: Bool
    let resetsAt: Date?
    let showExactResetDateTime: Bool

    var fraction: CGFloat? {
        guard let percent else { return nil }
        return CGFloat(min(max(percent, 0), 100) / 100)
    }

    var percentLabel: String {
        guard showsGlyph else { return " " }
        return UsageFormatting.percent(percent)
    }

    var resetLabel: String {
        guard showsGlyph else { return " " }
        return UsageFormatting.reset(resetsAt, exact: showExactResetDateTime)
    }

    var ringColor: Color {
        if let percent {
            if percent >= 95 { return .red }
            if percent >= 80 { return .yellow }
        }
        if id.contains("Other Models") {
            return Color(red: 0.40, green: 0.28, blue: 0.86)
        }
        if id.hasPrefix("Cursor") {
            return Color(red: 0.67, green: 0.36, blue: 1.0)
        }
        return Color(red: 0.22, green: 0.90, blue: 0.72)
    }

    var accessibilityLabel: String {
        if !showsGlyph { return "Empty" }
        return "\(id) \(percentLabel), resets \(resetLabel)"
    }

    static func empty(id: String) -> UsageRingSlot {
        UsageRingSlot(
            id: id,
            assetName: "CodexAppIcon",
            percent: nil,
            isOnline: false,
            showsGlyph: false,
            resetsAt: nil,
            showExactResetDateTime: false
        )
    }

    static func slots(from snapshot: UsageSnapshot, capacity: Int, showExactResetDateTime: Bool = false) -> [UsageRingSlot] {
        var items = WidgetRingLayout.items(from: snapshot, capacity: capacity).map { item in
            UsageRingSlot(
                id: item.id,
                assetName: item.provider == "Cursor" ? "CursorAppIcon" : "CodexAppIcon",
                percent: item.percent,
                isOnline: item.isOnline,
                showsGlyph: true,
                resetsAt: item.resetsAt,
                showExactResetDateTime: showExactResetDateTime
            )
        }
        while items.count < capacity {
            items.append(.empty(id: "empty-\(items.count)"))
        }
        return items
    }
}
