import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(UsageEntry(date: Date(), snapshot: .placeholder))
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let interval = UsageStore().refreshInterval()
        completion(Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(interval))))
    }

    private func currentEntry() -> UsageEntry {
        UsageEntry(date: Date(), snapshot: UsageStore().loadSnapshot() ?? .empty)
    }
}
