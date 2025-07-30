import SwiftUI
import NDKSwift

struct DebugMenuView: View {
    @EnvironmentObject var nostrManager: NostrManager
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: OutboxDebugView(ndk: nostrManager.ndk)) {
                    DebugMenuRow(
                        title: "Outbox Configuration",
                        subtitle: "View relay mappings and outbox statistics",
                        icon: "network.badge.shield.half.filled",
                        iconColor: .purple
                    )
                }
                
                NavigationLink(destination: RelayDebugView()) {
                    DebugMenuRow(
                        title: "Relay Connections",
                        subtitle: "Monitor relay status and connections",
                        icon: "antenna.radiowaves.left.and.right",
                        iconColor: .blue
                    )
                }
                
                NavigationLink(destination: CacheDebugView().environmentObject(nostrManager)) {
                    DebugMenuRow(
                        title: "Cache Inspector",
                        subtitle: "View cached events and profiles",
                        icon: "externaldrive.fill",
                        iconColor: .green
                    )
                }
                
                NavigationLink(destination: EventDebugView()) {
                    DebugMenuRow(
                        title: "Event Inspector",
                        subtitle: "View raw event data and signatures",
                        icon: "doc.text.magnifyingglass",
                        iconColor: .orange
                    )
                }
                
                NavigationLink(destination: ActiveSubscriptionsView()) {
                    DebugMenuRow(
                        title: "Active Subscriptions",
                        subtitle: "Monitor active subscriptions on each relay",
                        icon: "dot.radiowaves.left.and.right",
                        iconColor: .cyan
                    )
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            Section {
                DebugInfoRow(
                    title: "NDK Version",
                    value: getNDKVersion()
                )
                
                DebugInfoRow(
                    title: "Active Relays",
                    value: getActiveRelayCount()
                )
                
                DebugInfoRow(
                    title: "Authentication",
                    value: getAuthStatus()
                )
                
                DebugInfoRow(
                    title: "Session Active",
                    value: getSessionStatus()
                )
            } header: {
                Text("System Info")
                    .foregroundColor(Color.white.opacity(0.8))
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
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
    }
    
    private func getNDKVersion() -> String {
        // This would ideally come from NDKSwift package info
        return "1.0.0" // Placeholder
    }
    
    private func getActiveRelayCount() -> String {
        // Get active relay count from default + user added relays
        guard nostrManager.isInitialized else { return "0" }
        let totalRelays = nostrManager.defaultRelays.count + nostrManager.userAddedRelays.count
        return "\(totalRelays)"
    }
    
    private func getAuthStatus() -> String {
        return nostrManager.isAuthenticated ? "Authenticated" : "Not Authenticated"
    }
    
    private func getSessionStatus() -> String {
        let ndk = nostrManager.ndk
        return ndk.sessionData != nil ? "Active" : "Inactive"
    }
}

struct DebugMenuRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 4)
    }
}

struct DebugInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Placeholder Views (to be implemented later)

struct RelayDebugView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var relayInfo: [RelayInfo] = []
    @State private var isLoading = true
    @State private var selectedRelay: String?
    
    struct RelayInfo: Identifiable {
        let id = UUID()
        let url: String
        let isConnected: Bool
        let subscriptionCount: Int
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                summaryCard
                
                // Relay List
                if isLoading {
                    ProgressView("Loading relay data...")
                        .foregroundColor(.white)
                        .padding()
                } else if relayInfo.isEmpty {
                    emptyStateView
                } else {
                    ForEach(relayInfo) { relay in
                        relayCard(for: relay)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Relay Connections")
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
            await loadRelayInfo()
        }
        .refreshable {
            await loadRelayInfo()
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Relay Overview")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(totalRelays)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Total Relays")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 40)
                
                VStack(alignment: .leading) {
                    Text("\(connectedRelays)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 40)
                
                VStack(alignment: .leading) {
                    Text("\(totalSubscriptions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Subscriptions")
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
    
    private func relayCard(for relay: RelayInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(relay.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(relay.url.formattedRelayURL)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                if relay.subscriptionCount > 0 {
                    Text("\(relay.subscriptionCount)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            
            HStack {
                Label(relay.isConnected ? "Connected" : "Disconnected", 
                      systemImage: relay.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(relay.isConnected ? .green : .red)
                
                Spacer()
                
                if relay.subscriptionCount > 0 {
                    Label("\(relay.subscriptionCount) subscriptions", systemImage: "network")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Relays Configured")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("Add relays in Settings to connect to the Nostr network")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Computed Properties
    
    private var totalRelays: Int {
        relayInfo.count
    }
    
    private var connectedRelays: Int {
        relayInfo.filter { $0.isConnected }.count
    }
    
    private var totalSubscriptions: Int {
        relayInfo.reduce(0) { $0 + $1.subscriptionCount }
    }
    
    // MARK: - Helper Functions
    
    private func loadRelayInfo() async {
        isLoading = true
        
        let ndk = nostrManager.ndk
        
        let relays = await ndk.relays
        var info: [RelayInfo] = []
        
        for relay in relays {
            let connectionState = await relay.connectionState
            let activeSubs = await relay.activeSubscriptions
            
            info.append(RelayInfo(
                url: relay.url,
                isConnected: connectionState == .connected,
                subscriptionCount: activeSubs.count
            ))
        }
        
        await MainActor.run {
            self.relayInfo = info.sorted { $0.url < $1.url }
            self.isLoading = false
        }
    }
}


// MARK: - Extensions

extension String {
    var formattedRelayURL: String {
        self.replacingOccurrences(of: "wss://", with: "")
            .replacingOccurrences(of: "ws://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

struct EventDebugView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.orange.opacity(0.6))
            
            Text("Event Inspector")
                .font(.title2)
                .foregroundColor(.white)
                .padding(.top)
            
            Text("Coming soon...")
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .navigationTitle("Event Inspector")
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

struct DebugMenuView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DebugMenuView()
                .environmentObject(NostrManager())
        }
        .preferredColorScheme(.dark)
    }
}