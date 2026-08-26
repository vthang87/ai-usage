import SwiftUI

struct DashboardView: View {
    @Environment(UsageCollector.self) private var collector
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Usage")
                        .font(.title2.weight(.semibold))
                    Text("v\(AppVersion.marketing)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Last updated \(UsageFormatting.lastUpdated(collector.snapshot.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(collector.isRefreshing ? "Refreshing…" : "Refresh") {
                    Task { await collector.refresh() }
                }
                .disabled(collector.isRefreshing)
                .controlSize(.small)
                Button(updates.actionTitle) {
                    updates.performAction()
                }
                .disabled(updates.status.isBusy)
                .controlSize(.small)
            }
            HStack(alignment: .top, spacing: 12) {
                ProviderCard(
                    usage: collector.snapshot.codex,
                    fallbackName: "Codex",
                    showExactResetDateTime: collector.settings.showExactResetDateTime
                )
                ProviderCard(
                    usage: collector.snapshot.cursor,
                    fallbackName: "Cursor",
                    showExactResetDateTime: collector.settings.showExactResetDateTime
                )
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 280)
    }
}

private struct ProviderCard: View {
    let usage: ProviderUsage?
    let fallbackName: String
    let showExactResetDateTime: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(fallbackName == "Cursor" ? "CursorAppIcon" : "CodexAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(usage?.name ?? fallbackName)
                    .font(.headline)
                Spacer()
                Text(UsageFormatting.status(usage))
                    .font(.caption)
                    .foregroundStyle(usage?.isOnline == true ? Color.green : Color.secondary)
            }
            if let credits = UsageFormatting.resetCredits(usage?.resetCreditsAvailable) {
                HStack {
                    Text(credits)
                    if let expiry = usage?.nextResetCreditExpiresAt {
                        Text("· next expires \(UsageFormatting.reset(expiry, exact: showExactResetDateTime))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let usage, !usage.windows.isEmpty {
                ForEach(usage.windows) { window in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(window.label)
                            Spacer()
                            Text(UsageFormatting.percent(window.usedPercent))
                                .font(.title3.monospacedDigit().weight(.medium))
                        }
                        ProgressView(value: min(max((window.usedPercent ?? 0) / 100, 0), 1))
                        HStack {
                            if let quota = window.quotaDescription {
                                Text(quota)
                            }
                            Spacer()
                            Text("Reset \(UsageFormatting.reset(window.resetsAt, exact: showExactResetDateTime))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(usage?.lastError ?? "No data yet. Refresh to collect usage.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
