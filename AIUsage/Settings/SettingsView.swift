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
            Section("Alerts") {
                Toggle("Notify before reset", isOn: alertsEnabledBinding)
                Picker("Unused quota above", selection: thresholdBinding) {
                    Text("50%").tag(50.0)
                    Text("60%").tag(60.0)
                    Text("70%").tag(70.0)
                    Text("80%").tag(80.0)
                    Text("90%").tag(90.0)
                }
                .disabled(!collector.settings.unusedQuotaAlertsEnabled)
                Picker("Weekly / other lead time", selection: defaultLeadBinding) {
                    Text("6 hours").tag(6.0)
                    Text("12 hours").tag(12.0)
                    Text("24 hours").tag(24.0)
                }
                .disabled(!collector.settings.unusedQuotaAlertsEnabled)
                Picker("5 Hour lead time", selection: fiveHourLeadBinding) {
                    Text("1 hour").tag(1.0)
                    Text("2 hours").tag(2.0)
                    Text("3 hours").tag(3.0)
                }
                .disabled(!collector.settings.unusedQuotaAlertsEnabled)
                Toggle("Notify when quota resets", isOn: resetOccurredBinding)
                Text("Before-reset alerts fire when unused quota is still high. Reset alerts fire after a window starts a new cycle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: AppVersion.display)
                updateRow
                Button(updates.status == .checking ? "Checking…" : "Check for Updates") {
                    Task { await updates.check(force: true) }
                }
                .disabled(updates.status.isBusy)
                if case .available = updates.status {
                    Button("Install Update") {
                        Task { await updates.installAvailableUpdate() }
                    }
                    Button("Open release page") {
                        updates.openAvailableRelease()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
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
        case let .available(version, _, _):
            Text("\(version) is available")
        case let .downloading(version):
            Text("Downloading \(version)…")
                .foregroundStyle(.secondary)
        case let .installing(version):
            Text("Installing \(version)…")
                .foregroundStyle(.secondary)
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

    private var alertsEnabledBinding: Binding<Bool> {
        setting(\.unusedQuotaAlertsEnabled)
    }

    private var thresholdBinding: Binding<Double> {
        setting(\.unusedRemainingThreshold)
    }

    private var defaultLeadBinding: Binding<Double> {
        setting(\.defaultResetLeadHours)
    }

    private var fiveHourLeadBinding: Binding<Double> {
        setting(\.fiveHourResetLeadHours)
    }

    private var resetOccurredBinding: Binding<Bool> {
        setting(\.resetOccurredAlertsEnabled)
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { collector.settings[keyPath: keyPath] },
            set: { value in
                var next = collector.settings
                next[keyPath: keyPath] = value
                collector.updateSettings(next)
            }
        )
    }
}
