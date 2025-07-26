import SwiftUI
import NDKSwift

struct RelayManagementView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var showAddRelay = false
    
    var body: some View {
        List {
            if let ndk = nostrManager.ndk {
                RelayListContent(ndk: ndk, nostrManager: nostrManager)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text("NDK not initialized")
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            }
            
            Section {
                Button(action: { showAddRelay = true }) {
                    Label {
                        Text("Add Relay")
                            .foregroundColor(.purple)
                    } icon: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.purple)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
        }
        .navigationTitle("Relay Management")
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
        .sheet(isPresented: $showAddRelay) {
            AddRelayView()
        }
    }
}

// Separate view for relay list content that observes NDK relays
struct RelayListContent: View {
    let ndk: NDK
    let nostrManager: NostrManager
    @StateObject private var relayCollection: NDKRelayCollection
    
    init(ndk: NDK, nostrManager: NostrManager) {
        self.ndk = ndk
        self.nostrManager = nostrManager
        self._relayCollection = StateObject(wrappedValue: ndk.createRelayCollection())
    }
    
    var body: some View {
        Group {
            if relayCollection.relays.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text("No relays configured")
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text("Add relays to connect to the Nostr network")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(relayCollection.relays) { relayInfo in
                        RelayRowView(relayInfo: relayInfo, ndk: ndk, nostrManager: nostrManager)
                    }
                } header: {
                    HStack {
                        Text("Connected Relays")
                            .foregroundColor(Color.white.opacity(0.8))
                        Spacer()
                        Text("\(relayCollection.connectedCount)/\(relayCollection.totalCount)")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

// Individual relay row using relay info from collection
struct RelayRowView: View {
    let relayInfo: NDKRelayCollection.RelayInfo
    let ndk: NDK
    let nostrManager: NostrManager
    @State private var showDetails = false
    @State private var relay: NDKRelay?
    @State private var relayState: NDKRelay.State?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Connection status indicator
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(relayInfo.url)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        ConnectionStatusBadge(state: relayInfo.state, style: .compact)
                        
                        if let state = relayState,
                           let name = state.info?.name {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            
            // Stats row
            if let state = relayState {
                RelayStatsRow(stats: state.stats)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.05))
        .contentShape(Rectangle())
        .onTapGesture {
            showDetails = true
        }
        .sheet(isPresented: $showDetails) {
            if let relay = relay, let state = relayState {
                RelayDetailView(relay: relay, initialState: state, nostrManager: nostrManager)
            }
        }
        .task {
            await loadRelay()
        }
    }
    
    private var connectionColor: Color {
        switch relayInfo.state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .disconnecting:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private func loadRelay() async {
        let allRelays = await ndk.relays
        if let foundRelay = allRelays.first(where: { $0.url == relayInfo.url }) {
            self.relay = foundRelay
            
            // Get initial state
            for await state in foundRelay.stateStream {
                await MainActor.run {
                    self.relayState = state
                }
                // Only need the first state for display
                break
            }
        }
    }
}

// Simple connection status badge
struct ConnectionStatusBadge: View {
    let state: NDKRelayConnectionState
    let style: BadgeStyle
    
    enum BadgeStyle {
        case full
        case compact
    }
    
    var body: some View {
        if style == .compact {
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .cornerRadius(12)
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .disconnecting:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .failed:
            return "Failed"
        }
    }
}

// Simple relay stats row
struct RelayStatsRow: View {
    let stats: NDKRelayStats
    
    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                icon: "arrow.up",
                value: "\(stats.messagesSent)",
                label: "sent"
            )
            
            StatItem(
                icon: "arrow.down",
                value: "\(stats.messagesReceived)",
                label: "received"
            )
            
            if let latency = stats.latency {
                StatItem(
                    icon: "timer",
                    value: String(format: "%.0fms", latency * 1000),
                    label: "latency"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(Color.white.opacity(0.6))
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(value)
                    .fontWeight(.medium)
            }
            Text(label)
                .font(.system(size: 9))
        }
    }
}

// MARK: - Relay Detail View
struct RelayDetailView: View {
    let relay: NDKRelay
    let initialState: NDKRelay.State
    let nostrManager: NostrManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentState: NDKRelay.State
    @State private var showDisconnectAlert = false
    @State private var observationTask: Task<Void, Never>?
    
    init(relay: NDKRelay, initialState: NDKRelay.State, nostrManager: NostrManager) {
        self.relay = relay
        self.initialState = initialState
        self.nostrManager = nostrManager
        self._currentState = State(initialValue: initialState)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Connection Status
                Section("Connection") {
                    LabeledContent("Status", value: statusText)
                        .foregroundColor(.white)
                    
                    if let connectedAt = currentState.stats.connectedAt {
                        LabeledContent("Connected Since") {
                            Text(connectedAt, style: .relative)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .foregroundColor(.white)
                    }
                    
                    if let lastMessage = currentState.stats.lastMessageAt {
                        LabeledContent("Last Message") {
                            Text(lastMessage, style: .relative)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // Traffic Statistics
                Section("Traffic") {
                    LabeledContent("Messages Sent", value: "\(currentState.stats.messagesSent)")
                        .foregroundColor(.white)
                    LabeledContent("Messages Received", value: "\(currentState.stats.messagesReceived)")
                        .foregroundColor(.white)
                    LabeledContent("Bytes Sent", value: formatBytes(currentState.stats.bytesSent))
                        .foregroundColor(.white)
                    LabeledContent("Bytes Received", value: formatBytes(currentState.stats.bytesReceived))
                        .foregroundColor(.white)
                    
                    if let latency = currentState.stats.latency {
                        LabeledContent("Latency", value: String(format: "%.0f ms", latency * 1000))
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // Actions
                Section {
                    if case .connected = currentState.connectionState {
                        Button(role: .destructive, action: { showDisconnectAlert = true }) {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: reconnect) {
                            Label("Connect", systemImage: "arrow.clockwise")
                                .foregroundColor(.purple)
                        }
                    }
                    
                    // Allow removing user-added relays
                    if nostrManager.userAddedRelays.contains(relay.url) {
                        Button(role: .destructive, action: removeRelay) {
                            Label("Remove from App", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .navigationTitle(relay.url)
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
            .alert("Disconnect Relay?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task {
                        await relay.disconnect()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect from this relay?")
            }
            .onAppear {
                startObserving()
            }
            .onDisappear {
                stopObserving()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var statusText: String {
        switch currentState.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting..."
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    private func reconnect() {
        Task {
            do {
                try await relay.connect()
                dismiss()
            } catch {
                print("Failed to reconnect: \(error)")
            }
        }
    }
    
    private func removeRelay() {
        Task {
            // Remove relay from NDK
            await relay.disconnect()
            
            // Remove from persistent storage
            nostrManager.removeUserRelay(relay.url)
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func startObserving() {
        observationTask = Task {
            for await state in relay.stateStream {
                await MainActor.run {
                    self.currentState = state
                }
            }
        }
    }
    
    private func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
}

// MARK: - Add Relay View
struct AddRelayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nostrManager: NostrManager
    
    @State private var relayURL = ""
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Common relays
    let suggestedRelays = [
        RelayConstants.damus,
        RelayConstants.nostrBand,
        "wss://relayable.org",
        RelayConstants.primal,
        RelayConstants.nostrWine
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("wss://relay.example.com", text: $relayURL)
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                        .foregroundColor(.white)
                } header: {
                    Text("Relay URL")
                        .foregroundColor(Color.white.opacity(0.8))
                } footer: {
                    Text("Enter a WebSocket URL for a Nostr relay")
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Section("Suggested Relays") {
                    ForEach(suggestedRelays, id: \.self) { relay in
                        Button(action: { relayURL = relay }) {
                            HStack {
                                Text(relay)
                                    .foregroundColor(.white)
                                Spacer()
                                if relayURL == relay {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: addRelay) {
                        if isAdding {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Add Relay")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.purple)
                        }
                    }
                    .disabled(relayURL.isEmpty || isAdding)
                }
            }
            .navigationTitle("Add Relay")
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func addRelay() {
        guard !relayURL.isEmpty else { return }
        
        isAdding = true
        
        Task {
            do {
                // Add relay to NDK and connect to it
                guard let ndk = nostrManager.ndk else {
                    throw NostrError.signerRequired
                }
                
                guard let _ = await ndk.addRelayAndConnect(relayURL) else {
                    throw NostrError.networkError
                }
                
                // Persist the relay for future app launches
                nostrManager.addUserRelay(relayURL)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isAdding = false
                }
            }
        }
    }
}