import SwiftUI
import NDKSwift

struct ContentView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Group {
                if !nostrManager.isInitialized {
                    // Show loading while NostrManager initializes
                    ProgressView("Initializing...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.orange)
                } else if nostrManager.isAuthenticated {
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
        }
        .environment(\.ndk, nostrManager.ndk)
    }
}