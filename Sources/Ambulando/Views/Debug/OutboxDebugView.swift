import SwiftUI
import NDKSwift

struct OutboxDebugView: View {
    @StateObject private var viewModel: OutboxDebugViewModel
    @State private var searchText = ""
    @State private var selectedEntry: OutboxEntry?
    
    init(ndk: NDK?) {
        self._viewModel = StateObject(wrappedValue: OutboxDebugViewModel(ndk: ndk))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Outbox Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.refresh()
                    }
                    .foregroundColor(.purple)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(item: $selectedEntry) { entry in
            OutboxUserDetailView(entry: entry)
        }
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
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Summary Card
                OutboxSummaryCard(summary: viewModel.summary)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Connected Relays Section
                if !viewModel.summary.connectedRelaysInfo.isEmpty {
                    ConnectedRelaysSection(relays: viewModel.summary.connectedRelaysInfo)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // Search Bar
                searchBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // User List
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        OutboxEntryRow(entry: entry) {
                            selectedEntry = entry
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.bottom, 20) // Add bottom padding for better scrolling
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search users or relays...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var filteredEntries: [OutboxEntry] {
        viewModel.filteredEntries(searchText: searchText)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.purple)
            
            Text("Loading outbox data...")
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(message)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                viewModel.refresh()
            }
            .foregroundColor(.purple)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OutboxEntryRow: View {
    let entry: OutboxEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if let displayName = entry.displayName {
                        Text(displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text(String(entry.pubkey.prefix(16)) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(entry.source)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Relay Counts
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        RelayCountBadge(
                            count: entry.readRelays.count,
                            type: "R",
                            color: .blue
                        )
                        
                        RelayCountBadge(
                            count: entry.writeRelays.count,
                            type: "W",
                            color: .green
                        )
                    }
                    
                    Text("\(entry.totalRelayCount) total")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RelayCountBadge: View {
    let count: Int
    let type: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(type)
                .font(.caption2)
                .fontWeight(.medium)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(4)
    }
}

struct ConnectedRelaysSection: View {
    let relays: [ConnectedRelayInfo]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Section Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundColor(.purple)
                    
                    Text("Connected Relays")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("(\(relays.count))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(relays) { relay in
                        ConnectedRelayRow(relay: relay)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: 300) // Limit height to prevent overflow
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ConnectedRelayRow: View {
    let relay: ConnectedRelayInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection Status
            Circle()
                .fill(relay.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            // Relay URL
            VStack(alignment: .leading, spacing: 2) {
                Text(relay.url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Connection Reason Badge
                    Text(relay.connectionReason.description)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(relay.connectionReason.color).opacity(0.3))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(relay.connectionReason.color).opacity(0.6), lineWidth: 1)
                                )
                        )
                    
                    // Associated Pubkey for Outbox relays
                    if let pubkey = relay.associatedPubkey {
                        Text("via: \(String(pubkey.prefix(8)))...")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            Spacer()
            
            // Connection State
            Text(relay.connectionState)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Preview

struct OutboxDebugView_Previews: PreviewProvider {
    static var previews: some View {
        OutboxDebugView(ndk: nil)
            .preferredColorScheme(.dark)
    }
}