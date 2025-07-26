import SwiftUI
import NDKSwift

struct OutboxUserDetailView: View {
    let entry: OutboxEntry
    @Environment(\.dismiss) private var dismiss
    @State private var copiedText: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // User Info Section
                    userInfoSection
                    
                    // Relay Lists
                    if !entry.readRelays.isEmpty {
                        relaySection(
                            title: "Read Relays",
                            relays: entry.readRelays,
                            icon: "arrow.down.circle.fill",
                            color: .blue
                        )
                    }
                    
                    if !entry.writeRelays.isEmpty {
                        relaySection(
                            title: "Write Relays",
                            relays: entry.writeRelays,
                            icon: "arrow.up.circle.fill",
                            color: .green
                        )
                    }
                    
                    // Metadata Section
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("Outbox Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
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
        }
        .preferredColorScheme(.dark)
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Display Name
            if let displayName = entry.displayName {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Pubkey
            CopyableRow(
                label: "Pubkey",
                value: entry.pubkey,
                displayValue: String(entry.pubkey.prefix(32)) + "...",
                copiedText: $copiedText
            )
            
            // Npub
            CopyableRow(
                label: "Npub",
                value: entry.npub,
                displayValue: String(entry.npub.prefix(32)) + "...",
                copiedText: $copiedText
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func relaySection(title: String, relays: [RelayDisplayInfo], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(relays.count) relays")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                ForEach(relays) { relay in
                    RelayDetailRow(relay: relay, copiedText: $copiedText)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.white)
            
            LabeledContent("Source", value: entry.source)
                .foregroundColor(.white.opacity(0.8))
            
            LabeledContent("Last Updated", value: entry.lastUpdated.formatted())
                .foregroundColor(.white.opacity(0.8))
            
            LabeledContent("Total Relay Count", value: "\(entry.totalRelayCount)")
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct CopyableRow: View {
    let label: String
    let value: String
    let displayValue: String
    @Binding var copiedText: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            HStack {
                Text(displayValue)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { copyToClipboard(value) }) {
                    Image(systemName: copiedText == value ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(copiedText == value ? .green : .purple)
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        withAnimation {
            copiedText = text
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if copiedText == text {
                    copiedText = nil
                }
            }
        }
    }
}

struct RelayDetailRow: View {
    let relay: RelayDisplayInfo
    @Binding var copiedText: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Health indicator
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
                
                // Relay URL
                Text(relay.url)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // Copy button
                Button(action: { copyToClipboard(relay.url) }) {
                    Image(systemName: copiedText == relay.url ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(copiedText == relay.url ? .green : .purple.opacity(0.8))
                }
            }
            
            // Relay metadata
            HStack(spacing: 16) {
                // Health status
                HStack(spacing: 4) {
                    Text("Health:")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text(relay.health.description)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(healthColor)
                }
                
                // Score
                if let score = relay.score {
                    HStack(spacing: 4) {
                        Text("Score:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(String(format: "%.2f", score))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                
                // Response time
                if let avgTime = relay.averageResponseTime {
                    HStack(spacing: 4) {
                        Text("Avg:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(Int(avgTime))ms")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            
            // Additional metadata
            if relay.failureCount > 0 || relay.requiresAuth || relay.requiresPayment {
                HStack(spacing: 8) {
                    if relay.failureCount > 0 {
                        Label("\(relay.failureCount) failures", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    
                    if relay.requiresAuth {
                        Label("Auth", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if relay.requiresPayment {
                        Label("Paid", systemImage: "bitcoinsign.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private var healthColor: Color {
        switch relay.health {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        withAnimation {
            copiedText = text
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if copiedText == text {
                    copiedText = nil
                }
            }
        }
    }
}

// MARK: - Preview

struct OutboxUserDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockEntry = OutboxEntry(
            from: NDKOutboxItem(
                pubkey: "82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2",
                readRelays: Set([
                    RelayInfo(url: "wss://relay.damus.io", metadata: RelayMetadata(
                        score: 0.85,
                        lastConnectedAt: Date(),
                        avgResponseTime: 245,
                        failureCount: 1,
                        authRequired: false,
                        paymentRequired: false
                    )),
                    RelayInfo(url: "wss://nos.lol", metadata: RelayMetadata(
                        score: 0.72,
                        lastConnectedAt: Date(),
                        avgResponseTime: 180,
                        failureCount: 0,
                        authRequired: true,
                        paymentRequired: false
                    ))
                ]),
                writeRelays: Set([
                    RelayInfo(url: "wss://relay.damus.io", metadata: RelayMetadata(
                        score: 0.85,
                        lastConnectedAt: Date(),
                        avgResponseTime: 245,
                        failureCount: 1,
                        authRequired: false,
                        paymentRequired: false
                    )),
                    RelayInfo(url: "wss://nostr.wine", metadata: RelayMetadata(
                        score: 0.55,
                        lastConnectedAt: Date(),
                        avgResponseTime: 520,
                        failureCount: 3,
                        authRequired: false,
                        paymentRequired: true
                    ))
                ]),
                fetchedAt: Date(),
                source: .nip65
            ),
            displayName: "jack"
        )
        
        OutboxUserDetailView(entry: mockEntry)
            .preferredColorScheme(.dark)
    }
}