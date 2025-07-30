import SwiftUI
import NDKSwift
import NDKSwiftUI

struct RelaySelectorView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState
    @Binding var selectedRelay: String?
    @Binding var isPresented: Bool
    
    @State private var relayStates: [RelayInfo] = []
    @State private var observerTask: Task<Void, Never>?
    
    struct RelayInfo: Identifiable {
        let id = UUID()
        let url: String
        let isConnected: Bool
        let info: NDKRelayInformation?
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SELECT RELAY")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.3))
            
            // All relays option
            RelaySelectorRowView(
                title: "All Relays",
                subtitle: "\(relayStates.filter { $0.isConnected }.count) connected",
                isSelected: selectedRelay == nil,
                isConnected: true,
                iconURL: nil
            ) {
                selectedRelay = nil
                isPresented = false
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Individual relays
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(relayStates) { relay in
                        RelaySelectorRowView(
                            title: relay.info?.name ?? relay.url.formattedRelayURL,
                            subtitle: relay.isConnected ? "Connected" : "Disconnected",
                            isSelected: selectedRelay == relay.url,
                            isConnected: relay.isConnected,
                            iconURL: relay.info?.icon
                        ) {
                            selectedRelay = relay.url
                            isPresented = false
                        }
                        
                        if relay.id != relayStates.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(20)
        .onAppear {
            startObservingRelays()
        }
        .onDisappear {
            observerTask?.cancel()
        }
    }
    
    
    private func startObservingRelays() {
        let ndk = nostrManager.ndk
        
        observerTask = Task {
            // Get initial relay states
            let relays = await ndk.relays
            var states: [RelayInfo] = []
            
            for relay in relays {
                let connectionState = await relay.connectionState
                let isConnected = connectionState == .connected
                let info = await relay.info
                states.append(RelayInfo(url: relay.url, isConnected: isConnected, info: info))
            }
            
            await MainActor.run {
                self.relayStates = states.sorted { $0.url < $1.url }
            }
            
            // Listen for relay changes
            let changes = await ndk.relayChanges
            for await change in changes {
                switch change {
                case .relayAdded(let relay):
                    let isConnected = await relay.connectionState == .connected
                    let info = await relay.info
                    await MainActor.run {
                        if !self.relayStates.contains(where: { $0.url == relay.url }) {
                            self.relayStates.append(RelayInfo(url: relay.url, isConnected: isConnected, info: info))
                            self.relayStates.sort { $0.url < $1.url }
                        }
                    }
                    
                case .relayRemoved(let url):
                    _ = await MainActor.run {
                        self.relayStates.removeAll { $0.url == url }
                    }
                    
                case .relayConnected(let relay):
                    let info = await relay.info
                    await MainActor.run {
                        if let index = self.relayStates.firstIndex(where: { $0.url == relay.url }) {
                            self.relayStates[index] = RelayInfo(url: relay.url, isConnected: true, info: info)
                        }
                    }
                    
                case .relayDisconnected(let relay):
                    let info = await relay.info
                    await MainActor.run {
                        if let index = self.relayStates.firstIndex(where: { $0.url == relay.url }) {
                            self.relayStates[index] = RelayInfo(url: relay.url, isConnected: false, info: info)
                        }
                    }
                }
            }
        }
    }
}

struct RelaySelectorRowView: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isConnected: Bool
    let iconURL: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Relay icon if available
                if let iconURL = iconURL, let url = URL(string: iconURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    // Default icon for relays without custom icon
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "network")
                                .font(.system(size: 16))
                                .foregroundColor(Color.white.opacity(0.5))
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConnected ? Color.green : Color.red.opacity(0.6))
                            .frame(width: 6, height: 6)
                        
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}