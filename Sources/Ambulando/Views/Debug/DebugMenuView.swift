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
        guard nostrManager.ndk != nil else { return "0" }
        // This would ideally come from relay pool
        return "\(nostrManager.defaultRelays.count + nostrManager.userAddedRelays.count)"
    }
    
    private func getAuthStatus() -> String {
        return nostrManager.isAuthenticated ? "Authenticated" : "Not Authenticated"
    }
    
    private func getSessionStatus() -> String {
        guard let ndk = nostrManager.ndk else { return "No NDK" }
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
    var body: some View {
        VStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("Relay Debug")
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
        .navigationTitle("Relay Debug")
        .preferredColorScheme(.dark)
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