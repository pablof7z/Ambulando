import Foundation
import NDKSwift

struct BlossomServerInfo: Identifiable, Equatable {
    let id: String
    let url: String
    let name: String
    let description: String
    let isPaid: Bool
    let isWhitelisted: Bool
    let whitelistMessage: String?
    let paidMessage: String?
    
    init(url: String, name: String, description: String, isPaid: Bool = false, isWhitelisted: Bool = false, whitelistMessage: String? = nil, paidMessage: String? = nil) {
        self.id = url
        self.url = url
        self.name = name
        self.description = description
        self.isPaid = isPaid
        self.isWhitelisted = isWhitelisted
        self.whitelistMessage = whitelistMessage
        self.paidMessage = paidMessage
    }
    
    init(from event: NDKEvent) {
        self.id = event.id
        self.description = event.content
        
        var extractedUrl = ""
        var extractedName = ""
        var extractedIsPaid = false
        var extractedIsWhitelisted = false
        var extractedWhitelistMessage: String?
        var extractedPaidMessage: String?
        
        // Parse tags
        for tag in event.tags {
            guard tag.count >= 2 else { continue }
            
            switch tag[0] {
            case "d":
                extractedUrl = tag[1]
            case "name":
                extractedName = tag[1]
            case "paid":
                extractedIsPaid = true
                if tag.count > 1 {
                    extractedPaidMessage = tag[1]
                }
            case "whitelist":
                extractedIsWhitelisted = true
                if tag.count > 1 {
                    extractedWhitelistMessage = tag[1]
                }
            default:
                break
            }
        }
        
        self.url = extractedUrl
        self.name = extractedName.isEmpty ? Self.extractServerName(from: extractedUrl) : extractedName
        self.isPaid = extractedIsPaid
        self.isWhitelisted = extractedIsWhitelisted
        self.whitelistMessage = extractedWhitelistMessage
        self.paidMessage = extractedPaidMessage
    }
    
    /// Extracts a display name from the server URL
    private static func extractServerName(from url: String) -> String {
        // Remove protocol
        var name = url
        if let range = name.range(of: "://") {
            name = String(name[range.upperBound...])
        }
        
        // Remove trailing slash
        if name.hasSuffix("/") {
            name = String(name.dropLast())
        }
        
        // Remove www.
        if name.hasPrefix("www.") {
            name = String(name.dropFirst(4))
        }
        
        // Take first part before any path
        if let firstSlash = name.firstIndex(of: "/") {
            name = String(name[..<firstSlash])
        }
        
        return name
    }
    
    /// Display subtitle for the server
    var subtitle: String? {
        if isPaid && isWhitelisted {
            return "Paid & Whitelisted"
        } else if isPaid {
            return "Paid"
        } else if isWhitelisted {
            return "Whitelist Required"
        } else {
            return "Free"
        }
    }
    
    /// Combined access message
    var accessMessage: String? {
        if let paidMsg = paidMessage, let whitelistMsg = whitelistMessage {
            return "\(paidMsg)\n\(whitelistMsg)"
        } else if let paidMsg = paidMessage {
            return paidMsg
        } else if let whitelistMsg = whitelistMessage {
            return whitelistMsg
        } else if isPaid || isWhitelisted {
            return "Access restricted"
        }
        return nil
    }
}