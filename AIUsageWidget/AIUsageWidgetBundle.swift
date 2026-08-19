import SwiftUI
import WidgetKit

struct AIUsageSmallWidget: Widget {
    let kind = "AIUsageSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            SmallWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color.black.opacity(0.28)
                }
        }
        .configurationDisplayName("AI Usage")
        .description("Codex and Cursor as circular meters.")
        .supportedFamilies([.systemSmall])
    }
}

struct AIUsageMediumWidget: Widget {
    let kind = "AIUsageMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            MediumWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color.black.opacity(0.28)
                }
        }
        .configurationDisplayName("AI Usage")
        .description("Codex and Cursor circular usage meters.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIUsageSmallWidget()
        AIUsageMediumWidget()
    }
}

#Preview("Small", as: .systemSmall) {
    AIUsageSmallWidget()
} timeline: {
    UsageEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    AIUsageMediumWidget()
} timeline: {
    UsageEntry(date: .now, snapshot: .placeholder)
}
