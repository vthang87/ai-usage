import AppKit
import SwiftUI

struct MenuBarLabel: View {
    @Environment(UsageCollector.self) private var collector

    var body: some View {
        let snapshot = collector.snapshot
        HStack(spacing: 3) {
            Image(nsImage: Self.templateIcon)
            if let percent = snapshot.headlinePercent {
                Text("\(percent)%")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            } else {
                Text("AI")
                    .font(.system(size: 12, weight: .medium))
            }
            if let count = snapshot.codex?.resetCreditsAvailable {
                Text("·")
                    .font(.system(size: 12, weight: .medium))
                Text("\(count)R")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibilityLabel(for: snapshot))
    }

    private func accessibilityLabel(for snapshot: UsageSnapshot) -> String {
        let percent = snapshot.headlinePercent.map { "\($0) percent" } ?? "No usage"
        if let count = snapshot.codex?.resetCreditsAvailable {
            let resets = count == 1 ? "1 Codex reset" : "\(count) Codex resets"
            return "\(percent), \(resets)"
        }
        return percent
    }

    private static let templateIcon: NSImage = {
        let image = NSImage(named: "MenuBarRobot")?.copy() as? NSImage ?? NSImage()
        image.size = NSSize(width: 13, height: 13)
        image.isTemplate = true
        return image
    }()
}
