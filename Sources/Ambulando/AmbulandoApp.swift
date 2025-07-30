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
    // Audio state
    @Published var isRecording = false
    @Published var currentlyPlayingId: String?
    @Published var recordingStartTime: Date?
    
    // Reply context
    @Published var replyingTo: AudioEvent?
    
    // Lazy reference to NostrManager
    private weak var nostrManager: NostrManager?
    
    func setNostrManager(_ manager: NostrManager) {
        self.nostrManager = manager
    }
    
    func reset() {
        isRecording = false
        currentlyPlayingId = nil
        replyingTo = nil
    }
}

// MARK: - Nostr Manager
@MainActor
class NostrManager: ObservableObject {
    @Published private(set) var isInitialized = false
    private var _ndk: NDK!
    var ndk: NDK {
        return _ndk
    }
    var cache: NDKCache?
    @Published private(set) var authManager: NDKAuthManager?
    @Published var blossomServerManager: NDKBlossomServerManager?
    
    // MARK: - Configuration
    
    var defaultRelays: [String] {
        [
            RelayConstants.primal,
            RelayConstants.damus,
            RelayConstants.nosLol,
            RelayConstants.nostrBand
        ]
    }
    
    var appRelaysKey: String {
        "AmbulandoAppAddedRelays"
    }
    
    var clientTagConfig: NDKClientTagConfig? {
        NDKClientTagConfig(
            name: "Ambulando",
            autoTag: true
        )
    }
    
    var sessionConfiguration: NDKSessionConfiguration {
        NDKSessionConfiguration(
            dataRequirements: [.followList, .muteList, .webOfTrust(depth: 2)],
            preloadStrategy: .progressive
        )
    }
    
    init() {
        // Enable verbose NDK logging in debug builds
        #if DEBUG
        NDKLogger.logLevel = .debug
        NDKLogger.enabledCategories = Set(NDKLogCategory.allCases)
        print("🚀 [Ambulando] NDK logging enabled - Level: trace, Categories: all")
        #endif
        
        // Initialize NDK immediately to avoid crashes
        _ndk = NDK()
        
        Task {
            await setupNDK()
        }
    }
    
    func setupNDK() async {
        // Initialize cache
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dbPath = documentsPath.appendingPathComponent("ambulando_cache.db").path
            cache = try? await NDKSQLiteCache(path: dbPath)
        }
        
        // Re-initialize NDK with cache
        _ndk = NDK(cache: cache)
        
        // Add default relays
        for relay in defaultRelays {
            await _ndk.addRelay(relay)
        }
        
        // Connect to relays
        await _ndk.connect()
        
        // Initialize auth manager and check for existing sessions
        authManager = NDKAuthManager(ndk: _ndk)
        await authManager?.initialize()
        
        // Initialize Blossom server manager
        blossomServerManager = NDKBlossomServerManager(ndk: _ndk)
        
        // If authenticated, restore session
        if let authManager = authManager, authManager.isAuthenticated, let signer = authManager.activeSigner {
            do {
                try await _ndk.startSession(signer: signer, config: sessionConfiguration)
                print("🔍 [Ambulando] Restored session for user: \(authManager.activePubkey?.prefix(8) ?? "unknown")")
            } catch {
                print("🔍 [Ambulando] Failed to restore session: \(error)")
            }
        } else {
            print("🔍 [Ambulando] No existing session to restore")
        }
        
        isInitialized = true
    }
    
    
    func login(with signer: NDKSigner) async throws -> NDKSessionData {
        guard isInitialized else { throw NostrError.signerRequired }
        let ndk = self.ndk
        
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
            if let privateSigner = signer as? NDKPrivateKeySigner,
               let authManager = authManager {
                _ = try await authManager.addSession(
                    privateSigner,
                    requiresBiometric: false
                )
            }
            
            return sessionData
        }
    }
    
    
    var isAuthenticated: Bool {
        return authManager?.hasActiveSession ?? false
    }
    
    func logout() async {
        if let authManager = authManager {
            authManager.logout()
        }
        // Clear signer from NDK
        _ndk.signer = nil
    }
    
    // MARK: - Relay Management
    
    func addRelay(_ url: String) async {
        await _ndk.addRelay(url)
        
        // Save to user defaults
        var savedRelays = UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
        if !savedRelays.contains(url) {
            savedRelays.append(url)
            UserDefaults.standard.set(savedRelays, forKey: appRelaysKey)
        }
    }
    
    func removeRelay(_ url: String) async {
        await _ndk.removeRelay(url)
        
        // Remove from user defaults
        var savedRelays = UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
        savedRelays.removeAll { $0 == url }
        UserDefaults.standard.set(savedRelays, forKey: appRelaysKey)
    }
    
    var userAddedRelays: [String] {
        return UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
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
