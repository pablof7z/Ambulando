import Foundation

enum BlossomError: LocalizedError {
    case uploadFailed
    case noServersAvailable
    case invalidServerURL
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload file to Blossom server"
        case .noServersAvailable:
            return "No Blossom servers available"
        case .invalidServerURL:
            return "Invalid Blossom server URL"
        case .authenticationFailed:
            return "Failed to authenticate with Blossom server"
        }
    }
}