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
class NostrManager: NDKNostrManager {
    @Published var blossomServerManager: NDKBlossomServerManager?
    
    // MARK: - Configuration Overrides
    
    override var defaultRelays: [String] {
        [
            RelayConstants.primal,
            RelayConstants.damus,
            RelayConstants.nosLol,
            RelayConstants.nostrBand,
            RelayConstants.nostrWine
        ]
    }
    
    override var userRelaysKey: String {
        "AmbulandoUserAddedRelays"
    }
    
    override var clientTagConfig: NDKClientTagConfig? {
        NDKClientTagConfig(
            name: "Ambulando",
            autoTag: true
        )
    }
    
    override var sessionConfiguration: NDKSessionConfiguration {
        NDKSessionConfiguration(
            dataRequirements: [.followList, .muteList, .webOfTrust(depth: 2)],
            preloadStrategy: .progressive
        )
    }
    
    
    override init() {
        super.init()
        
        // Enable verbose NDK logging in debug builds
        #if DEBUG
        NDKLogger.logLevel = .debug
        NDKLogger.enabledCategories = Set(NDKLogCategory.allCases)
        print("🚀 [Ambulando] NDK logging enabled - Level: trace, Categories: all")
        #endif
    }
    
    override func setupNDK() async {
        await super.setupNDK()
        
        // Initialize Blossom server manager
        if let ndk = ndk {
            blossomServerManager = NDKBlossomServerManager(ndk: ndk)
        }
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
                _ = try await NDKAuthManager.shared.addSession(
                    privateSigner,
                    requiresBiometric: false
                )
            }
            
            return sessionData
        }
    }
    
    
    // isAuthenticated is now handled by parent class
    
    // Get auth manager for use in UI
    var authManager: NDKAuthManager {
        return NDKAuthManager.shared
    }
    
    // MARK: - Relay Management
    
    // Relay management is now handled by parent class
    
    // Use parent class methods for relay management
    
    // userAddedRelays is now handled by parent class
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
