import SwiftUI
import NDKSwift

struct BlossomSettingsView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @State private var newServerUrl = ""
    @State private var showingAddServer = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    
    private var serverManager: Any? { // NDKBlossomServerManager? {
        nil // Server manager not available yet
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Blossom Servers")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showingAddServer = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // Server list - always show immediately
                List {
                    // Show default server for now
                    ServerRow(
                        server: "https://blossom.primal.net",
                        isPrimary: true,
                        onDelete: {
                            // Cannot delete default server
                        }
                    )
                    .listRowBackground(Color.gray.opacity(0.1))
                    .listRowSeparatorTint(.gray.opacity(0.3))
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Label("The first server in the list will be used for uploads", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Label("Drag to reorder servers", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddServer) {
            AddServerSheet(
                serverUrl: $newServerUrl,
                suggestedServers: [], // No suggestions available
                existingServers: ["https://blossom.primal.net"],
                onAdd: { url in
                    addServer(url)
                    showingAddServer = false
                    newServerUrl = ""
                },
                onCancel: {
                    showingAddServer = false
                    newServerUrl = ""
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addServer(_ url: String) {
        // Clean up URL
        var cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme
        if !cleanUrl.hasPrefix("http://") && !cleanUrl.hasPrefix("https://") {
            cleanUrl = "https://\(cleanUrl)"
        }
        
        // Validate URL
        guard let validUrl = URL(string: cleanUrl),
              validUrl.host != nil else {
            errorMessage = "Invalid server URL"
            showingError = true
            return
        }
        
        // For now, just show error that we cannot add servers
        errorMessage = "Server management not available yet"
        showingError = true
    }
}

// MARK: - Server Row
struct ServerRow: View {
    let server: String
    let isPrimary: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatServerUrl(server))
                    .font(.body)
                    .foregroundColor(.white)
                
                if isPrimary {
                    Label("Primary upload server", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatServerUrl(_ url: String) -> String {
        var formatted = url
        if formatted.hasPrefix("https://") {
            formatted = String(formatted.dropFirst(8))
        } else if formatted.hasPrefix("http://") {
            formatted = String(formatted.dropFirst(7))
        }
        if formatted.hasSuffix("/") {
            formatted = String(formatted.dropLast())
        }
        return formatted
    }
}

// MARK: - Add Server Sheet
struct AddServerSheet: View {
    @Binding var serverUrl: String
    let suggestedServers: [Any] // [NDKBlossomServerInfo]
    let existingServers: [String]
    let onAdd: (String) -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingSuggestions = true
    
    var availableSuggestions: [Any] { // [NDKBlossomServerInfo] {
        [] // No suggestions available
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Add Blossom Server")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("blossom.example.com", text: $serverUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                                .focused($isTextFieldFocused)
                        }
                        .padding(.horizontal)
                        
                        if !availableSuggestions.isEmpty && showingSuggestions {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Suggested Servers")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button("Hide") {
                                        withAnimation {
                                            showingSuggestions = false
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                
                                // No suggested servers available
                            }
                            .padding(.top)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                
                VStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        
                        Button("Add") {
                            onAdd(serverUrl)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .disabled(serverUrl.isEmpty)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black,
                                Color.black.opacity(0.95),
                                Color.black.opacity(0.9)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .ignoresSafeArea()
                    )
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

