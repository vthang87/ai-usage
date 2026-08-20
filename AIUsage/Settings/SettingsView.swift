import SwiftUI

struct SettingsView: View {
    @Environment(UsageCollector.self) private var collector
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        Form {
            Section("Usage") {
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
            Section("About") {
                LabeledContent("Version", value: AppVersion.display)
                updateRow
                Button(updates.status == .checking ? "Checking…" : "Check for Updates") {
                    Task { await updates.check(force: true) }
                }
                .disabled(updates.status == .checking)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var updateRow: some View {
        switch updates.status {
        case .idle:
            Text("Not checked yet")
                .foregroundStyle(.secondary)
        case .checking:
            Text("Checking GitHub Releases…")
                .foregroundStyle(.secondary)
        case .upToDate:
            Text("You’re up to date")
                .foregroundStyle(.secondary)
        case let .available(version, _):
            HStack {
                Text("\(version) is available")
                    .foregroundStyle(.primary)
                Spacer()
                Button("Download") {
                    updates.openAvailableRelease()
                }
            }
        case let .failed(message):
            Text(message)
                .foregroundStyle(.red)
        }
    }

    private var intervalBinding: Binding<TimeInterval> {
        Binding(
            get: { collector.refreshInterval },
            set: { collector.setRefreshInterval($0) }
        )
    }
}
