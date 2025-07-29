import Foundation
import NDKSwift

// MARK: - Outbox Debug Data Models

enum RelayHealth: CaseIterable {
    case excellent  // Score > 0.8, low latency, no recent failures
    case good       // Score > 0.6, moderate latency, few failures
    case fair       // Score > 0.4, higher latency, some failures
    case poor       // Score > 0.2, high latency, many failures
    case unknown    // No metadata available
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
    
    static func from(metadata: RelayMetadata?) -> RelayHealth {
        guard let metadata = metadata,
              let score = metadata.score else {
            return .unknown
        }
        
        if score > 0.8 { return .excellent }
        if score > 0.6 { return .good }
        if score > 0.4 { return .fair }
        if score > 0.2 { return .poor }
        return .poor
    }
}

struct OutboxSummary {
    let totalUsers: Int
    let totalRelays: Int
    let averageRelaysPerUser: Double
    let lastUpdateTime: Date
    let unknownUsersCount: Int
    let activeSubscriptions: Int
    
    static let empty = OutboxSummary(
        totalUsers: 0,
        totalRelays: 0,
        averageRelaysPerUser: 0,
        lastUpdateTime: Date(),
        unknownUsersCount: 0,
        activeSubscriptions: 0
    )
}

struct OutboxEntry: Identifiable {
    let id = UUID()
    let pubkey: String
    var displayName: String?
    let npub: String
    let readRelays: [RelayDisplayInfo]
    let writeRelays: [RelayDisplayInfo]
    let lastUpdated: Date
    let source: String
    let totalRelayCount: Int
    
    init(from item: NDKOutboxItem, displayName: String? = nil) {
        self.pubkey = item.pubkey
        self.displayName = displayName
        let pubkeyData = Data(hex: item.pubkey) ?? Data()
        self.npub = (try? Bech32.encode(hrp: "npub", data: [UInt8](pubkeyData))) ?? item.pubkey
        self.readRelays = item.readRelays.map { RelayDisplayInfo(from: $0) }
        self.writeRelays = item.writeRelays.map { RelayDisplayInfo(from: $0) }
        self.lastUpdated = item.fetchedAt
        self.source = item.source.description
        self.totalRelayCount = item.allRelayURLs.count
    }
}

struct RelayDisplayInfo: Identifiable {
    let id = UUID()
    let url: String
    let metadata: RelayMetadata?
    let score: Double?
    let health: RelayHealth
    let lastConnected: Date?
    let averageResponseTime: Double?
    let failureCount: Int
    let requiresAuth: Bool
    let requiresPayment: Bool
    
    init(from relayInfo: RelayInfo) {
        self.url = relayInfo.url
        self.metadata = relayInfo.metadata
        self.score = relayInfo.metadata?.score
        self.health = RelayHealth.from(metadata: relayInfo.metadata)
        self.lastConnected = relayInfo.metadata?.lastConnectedAt
        self.averageResponseTime = relayInfo.metadata?.avgResponseTime
        self.failureCount = relayInfo.metadata?.failureCount ?? 0
        self.requiresAuth = relayInfo.metadata?.authRequired ?? false
        self.requiresPayment = relayInfo.metadata?.paymentRequired ?? false
    }
}

// MARK: - Extensions

extension RelayListSource {
    var description: String {
        switch self {
        case .nip65:
            return "NIP-65 Relay List"
        case .contactList:
            return "Contact List (Kind 3)"
        case .manual:
            return "Manual Configuration"
        case .unknown:
            return "Unknown Source"
        }
    }
}

extension Data {
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex
        for _ in 0..<len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}