import SwiftUI
import NDKSwift

struct NDKDebugLogsView: View {
    @StateObject private var logManager = NDKLogManager.shared
    @State private var autoScroll = true
    @State private var filter = ""
    
    var filteredLogs: [NDKLogEntry] {
        if filter.isEmpty {
            return logManager.logs
        }
        return logManager.logs.filter { log in
            log.message.localizedCaseInsensitiveContains(filter) ||
            log.category.rawValue.localizedCaseInsensitiveContains(filter)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            VStack(spacing: 12) {
                HStack {
                    Text("NDK Debug Logs")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        logManager.clear()
                    }) {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Filter logs...", text: $filter)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    Toggle("Auto-scroll", isOn: $autoScroll)
                        .toggleStyle(.switch)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Logs
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredLogs) { log in
                            LogEntryView(log: log)
                                .id(log.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color.black)
                .onChange(of: logManager.logs.count) { _, _ in
                    if autoScroll, let lastLog = logManager.logs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .background(Color.black)
    }
}

struct LogEntryView: View {
    let log: NDKLogEntry
    
    var icon: String {
        switch log.level {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Timestamp and category
            HStack {
                Text(log.timestamp, style: .time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                
                Text("[\(log.category.rawValue)]")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(categoryColor)
                
                Spacer()
            }
            
            // Message with icon
            HStack(alignment: .top, spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                
                Text(log.message)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Additional details if present
            if let details = log.details, !details.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(details.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text("\(key):")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(value)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .textSelection(.enabled)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor)
        .cornerRadius(6)
    }
    
    var categoryColor: Color {
        switch log.category {
        case .network: return .blue
        case .relay: return .green
        case .subscription: return .orange
        case .event: return .purple
        case .cache: return .cyan
        case .auth: return .yellow
        case .wallet: return .mint
        case .general: return .gray
        case .connection: return .teal
        case .outbox: return .indigo
        case .signer: return .pink
        case .sync: return .brown
        case .performance: return .red
        case .security: return .orange
        case .database: return .blue
        case .signature: return .purple
        }
    }
    
    var backgroundColor: Color {
        switch log.level {
        case .error: return Color.red.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .success: return Color.green.opacity(0.1)
        default: return Color.white.opacity(0.05)
        }
    }
}

// MARK: - Log Models
struct NDKLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: LogLevel
    let category: LogCategory
    let message: String
    let details: [String: String]?
    
    enum LogLevel {
        case debug, info, warning, error, success
    }
    
    enum LogCategory: String {
        case network = "NETWORK"
        case relay = "RELAY"
        case subscription = "SUBSCRIPTION"
        case event = "EVENT"
        case cache = "CACHE"
        case auth = "AUTH"
        case wallet = "WALLET"
        case general = "GENERAL"
        case connection = "CONNECTION"
        case outbox = "OUTBOX"
        case signer = "SIGNER"
        case sync = "SYNC"
        case performance = "PERFORMANCE"
        case security = "SECURITY"
        case database = "DATABASE"
        case signature = "SIGNATURE"
    }
}

// MARK: - Log Manager
class NDKLogManager: ObservableObject {
    static let shared = NDKLogManager()
    
    @Published var logs: [NDKLogEntry] = []
    private let maxLogs = 1000
    
    private init() {
        // Start capturing NDK logs
        setupNDKLogging()
    }
    
    func clear() {
        logs.removeAll()
    }
    
    private func setupNDKLogging() {
        // Set custom log handler for NDK
        NDKLogger.logHandler = { [weak self] formattedMessage in
            Task { @MainActor in
                self?.parseAndAddLog(formattedMessage)
            }
        }
        
        // Enable verbose logging in NDK
        NDKLogger.logLevel = .trace
        
        // Enable all categories
        NDKLogger.enabledCategories = Set(NDKLogCategory.allCases)
    }
    
    private func parseAndAddLog(_ formattedMessage: String) {
        // Parse NDK log format: [timestamp] [category] [level] emoji message
        let components = formattedMessage.components(separatedBy: "] ")
        guard components.count >= 3 else {
            addLog(level: .info, category: .general, message: formattedMessage, details: nil)
            return
        }
        
        // Extract components
        let categoryStr = components[1].replacingOccurrences(of: "[", with: "")
        let levelStr = components[2].replacingOccurrences(of: "[", with: "")
        let messageWithEmoji = components[3...].joined(separator: "] ")
        
        // Remove emoji prefix if present
        let message = messageWithEmoji.trimmingCharacters(in: .whitespaces)
        
        // Map level and category
        let level = mapLogLevel(levelStr)
        let category = mapLogCategory(categoryStr)
        
        addLog(level: level, category: category, message: message, details: nil)
    }
    
    private func addLog(level: NDKLogEntry.LogLevel, category: NDKLogEntry.LogCategory, message: String, details: [String: String]?) {
        let entry = NDKLogEntry(level: level, category: category, message: message, details: details)
        logs.append(entry)
        
        // Keep only the last maxLogs entries
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
    
    private func mapLogLevel(_ levelStr: String) -> NDKLogEntry.LogLevel {
        switch levelStr.lowercased() {
        case "trace", "verbose", "debug": return .debug
        case "info": return .info
        case "warning", "warn": return .warning
        case "error": return .error
        case "success": return .success
        default: return .info
        }
    }
    
    private func mapLogCategory(_ categoryStr: String) -> NDKLogEntry.LogCategory {
        // Convert to uppercase to match enum raw values
        let uppercased = categoryStr.uppercased()
        return NDKLogEntry.LogCategory(rawValue: uppercased) ?? .general
    }
}

// MARK: - Preview
struct NDKDebugLogsView_Previews: PreviewProvider {
    static var previews: some View {
        NDKDebugLogsView()
            .preferredColorScheme(.dark)
    }
}