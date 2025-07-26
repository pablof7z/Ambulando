import Foundation
import NDKSwift

struct AudioEvent: Identifiable, Equatable {
    let id: String
    let event: NDKEvent
    let author: NDKUser
    let audioURL: String
    let createdAt: Date
    let isReply: Bool
    let replyTo: String?
    let replyToPubkey: String?
    let webOfTrustScore: Double
    let waveform: [Double]?
    let duration: TimeInterval?
    
    // Reaction tracking (populated separately)
    var likeCount: Int = 0
    var zapCount: Int = 0
    var replyCount: Int = 0
    
    static func == (lhs: AudioEvent, rhs: AudioEvent) -> Bool {
        lhs.id == rhs.id
    }
    
    var sortScore: Double {
        // Combine recency and web of trust
        let recencyScore = 1.0 - (Date().timeIntervalSince(createdAt) / (7 * 24 * 60 * 60)) // Decay over 7 days
        return (webOfTrustScore * 0.7) + (max(0, recencyScore) * 0.3)
    }
    
    var hashtags: [String] {
        // Extract hashtags from 't' tags
        return event.tags.compactMap { tag in
            guard tag.count >= 2 && tag[0] == "t" else { return nil }
            return tag[1]
        }
    }
    
    static func from(event: NDKEvent, webOfTrustScore: Double) -> AudioEvent? {
        guard let audioURL = extractAudioURL(from: event.content) else { return nil }
        
        let isReply = event.kind == 1244
        let replyTo = isReply ? extractReplyTo(from: event) : nil
        let replyToPubkey = isReply ? extractReplyToPubkey(from: event) : nil
        
        // Parse imeta tag for waveform and duration
        let (waveform, duration) = extractMetadata(from: event, audioURL: audioURL)
        
        return AudioEvent(
            id: event.id,
            event: event,
            author: NDKUser(pubkey: event.pubkey),
            audioURL: audioURL,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            isReply: isReply,
            replyTo: replyTo,
            replyToPubkey: replyToPubkey,
            webOfTrustScore: webOfTrustScore,
            waveform: waveform,
            duration: duration
        )
    }
    
    private static func extractAudioURL(from content: String) -> String? {
        // Content should be a direct URL
        guard let url = URL(string: content),
              url.scheme == "https" || url.scheme == "http" else {
            return nil
        }
        return content
    }
    
    private static func extractReplyTo(from event: NDKEvent) -> String? {
        // Look for 'e' tag that marks the reply target
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "e" {
                return tag[1]
            }
        }
        return nil
    }
    
    private static func extractReplyToPubkey(from event: NDKEvent) -> String? {
        // Look for 'p' tag that indicates who we're replying to
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "p" {
                return tag[1]
            }
        }
        return nil
    }
    
    private static func extractMetadata(from event: NDKEvent, audioURL: String) -> (waveform: [Double]?, duration: TimeInterval?) {
        // Use NDKSwift's built-in imeta parsing
        let audioImeta = event.imetas(for: audioURL).first
        
        // Extract waveform from additionalFields
        var waveform: [Double]?
        if let waveformString = audioImeta?.additionalFields["waveform"] {
            waveform = waveformString.split(separator: " ")
                .compactMap { Double($0) }
        }
        
        // Extract duration from additionalFields
        var duration: TimeInterval?
        if let durationString = audioImeta?.additionalFields["duration"] {
            duration = TimeInterval(durationString)
        }
        
        return (waveform, duration)
    }
}