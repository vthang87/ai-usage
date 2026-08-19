import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(UsageCollector.self) private var collector
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            providerSection(title: "Codex", usage: collector.snapshot.codex, showsReset: false)
            providerSection(title: "Cursor", usage: collector.snapshot.cursor, showsReset: true)
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
            }
            .controlSize(.small)
            HStack {
                SettingsLink {
                    Text("Settings…")
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 280)
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
    private func providerSection(title: String, usage: ProviderUsage?, showsReset: Bool) -> some View {
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
                ForEach(Array(usage.windows.enumerated()), id: \.element.id) { index, window in
                    HStack {
                        Text(window.label)
                        Spacer()
                        Text(UsageFormatting.percent(window.usedPercent))
                            .monospacedDigit()
                            .foregroundStyle(percentColor(window.usedPercent))
                        if showsReset, index == usage.windows.count - 1 {
                            Text(UsageFormatting.reset(window.resetsAt))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 52, alignment: .trailing)
                        }
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
