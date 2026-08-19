import Foundation

protocol UsageProvider: Sendable {
    func collect() async -> ProviderUsage
}
