import SwiftUI
import NDKSwift

@main
struct AmbulandoApp: App {
    @StateObject private var nostrManager = NostrManager()
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
            .environmentObject(nostrManager)
            .environmentObject(appState)
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: NDKUser?
    
    // Audio state
    @Published var isRecording = false
    @Published var currentlyPlayingId: String?
    @Published var recordingStartTime: Date?
    
    // Reply context
    @Published var replyingTo: AudioEvent?
    
    // Signer reference for reactions
    var signer: NDKSigner? {
        nostrManager?.ndk?.signer
    }
    
    // Lazy reference to NostrManager
    private weak var nostrManager: NostrManager?
    
    func setNostrManager(_ manager: NostrManager) {
        self.nostrManager = manager
    }
    
    func reset() {
        isAuthenticated = false
        currentUser = nil
        isRecording = false
        currentlyPlayingId = nil
        replyingTo = nil
    }
}

// MARK: - Nostr Manager
@MainActor
class NostrManager: ObservableObject {
    @Published var ndk: NDK?
    @Published var authenticationState: NDKAuthManager.AuthenticationState = .unauthenticated
    
    private var ndkAuthManager: NDKAuthManager
    private var authStateObservation: Task<Void, Never>?
    
    // Recommended relays for Ambulando
    let defaultRelays = [
        RelayConstants.primal,
        RelayConstants.damus,
        RelayConstants.nosLol,
        RelayConstants.nostrBand,
        RelayConstants.nostrWine
    ]
    
    // Key for storing user-added relays
    private static let userRelaysKey = "AmbulandoUserAddedRelays"
    
    init() {
        self.ndkAuthManager = NDKAuthManager.shared
        setupNDK()
    }
    
    private func setupNDK() {
        let allRelays = getAllRelays()
        ndk = NDK(relayUrls: allRelays)
        
        if let ndk = ndk {
            // Configure client tag
            ndk.clientTagConfig = NDKClientTagConfig(
                name: "Ambulando",
                autoTag: true
            )
            
            ndkAuthManager.setNDK(ndk)
            
            // Setup session restoration
            Task {
                await ndk.connect()
                
                // Auth manager will restore sessions automatically when needed
                
                // Observe authentication state changes
                _ = withObservationTracking {
                    ndkAuthManager.authenticationState
                } onChange: { [weak self] in
                    Task { @MainActor in
                        await self?.handleAuthStateChange()
                    }
                }
                
                await handleAuthStateChange()
            }
        }
    }
    
    private func handleAuthStateChange() async {
        switch ndkAuthManager.authenticationState {
        case .authenticated:
            // If authenticated, ensure signer is set on NDK
            if let activeSigner = ndkAuthManager.activeSigner {
                ndk?.signer = activeSigner
                // Start session if not already started
                if ndk?.sessionData == nil {
                    do {
                        _ = try await ndk?.startSession(
                            signer: activeSigner,
                            config: NDKSessionConfiguration(
                                dataRequirements: [.followList, .muteList, .webOfTrust(depth: 2)],
                                preloadStrategy: .progressive
                            )
                        )
                    } catch {
                        // Session start failed
                    }
                }
            }
            
        case .unauthenticated:
            // Clear signer if unauthenticated
            ndk?.signer = nil
            
        default:
            break
        }
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    func login(with signer: NDKSigner) async throws -> NDKSessionData {
        guard let ndk = ndk else { throw NostrError.signerRequired }
        
        // For bunker signers, the signer should already be set on NDK
        // and connected before calling this method
        if signer is NDKBunkerSigner {
            // Start session with the bunker signer
            let sessionData = try await ndk.startSession(
                signer: signer,
                config: NDKSessionConfiguration(
                    dataRequirements: [.followList, .muteList, .webOfTrust(depth: 2)],
                    preloadStrategy: .progressive
                )
            )
            
            // Note: We don't persist bunker signers to keychain
            // The connection token should be saved separately if needed
            
            return sessionData
        } else {
            // For private key signers, start session normally
            let sessionData = try await ndk.startSession(
                signer: signer,
                config: NDKSessionConfiguration(
                    dataRequirements: [.followList, .muteList, .webOfTrust(depth: 2)],
                    preloadStrategy: .progressive
                )
            )
            
            // Create or update session with auth manager for persistence
            if let privateSigner = signer as? NDKPrivateKeySigner {
                _ = try await ndkAuthManager.createSession(
                    with: privateSigner,
                    requiresBiometric: false,
                    isHardwareBacked: false
                )
            }
            
            return sessionData
        }
    }
    
    func logout() {
        Task {
            // Clear all sessions from keychain
            for session in ndkAuthManager.availableSessions {
                try? await ndkAuthManager.deleteSession(session)
            }
        }
        
        // Clear active authentication state
        ndkAuthManager.logout()
        
        // Clear NDK signer
        ndk?.signer = nil
    }
    
    // Check if user is authenticated via NDKAuth
    var isAuthenticated: Bool {
        // Must have both auth manager authenticated AND signer loaded
        ndkAuthManager.isAuthenticated && ndk?.signer != nil
    }
    
    // Get auth manager for use in UI
    var authManager: NDKAuthManager {
        return ndkAuthManager
    }
    
    // MARK: - Relay Management
    
    /// Get all relays (default + user-added)
    private func getAllRelays() -> [String] {
        let userRelays = getUserAddedRelays()
        let allRelays = defaultRelays + userRelays
        return Array(Set(allRelays)) // Remove duplicates
    }
    
    /// Get user-added relays from UserDefaults
    private func getUserAddedRelays() -> [String] {
        return UserDefaults.standard.stringArray(forKey: Self.userRelaysKey) ?? []
    }
    
    /// Add a user relay and persist it
    func addUserRelay(_ relayURL: String) {
        var userRelays = getUserAddedRelays()
        guard !userRelays.contains(relayURL) && !defaultRelays.contains(relayURL) else {
            print("Relay \(relayURL) already exists")
            return
        }
        
        userRelays.append(relayURL)
        UserDefaults.standard.set(userRelays, forKey: Self.userRelaysKey)
    }
    
    /// Remove a user relay and persist the change
    func removeUserRelay(_ relayURL: String) {
        var userRelays = getUserAddedRelays()
        userRelays.removeAll(value: relayURL)
        UserDefaults.standard.set(userRelays, forKey: Self.userRelaysKey)
    }
    
    /// Get list of user-added relays (for UI display)
    var userAddedRelays: [String] {
        return getUserAddedRelays()
    }
}

// MARK: - Errors
enum NostrError: LocalizedError {
    case signerRequired
    case invalidKey
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .signerRequired:
            return "No signer available"
        case .invalidKey:
            return "Invalid private key"
        case .networkError:
            return "Network connection failed"
        }
    }
}
