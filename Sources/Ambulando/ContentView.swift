import SwiftUI
import NDKSwift

struct ContentView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        let authManager = NDKAuthManager.shared
        let isAuth = authManager.authenticationState == .authenticated && authManager.activeSession != nil && authManager.activeSigner != nil
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            Group {
                if isAuth {
                    NavigationView {
                        HomeFeedView()
                    }
                    .environment(\.ndk, nostrManager.ndk)
                } else {
                    AuthenticationView()
                }
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
        .onAppear {
            appState.setNostrManager(nostrManager)
            checkAuthentication()
        }
        .environment(\.ndk, nostrManager.ndk)
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Blossom server manager loads automatically when accessed
                // through nostrManager.ndk.blossomServerManager
            }
        }
    }
    
    private func checkAuthentication() {
        let authManager = NDKAuthManager.shared
        guard let session = authManager.activeSession else {
            appState.isAuthenticated = false
            appState.currentUser = nil
            return
        }
        
        appState.isAuthenticated = true
        appState.currentUser = nostrManager.ndk?.getUser(session.pubkey)
    }
}