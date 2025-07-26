import Foundation
import NDKSwift

@MainActor
class BlossomServerManager: ObservableObject {
    @Published var servers: [String] = []
    @Published var isLoading = false
    @Published var suggestedServers: [BlossomServerInfo] = []
    
    private let ndk: NDK?
    private let defaultServer = "https://blossom.primal.net"
    private static let userDefaultsKey = "AmbulandoBlossomServers"
    private var suggestionsTask: Task<Void, Never>?
    
    init(ndk: NDK?) {
        self.ndk = ndk
        loadServers()
        loadSuggestedServers()
    }
    
    deinit {
        suggestionsTask?.cancel()
    }
    
    // MARK: - Server Management
    
    func loadServers() {
        guard let ndk = ndk, let signer = ndk.signer else {
            // Fallback to default server
            servers = [defaultServer]
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Get the public key from signer
                let pubkey = try await signer.pubkey
                
                // Fetch user's blossom server list event (kind 10063)
                let filter = NDKFilter(
                    authors: [pubkey],
                    kinds: [10063],
                    limit: 1
                )
                
                // Use observe to get the event
                let dataSource = ndk.observe(filter: filter, maxAge: 300, cachePolicy: .cacheWithNetwork)
                
                var foundEvent = false
                for await event in dataSource.events {
                    parseServersFromEvent(event)
                    foundEvent = true
                    break // We only need the first event
                }
                
                if !foundEvent {
                    // No server list found, use default
                    servers = [defaultServer]
                }
            } catch {
                print("Failed to fetch blossom server list: \(error)")
                servers = [defaultServer]
            }
            
            isLoading = false
        }
    }
    
    private func parseServersFromEvent(_ event: NDKEvent) {
        var serverList: [String] = []
        
        // Parse server tags
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "server" {
                let serverUrl = tag[1]
                if !serverUrl.isEmpty {
                    serverList.append(serverUrl)
                }
            }
        }
        
        // Update servers list
        servers = serverList.isEmpty ? [defaultServer] : serverList
        
        // Save to UserDefaults
        saveToUserDefaults()
    }
    
    // MARK: - Persistence
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(servers, forKey: Self.userDefaultsKey)
    }
    
    private func loadFromUserDefaults() {
        if let savedServers = UserDefaults.standard.stringArray(forKey: Self.userDefaultsKey),
           !savedServers.isEmpty {
            servers = savedServers
        } else {
            servers = [defaultServer]
        }
    }
    
    // MARK: - Server Management UI
    
    func addServer(_ serverUrl: String) {
        guard !servers.contains(serverUrl) else { return }
        servers.append(serverUrl)
        saveToUserDefaults()
        publishServerList()
    }
    
    func removeServer(_ serverUrl: String) {
        servers.removeAll { $0 == serverUrl }
        if servers.isEmpty {
            servers = [defaultServer]
        }
        saveToUserDefaults()
        publishServerList()
    }
    
    func removeServer(at index: Int) {
        guard index >= 0 && index < servers.count else { return }
        servers.remove(at: index)
        if servers.isEmpty {
            servers = [defaultServer]
        }
        saveToUserDefaults()
        publishServerList()
    }
    
    func moveServer(from source: IndexSet, to destination: Int) {
        var newServers = servers
        for index in source.sorted(by: >) {
            let server = newServers.remove(at: index)
            let adjustedDestination = destination > index ? destination - 1 : destination
            newServers.insert(server, at: adjustedDestination)
        }
        servers = newServers
        saveToUserDefaults()
        publishServerList()
    }
    
    private func publishServerList() {
        guard let ndk = ndk else { return }
        
        Task {
            do {
                // Create server list event (kind 10063)
                let (_, _) = try await ndk.publish { builder in
                    var eventBuilder = builder.kind(10063)
                    
                    // Add server tags
                    for server in servers {
                        eventBuilder = eventBuilder.tag(["server", server])
                    }
                    
                    return eventBuilder
                }
                
                print("Published blossom server list")
            } catch {
                print("Failed to publish server list: \(error)")
            }
        }
    }
    
    // MARK: - Convenience
    
    /// Get all servers for fallback upload attempts
    var allServers: [String] {
        servers.isEmpty ? [defaultServer] : servers
    }
    
    // MARK: - Suggested Servers
    
    func loadSuggestedServers() {
        guard let ndk = ndk else {
            print("BlossomServerManager: No NDK instance available for loading suggested servers")
            return
        }
        
        suggestionsTask?.cancel()
        suggestionsTask = Task {
            print("BlossomServerManager: Starting to fetch kind 36363 events...")
            
            // Create filter for Blossom server discovery events (kind 36363)
            let filter = NDKFilter(
                kinds: [36363],
                limit: 50
            )
            
            // Use observe with cache-first approach
            let dataSource = ndk.observe(filter: filter, maxAge: 3600, cachePolicy: .cacheWithNetwork)
            
            var serverInfos: [BlossomServerInfo] = []
            var seenUrls = Set<String>()
            
            for await event in dataSource.events {
                if Task.isCancelled { break }
                
                let serverInfo = BlossomServerInfo(from: event)
                
                // Only add if we haven't seen this URL before and it's valid
                if !serverInfo.url.isEmpty && !seenUrls.contains(serverInfo.url) {
                    seenUrls.insert(serverInfo.url)
                    serverInfos.append(serverInfo)
                    
                    print("BlossomServerManager: Found server: \(serverInfo.name) at \(serverInfo.url)")
                    
                    // Update UI incrementally
                    suggestedServers = serverInfos.sorted { server1, server2 in
                        // Sort free servers first, then by name
                        if server1.isPaid == server2.isPaid && server1.isWhitelisted == server2.isWhitelisted {
                            return server1.name < server2.name
                        }
                        if server1.isPaid != server2.isPaid {
                            return !server1.isPaid
                        }
                        return !server1.isWhitelisted
                    }
                }
            }
            
            print("BlossomServerManager: Finished loading suggested servers. Found \(serverInfos.count) servers.")
        }
    }
}