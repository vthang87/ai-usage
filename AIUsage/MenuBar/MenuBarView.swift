import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(UsageCollector.self) private var collector
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            providerSection(title: "Codex", usage: collector.snapshot.codex)
            providerSection(title: "Cursor", usage: collector.snapshot.cursor)
            updateStatusLine
            Divider()
            HStack {
                Button(collector.isRefreshing ? "Refreshing…" : "Refresh") {
                    Task { await collector.refresh() }
                }
                .disabled(collector.isRefreshing)
                Button("Open Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")
                }
                Button(checkUpdateTitle) {
                    checkOrOpenUpdate()
                }
                .disabled(updates.status == .checking)
            }
            .controlSize(.small)
            HStack {
                SettingsLink {
                    Text("Settings…")
                }
                Spacer()
                Text("v\(AppVersion.marketing)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 312)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("MenuBarRobot")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text("AI Usage")
                .font(.headline)
            Spacer()
            Text(UsageFormatting.lastUpdated(collector.snapshot.updatedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var updateStatusLine: some View {
        switch updates.status {
        case .idle:
            EmptyView()
        case .checking:
            Text("Checking for updates…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .upToDate:
            Text("You’re up to date")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .available(version, _):
            Text("Version \(version) is available")
                .font(.caption)
                .foregroundStyle(.blue)
        case let .failed(message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var checkUpdateTitle: String {
        switch updates.status {
        case .checking:
            return "Checking…"
        case let .available(version, _):
            return "Download \(version)"
        default:
            return "Check Update"
        }
    }

    private func checkOrOpenUpdate() {
        if case .available = updates.status {
            updates.openAvailableRelease()
        } else {
            Task { await updates.check(force: true) }
        }
    }

    @ViewBuilder
    private func providerSection(title: String, usage: ProviderUsage?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                providerMark(for: title)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Circle()
                    .fill(usage?.isOnline == true ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(UsageFormatting.status(usage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let usage, !usage.windows.isEmpty {
                ForEach(usage.windows) { window in
                    HStack {
                        Text(window.label)
                        Spacer()
                        Text(UsageFormatting.percent(window.usedPercent))
                            .monospacedDigit()
                            .foregroundStyle(percentColor(window.usedPercent))
                        Text(UsageFormatting.reset(window.resetsAt))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                    .font(.callout)
                }
            } else if let message = usage?.lastError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func providerMark(for title: String) -> some View {
        Image(title == "Cursor" ? "CursorAppIcon" : "CodexAppIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
    }

    private func percentColor(_ value: Double?) -> Color {
        guard let value else { return .primary }
        if value >= 90 { return .red }
        if value >= 70 { return .orange }
        return .primary
    }
}
