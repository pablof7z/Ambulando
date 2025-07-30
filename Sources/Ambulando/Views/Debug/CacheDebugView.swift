import SwiftUI
import NDKSwift

// MARK: - Cache Debug View
struct CacheDebugView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var cacheStats: CacheStatistics?
    @State private var isLoadingStats = false
    @State private var selectedKind: Int?
    @State private var cachedEvents: [NDKEvent] = []
    @State private var isLoadingEvents = false
    @State private var showingProfileCache = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    
    private var kindNames: [Int: String] = [
        0: "Metadata",
        1: "Text Note",
        3: "Follow List",
        4: "DM",
        5: "Deletion",
        6: "Repost",
        7: "Reaction",
        10002: "Relay List",
        30023: "Long-form Content",
        1063: "File Metadata",
        1808: "Audio Track"
    ]
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 0) {
                // Stats Overview
                if let stats = cacheStats {
                    CacheStatsHeaderView(stats: stats)
                        .padding()
                } else if isLoadingStats {
                    ProgressView("Loading cache statistics...")
                        .foregroundColor(.white)
                        .padding()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Kind Selection Grid
                if let stats = cacheStats, !stats.eventsByKind.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(stats.eventsByKind.sorted(by: { $0.value > $1.value }), id: \.key) { kind, count in
                                CacheKindCard(
                                    kind: kind,
                                    count: count,
                                    kindName: kindNames[kind] ?? "Kind \(kind)",
                                    isSelected: selectedKind == kind
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedKind = selectedKind == kind ? nil : kind
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 120)
                }
                
                // Event List
                if selectedKind != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Events")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if isLoadingEvents {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.5))
                            
                            TextField("Search events...", text: $searchQuery)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredEvents, id: \.id) { event in
                                    CachedEventRow(event: event)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
        }
        .navigationTitle("Cache Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingProfileCache = true
                    } label: {
                        Label("Profile Cache", systemImage: "person.circle")
                    }
                    
                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadCacheStatistics()
        }
        .onChange(of: selectedKind) { oldValue, newValue in
            if let kind = newValue {
                Task {
                    await loadEventsForKind(kind)
                }
            } else {
                cachedEvents = []
            }
        }
        .sheet(isPresented: $showingProfileCache) {
            ProfileCacheView()
                .environmentObject(nostrManager)
        }
    }
    
    private var filteredEvents: [NDKEvent] {
        if searchQuery.isEmpty {
            return cachedEvents
        }
        
        return cachedEvents.filter { event in
            event.content.localizedCaseInsensitiveContains(searchQuery) ||
            event.id.localizedCaseInsensitiveContains(searchQuery) ||
            event.pubkey.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private func loadCacheStatistics() async {
        let ndk = nostrManager.ndk
        
        isLoadingStats = true
        errorMessage = nil
        
        do {
            // Get cache from NDK
            if let cache = ndk.cache as? NDKSQLiteCache {
                let stats = try await cache.getStatistics()
                await MainActor.run {
                    self.cacheStats = stats
                    self.isLoadingStats = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Cache not available"
                    self.isLoadingStats = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load statistics: \(error.localizedDescription)"
                self.isLoadingStats = false
            }
        }
    }
    
    private func loadEventsForKind(_ kind: Int) async {
        let ndk = nostrManager.ndk
        
        await MainActor.run {
            isLoadingEvents = true
            cachedEvents = []
        }
        
        do {
            let filter = NDKFilter(kinds: [kind], limit: 50)
            let events = try await ndk.cache.queryEvents(filter)
            
            await MainActor.run {
                self.cachedEvents = events.sorted { $0.createdAt > $1.createdAt }
                self.isLoadingEvents = false
            }
        } catch {
            await MainActor.run {
                self.cachedEvents = []
                self.isLoadingEvents = false
            }
        }
    }
    
    private func clearCache() {
        // This would need to be implemented in NDKCache protocol
        // For now, just show an alert
        errorMessage = "Cache clearing not yet implemented"
    }
}

// MARK: - Cache Stats Header View
struct CacheStatsHeaderView: View {
    let stats: CacheStatistics
    
    private var totalSizeEstimate: String {
        // Rough estimate: ~1KB per event average
        let sizeInKB = stats.totalEvents
        if sizeInKB < 1024 {
            return "\(sizeInKB) KB"
        } else {
            let sizeInMB = Double(sizeInKB) / 1024.0
            return String(format: "%.1f MB", sizeInMB)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                CacheStatCard(
                    title: "Total Events",
                    value: "\(stats.totalEvents)",
                    icon: "doc.text.fill",
                    color: .blue
                )
                
                CacheStatCard(
                    title: "Event Kinds",
                    value: "\(stats.eventsByKind.count)",
                    icon: "square.grid.2x2",
                    color: .purple
                )
                
                CacheStatCard(
                    title: "Est. Size",
                    value: totalSizeEstimate,
                    icon: "externaldrive.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Cache Stat Card
struct CacheStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cache Kind Card
struct CacheKindCard: View {
    let kind: Int
    let count: Int
    let kindName: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(kindName)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Kind \(kind)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
}

// MARK: - Cached Event Row
struct CachedEventRow: View {
    let event: NDKEvent
    @State private var isExpanded = false
    
    private var eventTypeIcon: String {
        switch event.kind {
        case 0: return "person.circle"
        case 1: return "text.bubble"
        case 3: return "person.2"
        case 4: return "envelope"
        case 5: return "trash"
        case 6: return "arrow.triangle.2.circlepath"
        case 7: return "heart"
        case 1063: return "doc"
        case 1808: return "waveform"
        default: return "doc.text"
        }
    }
    
    private var timestamp: String {
        let date = Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: eventTypeIcon)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.id.prefix(16) + "...")
                        .font(.caption)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(timestamp)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Content preview
            if !event.content.isEmpty {
                Text(event.content)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(isExpanded ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    DetailRow(label: "Author", value: String(event.pubkey.prefix(16)) + "...")
                    DetailRow(label: "Created", value: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(event.createdAt))))
                    
                    if !event.tags.isEmpty {
                        DetailRow(label: "Tags", value: "\(event.tags.count) tags")
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}

// MARK: - Profile Cache View
struct ProfileCacheView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var cachedProfiles: [(pubkey: String, profile: NDKUserProfile)] = []
    @State private var isLoading = false
    @State private var searchQuery = ""
    @Environment(\.dismiss) var dismiss
    
    private var filteredProfiles: [(pubkey: String, profile: NDKUserProfile)] {
        if searchQuery.isEmpty {
            return cachedProfiles
        }
        
        return cachedProfiles.filter { item in
            item.profile.name?.localizedCaseInsensitiveContains(searchQuery) ?? false ||
            item.profile.displayName?.localizedCaseInsensitiveContains(searchQuery) ?? false ||
            item.pubkey.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
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
                
                VStack {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Search profiles...", text: $searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                    
                    if isLoading {
                        ProgressView("Loading cached profiles...")
                            .foregroundColor(.white)
                            .frame(maxHeight: .infinity)
                    } else if filteredProfiles.isEmpty {
                        VStack {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text(searchQuery.isEmpty ? "No cached profiles" : "No profiles match your search")
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredProfiles, id: \.pubkey) { item in
                                    ProfileCacheRow(pubkey: item.pubkey, profile: item.profile)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Profile Cache")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                await loadCachedProfiles()
            }
        }
    }
    
    private func loadCachedProfiles() async {
        let ndk = nostrManager.ndk
        
        isLoading = true
        
        // For now, we'll fetch recent metadata events as a proxy for cached profiles
        let filter = NDKFilter(kinds: [0], limit: 100)
        
        do {
            let events = try await ndk.cache.queryEvents(filter)
            
            var profiles: [(String, NDKUserProfile)] = []
            
            for event in events {
                if let profileData = event.content.data(using: String.Encoding.utf8),
                   let profile = try? JSONDecoder().decode(NDKUserProfile.self, from: profileData) {
                    profiles.append((event.pubkey, profile))
                }
            }
            
            await MainActor.run {
                self.cachedProfiles = profiles.sorted { p1, p2 in
                    let name1 = p1.1.displayName ?? p1.1.name ?? p1.0
                    let name2 = p2.1.displayName ?? p2.1.name ?? p2.0
                    return name1 < name2
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Profile Cache Row
struct ProfileCacheRow: View {
    let pubkey: String
    let profile: NDKUserProfile
    
    private var displayName: String {
        profile.displayName ?? profile.name ?? String(pubkey.prefix(16)) + "..."
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let picture = profile.picture, let url = URL(string: picture) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Text(String(displayName.prefix(1)).uppercased())
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Text(String(displayName.prefix(1)).uppercased())
                            .foregroundColor(.white.opacity(0.5))
                    )
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                if let nip05 = profile.nip05 {
                    Text(nip05)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text(String(pubkey.prefix(16)) + "...")
                    .font(.caption2)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}