import SwiftUI
import NDKSwift

struct SettingsView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentUser: NDKUser?
    @State private var userMetadata: NDKUserMetadata?
    @State private var copiedNpub = false
    
    var body: some View {
        List {
            // Account section
            AccountSectionView(
                currentUser: currentUser,
                userMetadata: userMetadata,
                copiedNpub: copiedNpub,
                onCopyNpub: copyNpub
            )
            
            // Preferences
            Section(header: Text("Preferences").foregroundColor(Color.white.opacity(0.8))) {
                NavigationLink(destination: RelayManagementView()) {
                    Label("Relays", systemImage: "network")
                }
                .foregroundColor(.white)
                
                NavigationLink(destination: BlossomSettingsView()) {
                    Label("Blossom Servers", systemImage: "icloud.and.arrow.up")
                        .foregroundColor(.white)
                }
                .foregroundColor(.white)
                
                NavigationLink(destination: MuteListView()) {
                    Label("Muted Users", systemImage: "speaker.slash")
                }
                .foregroundColor(.white)
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            // Debug section (only in debug builds)
            #if DEBUG
            Section(header: Text("Debug").foregroundColor(Color.white.opacity(0.8))) {
                NavigationLink(destination: DebugMenuView()) {
                    Label("Debug Tools", systemImage: "hammer.fill")
                }
                .foregroundColor(.white)
            }
            .listRowBackground(Color.white.opacity(0.05))
            #endif
            
            // Danger zone
            Section {
                Button(role: .destructive, action: logout) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .navigationTitle("Settings")
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
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.purple)
            }
        }
        .task {
            await loadUserData()
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadUserData() async {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        // Get the current user from the active session
        if let authManager = nostrManager.authManager,
           let activeSession = authManager.activeSession {
            let pubkey = activeSession.pubkey
            currentUser = NDKUser(pubkey: pubkey)
            
            // Fetch profile using NDKProfileManager
            for await metadata in await ndk.profileManager.subscribe(for: pubkey, maxAge: TimeConstants.hour) {
                userMetadata = metadata
                break // Take first metadata
            }
        }
    }
    
    private func copyNpub(_ npub: String) {
        #if os(iOS)
        UIPasteboard.general.string = npub
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(npub, forType: .string)
        #endif
        withAnimation {
            copiedNpub = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedNpub = false
            }
        }
    }
    
    private func logout() {
        Task {
            await nostrManager.logout()
            await MainActor.run {
                appState.reset()
                dismiss()
            }
        }
    }
}

// MARK: - Mute List View (Placeholder)
struct MuteListView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var mutedUsers: Set<String> = []
    
    var body: some View {
        List {
            if mutedUsers.isEmpty {
                Text("No muted users")
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(mutedUsers), id: \.self) { pubkey in
                    HStack {
                        Text(String(pubkey.prefix(16)) + "...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
        }
        .navigationTitle("Muted Users")
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
        .task {
            await loadMutedUsers()
        }
    }
    
    private func loadMutedUsers() async {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        guard let sessionData = ndk.sessionData else { return }
        
        mutedUsers = sessionData.muteList
    }
}