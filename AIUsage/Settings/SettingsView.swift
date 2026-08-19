import SwiftUI

struct SettingsView: View {
    @Environment(UsageCollector.self) private var collector

    private let options: [TimeInterval] = [60, 120, 300, 600, 900]

    var body: some View {
        Form {
            Picker("Refresh interval", selection: intervalBinding) {
                Text("1 minute").tag(TimeInterval(60))
                Text("2 minutes").tag(TimeInterval(120))
                Text("5 minutes").tag(TimeInterval(300))
                Text("10 minutes").tag(TimeInterval(600))
                Text("15 minutes").tag(TimeInterval(900))
            }
            Text("Refreshes automatically on a timer, at launch, after wake, and when you press Refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360)
    }

    private var intervalBinding: Binding<TimeInterval> {
        Binding(
            get: { collector.refreshInterval },
            set: { collector.setRefreshInterval($0) }
        )
    }
}
