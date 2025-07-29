import Foundation

extension URLSession {
    static let ambulando: URLSession = {
        let configuration = URLSessionConfiguration.default
        
        // Set a proper user agent to avoid being blocked by Cloudflare and other services
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        
        // Format: Ambulando/1.0 (build 1; iOS 17.0)
        let userAgent = "Ambulando/\(appVersion) (build \(buildNumber); \(osVersion))"
        
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        
        // Additional configuration for better performance
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        return URLSession(configuration: configuration)
    }()
}