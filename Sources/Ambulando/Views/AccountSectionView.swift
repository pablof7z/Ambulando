import SwiftUI
import NDKSwift

struct AccountSectionView: View {
    let currentUser: NDKUser?
    let userMetadata: NDKUserMetadata?
    let copiedNpub: Bool
    let onCopyNpub: (String) -> Void
    
    var body: some View {
        Section {
            if let currentUser = currentUser {
                HStack {
                    // Profile picture placeholder
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple,
                                    Color.blue
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text((userMetadata?.displayName ?? userMetadata?.name ?? "User").prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userMetadata?.displayName ?? userMetadata?.name ?? "Nostr User")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Text(String(currentUser.npub.prefix(16)) + "...")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.6))
                            
                            Button(action: { onCopyNpub(currentUser.npub) }) {
                                Image(systemName: copiedNpub ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(copiedNpub ? .green : Color.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                }
            } else {
                Text("No user logged in")
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        } header: {
            Text("Account")
                .foregroundColor(Color.white.opacity(0.8))
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}