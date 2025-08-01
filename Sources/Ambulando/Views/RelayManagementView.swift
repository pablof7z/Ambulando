import SwiftUI
import NDKSwift
import NDKSwiftUI

struct RelayManagementView: View {
    @EnvironmentObject var nostrManager: NostrManager
    
    var body: some View {
        NDKUIRelayManagementView(ndk: nostrManager.ndk)
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
    }
}