import SwiftUI
import NDKSwift

struct ActiveSubscriptionsView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var subscriptions: [RelaySubscriptions] = []
    @State private var isLoading = true
    @State private var selectedRelay: String?
    @State private var expandedSubscriptions: Set<String> = []
    
    struct RelaySubscriptions: Identifiable {
        let id = UUID()
        let relayURL: String
        let subscriptions: [NDKRelaySubscriptionInfo]
        let relayState: NDKRelay.State
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                summaryCard
                
                // Relay List
                if isLoading {
                    ProgressView("Loading subscriptions...")
                        .foregroundColor(.white)
                        .padding()
                } else if subscriptions.isEmpty {
                    emptyStateView
                } else {
                    ForEach(subscriptions) { relayData in
                        relayCard(for: relayData)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Active Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.02, blue: 0.08),
                    Color(red: 0.02, green: 0.01, blue: 0.03),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .task {
            await loadSubscriptions()
        }
        .refreshable {
            await loadSubscriptions()
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Subscription Overview")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(totalSubscriptions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Total Subscriptions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 40)
                
                VStack(alignment: .leading) {
                    Text("\(activeRelays)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Active Relays")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 40)
                
                VStack(alignment: .leading) {
                    Text("\(totalEventCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Events Received")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func relayCard(for relayData: RelaySubscriptions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Relay Header
            HStack {
                Circle()
                    .fill(relayData.relayState.connectionState == .connected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(relayData.relayURL.formattedRelayURL)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(relayData.subscriptions.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            // Subscription List
            if selectedRelay == relayData.relayURL {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(relayData.subscriptions, id: \.id) { subscription in
                        subscriptionRow(subscription)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                if selectedRelay == relayData.relayURL {
                    selectedRelay = nil
                } else {
                    selectedRelay = relayData.relayURL
                }
            }
        }
    }
    
    private func subscriptionRow(_ subscription: NDKRelaySubscriptionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subscription Header
            HStack {
                Text("ID: \(subscription.id.prefix(8))...")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(Color.white.opacity(0.8))
                
                Spacer()
                
                if subscription.eventCount > 0 {
                    Label("\(subscription.eventCount)", systemImage: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Button(action: {
                    withAnimation {
                        if expandedSubscriptions.contains(subscription.id) {
                            expandedSubscriptions.remove(subscription.id)
                        } else {
                            expandedSubscriptions.insert(subscription.id)
                        }
                    }
                }) {
                    Image(systemName: expandedSubscriptions.contains(subscription.id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Time info
            HStack {
                Text("Created: \(subscription.createdAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                if let lastEvent = subscription.lastEventAt {
                    Text("• Last event: \(lastEvent, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Note about per-kind breakdown
            if subscription.eventCount > 0 && expandedSubscriptions.contains(subscription.id) {
                Text("Note: Event breakdown by kind not available in current NDK version")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .italic()
            }
            
            // Filters (expandable)
            if expandedSubscriptions.contains(subscription.id) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filters:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ForEach(Array(subscription.filters.enumerated()), id: \.offset) { index, filter in
                        filterView(filter, index: index)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func filterView(_ filter: NDKFilter, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Filter \(index + 1)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                if let kinds = filter.kinds, !kinds.isEmpty {
                    filterRow("Kinds", value: formatEventKinds(Set(kinds)))
                }
                
                if let authors = filter.authors, !authors.isEmpty {
                    filterRow("Authors", value: "\(authors.count) pubkeys")
                }
                
                if let limit = filter.limit {
                    filterRow("Limit", value: String(limit))
                }
                
                if let since = filter.since {
                    filterRow("Since", value: DateFormatters.formatTimestampForDisplay(Int64(since)))
                }
                
                if let until = filter.until {
                    filterRow("Until", value: DateFormatters.formatTimestampForDisplay(Int64(until)))
                }
                
                if let ids = filter.ids, !ids.isEmpty {
                    filterRow("Event IDs", value: "\(ids.count) events")
                }
                
                if let tags = filter.tags, !tags.isEmpty {
                    filterRow("Tags", value: "\(tags.count) filters")
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.purple.opacity(0.1))
            )
        }
    }
    
    private func filterRow(_ label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundColor(Color.white.opacity(0.8))
                .lineLimit(1)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Active Subscriptions")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("No subscriptions are currently active on any relay")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Computed Properties
    
    private var totalSubscriptions: Int {
        subscriptions.reduce(0) { $0 + $1.subscriptions.count }
    }
    
    private var activeRelays: Int {
        subscriptions.filter { $0.relayState.connectionState == .connected }.count
    }
    
    private var totalEventCount: Int {
        subscriptions.reduce(0) { total, relay in
            total + relay.subscriptions.reduce(0) { $0 + $1.eventCount }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadSubscriptions() async {
        isLoading = true
        
        let ndk = nostrManager.ndk
        
        let relays = await ndk.relays
        var newSubscriptions: [RelaySubscriptions] = []
        
        for relay in relays {
            let activeSubs = await relay.activeSubscriptions
            let connectionState = await relay.connectionState
            
            if !activeSubs.isEmpty || connectionState == .connected {
                // Create a state object for our view
                let state = NDKRelay.State(
                    connectionState: connectionState,
                    stats: await relay.stats,
                    info: await relay.info,
                    activeSubscriptions: activeSubs
                )
                
                newSubscriptions.append(
                    RelaySubscriptions(
                        relayURL: relay.url,
                        subscriptions: activeSubs,
                        relayState: state
                    )
                )
            }
        }
        
        await MainActor.run {
            self.subscriptions = newSubscriptions.sorted { $0.subscriptions.count > $1.subscriptions.count }
            self.isLoading = false
        }
    }
    
    
    
    private func formatEventKinds(_ kinds: Set<Int>) -> String {
        let sortedKinds = kinds.sorted()
        let namedKinds = sortedKinds.map { kind in
            switch kind {
            case 0: return "0 (Profile)"
            case 1: return "1 (Note)"
            case 3: return "3 (Contacts)"
            case 4: return "4 (DM)"
            case 5: return "5 (Deletion)"
            case 6: return "6 (Repost)"
            case 7: return "7 (Reaction)"
            case 8: return "8 (Badge)"
            case 9: return "9 (Group Chat)"
            case 10: return "10 (Group Thread)"
            case 11: return "11 (Group Thread Reply)"
            case 30000: return "30000 (Lists)"
            case 30001: return "30001 (Bookmarks)"
            case 30008: return "30008 (Profile Badges)"
            case 30009: return "30009 (Badge Definition)"
            case 30023: return "30023 (Long Form)"
            case 30078: return "30078 (App Data)"
            case 31234: return "31234 (Draft)"
            case 32123: return "32123 (Live Activity)"
            default: return String(kind)
            }
        }
        
        if namedKinds.count > 3 {
            return namedKinds.prefix(3).joined(separator: ", ") + " +\(namedKinds.count - 3)"
        }
        return namedKinds.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        ActiveSubscriptionsView()
            .environmentObject(NostrManager())
    }
}