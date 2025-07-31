import SwiftUI
import NDKSwift
import NDKSwiftUI

struct UserProfileView: View {
    let pubkey: String
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var metadata: NDKUserMetadata?
    @State private var isFollowing = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var audioEvents: [AudioEvent] = []
    @State private var audioEventsTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with profile picture and stats
                VStack(spacing: 16) {
                    NDKUIProfilePicture(ndk: nostrManager.ndk, pubkey: pubkey, size: 120)
                    
                    VStack(spacing: 8) {
                        Text(metadata?.displayName ?? metadata?.name ?? String(pubkey.prefix(16)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        if let nip05 = metadata?.nip05 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.purple)
                                Text(nip05)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                        }
                    }
                    
                    // Stats
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(followersCount)")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Followers")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        
                        VStack {
                            Text("\(followingCount)")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Following")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 8)
                    
                    // Follow button
                    if let currentUserPubkey = nostrManager.authManager?.activeSession?.pubkey, 
                       pubkey != currentUserPubkey {
                        Button(action: toggleFollow) {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isFollowing ? .white : .black)
                                .frame(maxWidth: 200)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isFollowing ? Color.white.opacity(0.2) : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white, lineWidth: isFollowing ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.top, 20)
                
                // About section
                if let about = metadata?.about, !about.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(about)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                
                // Audio events section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio Posts")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    if audioEvents.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 40))
                                .foregroundColor(Color.white.opacity(0.3))
                            
                            Text("No audio posts yet")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Display audio events
                        LazyVStack(spacing: 0) {
                            ForEach(audioEvents.sorted { $0.createdAt > $1.createdAt }) { audioEvent in
                                AudioEventCard(audioEvent: audioEvent)
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .padding(.top, 16)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .onAppear {
            loadProfile()
            checkFollowStatus()
            loadAudioEvents()
        }
        .onDisappear {
            audioEventsTask?.cancel()
        }
    }
    
    private func loadProfile() {
        Task {
            guard nostrManager.isInitialized else { return }
            let ndk = nostrManager.ndk
            
            for await metadata in await ndk.profileManager.subscribe(for: pubkey, maxAge: TimeConstants.hour) {
                await MainActor.run {
                    self.metadata = metadata
                }
                break // Just get the first result for now
            }
        }
    }
    
    private func checkFollowStatus() {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        guard let sessionData = ndk.sessionData else { return }
        
        isFollowing = sessionData.followList.contains(pubkey)
    }
    
    private func toggleFollow() {
        // TODO: Implement follow/unfollow functionality
        isFollowing.toggle()
    }
    
    private func loadAudioEvents() {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        // Cancel any existing task
        audioEventsTask?.cancel()
        
        // Clear existing events
        audioEvents.removeAll()
        
        // Create filter for audio events by this user
        let filter = NDKFilter(
            authors: [pubkey],
            kinds: [1222, 1244]
        )
        
        // Stream audio events
        let dataSource = ndk.subscribe(filter: filter, maxAge: 0, cachePolicy: .cacheWithNetwork)
        
        audioEventsTask = Task {
            for await event in dataSource.events {
                // Check if task was cancelled
                if Task.isCancelled { break }
                
                // Get WOT score from session data
                let wotScore: Double
                if let sessionData = ndk.sessionData {
                    let score = sessionData.webOfTrust[event.pubkey] ?? 0
                    // Normalize score (direct follows have Int.max)
                    wotScore = score == Int.max ? 1.0 : min(Double(score) / 10.0, 1.0)
                } else {
                    wotScore = 0.1
                }
                
                if let audioEvent = AudioEvent.from(event: event, webOfTrustScore: wotScore) {
                    await MainActor.run {
                        // Add new event if it doesn't already exist
                        if !self.audioEvents.contains(where: { $0.id == audioEvent.id }) {
                            self.audioEvents.append(audioEvent)
                        }
                    }
                }
            }
        }
    }
}
