import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot

    var body: some View {
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
        }
    }

    private static let templateIcon: NSImage = {
        let image = NSImage(named: "MenuBarRobot")?.copy() as? NSImage ?? NSImage()
        image.size = NSSize(width: 13, height: 13)
        image.isTemplate = true
        return image
    }()
}
