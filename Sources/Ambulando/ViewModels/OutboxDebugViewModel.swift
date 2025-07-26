import Foundation
import SwiftUI
import NDKSwift

@MainActor
class OutboxDebugViewModel: ObservableObject {
    @Published var outboxEntries: [OutboxEntry] = []
    @Published var summary: OutboxSummary = .empty
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private var relayUpdateTask: Task<Void, Never>?
    private let ndk: NDK?
    
    init(ndk: NDK?) {
        self.ndk = ndk
    }
    
    deinit {
        relayUpdateTask?.cancel()
    }
    
    func loadData() async {
        guard let ndk = ndk else {
            errorMessage = "NDK not available"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Get current outbox statistics
        let stats = await ndk.outbox.getRelayUpdateStats()
        
        // Get all tracked outbox items
        let outboxItems = await getAllOutboxItems()
        
        // Process entries and calculate summary
        let entries = await processOutboxItems(outboxItems)
        let summaryData = calculateSummary(from: entries, stats: stats)
        
        // Update UI
        self.outboxEntries = entries
        self.summary = summaryData
        
        isLoading = false
        
        // Start real-time updates
        startRealtimeUpdates()
    }
    
    private func getAllOutboxItems() async -> [NDKOutboxItem] {
        guard let ndk = ndk else { return [] }
        
        // Get all tracked items from the outbox manager
        return await ndk.outbox.getAllTrackedItems()
    }
    
    private func processOutboxItems(_ items: [NDKOutboxItem]) async -> [OutboxEntry] {
        var entries: [OutboxEntry] = []
        
        for item in items {
            // Try to get display name from profile cache
            let displayName = await getDisplayName(for: item.pubkey)
            let entry = OutboxEntry(from: item, displayName: displayName)
            entries.append(entry)
        }
        
        // Sort by most recently updated
        return entries.sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    private func getDisplayName(for pubkey: String) async -> String? {
        guard let ndk = ndk else { return nil }
        
        // Attempt to get profile from cache (don't fetch if not available)
        for await profile in await ndk.profileManager.observe(for: pubkey, maxAge: TimeConstants.hour) {
            if let profile = profile {
                return profile.name ?? profile.displayName
            }
        }
        
        return nil
    }
    
    private func calculateSummary(from entries: [OutboxEntry], stats: RelayUpdateStats) -> OutboxSummary {
        let allRelays = Set(entries.flatMap { entry in
            entry.readRelays.map { $0.url } + entry.writeRelays.map { $0.url }
        })
        
        let totalRelayCount = entries.reduce(0) { $0 + $1.totalRelayCount }
        let averageRelays = entries.isEmpty ? 0 : Double(totalRelayCount) / Double(entries.count)
        
        return OutboxSummary(
            totalUsers: entries.count,
            totalRelays: allRelays.count,
            averageRelaysPerUser: averageRelays,
            lastUpdateTime: entries.first?.lastUpdated ?? Date(),
            unknownUsersCount: stats.totalUnknownAuthors,
            activeSubscriptions: stats.activeSubscriptions
        )
    }
    
    private func startRealtimeUpdates() {
        guard let ndk = ndk else { return }
        
        relayUpdateTask?.cancel()
        relayUpdateTask = Task {
            for await update in await ndk.outbox.relayUpdates {
                await handleRelayUpdate(update)
            }
        }
    }
    
    private func handleRelayUpdate(_ update: RelayUpdateEvent) async {
        // Update existing entry or add new one
        if let index = outboxEntries.firstIndex(where: { $0.pubkey == update.pubkey }) {
            // Update existing entry
            let displayName = await getDisplayName(for: update.pubkey)
            let mockItem = createMockOutboxItem(from: update, displayName: displayName)
            let updatedEntry = OutboxEntry(from: mockItem, displayName: displayName)
            outboxEntries[index] = updatedEntry
        } else {
            // Add new entry
            let displayName = await getDisplayName(for: update.pubkey)
            let mockItem = createMockOutboxItem(from: update, displayName: displayName)
            let newEntry = OutboxEntry(from: mockItem, displayName: displayName)
            outboxEntries.append(newEntry)
        }
        
        // Recalculate summary
        if let ndk = ndk {
            let stats = await ndk.outbox.getRelayUpdateStats()
            summary = calculateSummary(from: outboxEntries, stats: stats)
        }
        
        // Re-sort entries
        outboxEntries.sort { $0.lastUpdated > $1.lastUpdated }
    }
    
    private func createMockOutboxItem(from update: RelayUpdateEvent, displayName: String?) -> NDKOutboxItem {
        // Convert RelayUpdateEvent to NDKOutboxItem for UI display
        let readRelays = Set(update.relays.readRelays.map { url in
            RelayInfo(url: url, metadata: nil) // We don't have metadata in the update
        })
        
        let writeRelays = Set(update.relays.writeRelays.map { url in
            RelayInfo(url: url, metadata: nil)
        })
        
        return NDKOutboxItem(
            pubkey: update.pubkey,
            readRelays: readRelays,
            writeRelays: writeRelays,
            fetchedAt: update.timestamp,
            source: .nip65 // Assume NIP-65 for updates
        )
    }
    
    func refresh() {
        Task {
            await loadData()
        }
    }
    
    func trackUser(_ pubkey: String) {
        guard let ndk = ndk else { return }
        
        Task {
            await ndk.outbox.trackUser(pubkey)
        }
    }
    
    func untrackUser(_ pubkey: String) {
        guard let ndk = ndk else { return }
        
        Task {
            await ndk.outbox.untrackUser(pubkey)
        }
    }
    
    // Filtered entries for search
    func filteredEntries(searchText: String) -> [OutboxEntry] {
        guard !searchText.isEmpty else { return outboxEntries }
        
        let lowercased = searchText.lowercased()
        return outboxEntries.filter { entry in
            entry.pubkey.lowercased().contains(lowercased) ||
            entry.npub.lowercased().contains(lowercased) ||
            entry.displayName?.lowercased().contains(lowercased) == true ||
            entry.readRelays.contains { $0.url.lowercased().contains(lowercased) } ||
            entry.writeRelays.contains { $0.url.lowercased().contains(lowercased) }
        }
    }
}

// MARK: - Mock Data for Development

extension OutboxDebugViewModel {
    static func createMockData() -> OutboxDebugViewModel {
        let viewModel = OutboxDebugViewModel(ndk: nil)
        
        // Create some mock entries for UI development
        let mockEntries = [
            createMockEntry(
                pubkey: "82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2",
                displayName: "jack",
                readRelays: ["wss://relay.damus.io", "wss://nos.lol"],
                writeRelays: ["wss://relay.damus.io", "wss://nostr.wine"]
            ),
            createMockEntry(
                pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
                displayName: "fiatjaf",
                readRelays: ["wss://nostr.wine", "wss://relay.nostr.band"],
                writeRelays: ["wss://nostr.wine"]
            )
        ]
        
        viewModel.outboxEntries = mockEntries
        viewModel.summary = OutboxSummary(
            totalUsers: mockEntries.count,
            totalRelays: 4,
            averageRelaysPerUser: 2.5,
            lastUpdateTime: Date(),
            unknownUsersCount: 15,
            activeSubscriptions: 3
        )
        viewModel.isLoading = false
        
        return viewModel
    }
    
    private static func createMockEntry(
        pubkey: String,
        displayName: String,
        readRelays: [String],
        writeRelays: [String]
    ) -> OutboxEntry {
        let readRelayInfos = readRelays.map { url in
            RelayInfo(url: url, metadata: RelayMetadata(
                score: Double.random(in: 0.3...0.9),
                lastConnectedAt: Date().addingTimeInterval(-Double.random(in: 0...3600)),
                avgResponseTime: Double.random(in: 100...500),
                failureCount: Int.random(in: 0...5),
                authRequired: Bool.random(),
                paymentRequired: Bool.random()
            ))
        }
        
        let writeRelayInfos = writeRelays.map { url in
            RelayInfo(url: url, metadata: RelayMetadata(
                score: Double.random(in: 0.3...0.9),
                lastConnectedAt: Date().addingTimeInterval(-Double.random(in: 0...3600)),
                avgResponseTime: Double.random(in: 100...500),
                failureCount: Int.random(in: 0...5),
                authRequired: Bool.random(),
                paymentRequired: Bool.random()
            ))
        }
        
        let mockItem = NDKOutboxItem(
            pubkey: pubkey,
            readRelays: Set(readRelayInfos),
            writeRelays: Set(writeRelayInfos),
            fetchedAt: Date().addingTimeInterval(-Double.random(in: 0...86400)),
            source: .nip65
        )
        
        return OutboxEntry(from: mockItem, displayName: displayName)
    }
}