import SwiftUI
import NDKSwift
import NDKSwiftUI
import AVFoundation

struct HomeFeedView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState
    
    @State private var audioEvents: [AudioEvent] = []
    @State private var showRecordingHint = true
    @State private var recordingScale: CGFloat = 1
    @State private var recordingOpacity: Double = 1
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var dataSourceTask: Task<Void, Never>?
    @State private var selectedRelay: String? = nil
    @State private var showRelaySelector = false
    
    // Recording states
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var showingRecordingUI = false
    @State private var recordingWaveform: [CGFloat] = []
    @State private var fullWaveform: [Double] = [] // Store full waveform for imeta
    
    // Upload and preview states
    @State private var isUploading = false
    @State private var uploadedURL: String?
    @State private var isShowingPreview = false
    @State private var audioPlayer: AVAudioPlayer?
    
    // Playback states
    @State private var isPlaying = false
    @State private var playbackTimer: Timer?
    @State private var playbackProgress: TimeInterval = 0
    @State private var playbackWaveformProgress: Int = 0
    
    var sortedEvents: [AudioEvent] {
        audioEvents.sorted { $0.sortScore > $1.sortScore }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HeaderView(selectedRelay: $selectedRelay, showRelaySelector: $showRelaySelector)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // Feed - Always show UI immediately, no loading states
                if audioEvents.isEmpty {
                    EmptyFeedView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedEvents) { audioEvent in
                                AudioEventCard(audioEvent: audioEvent)
                                    .transition(.asymmetric(
                                        insertion: .opacity,
                                        removal: .scale(scale: 0.8).combined(with: .opacity)
                                    ))
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .refreshable {
                        await refreshAudioEvents()
                    }
                }
            }
            
            // Recording UI overlay
            if showingRecordingUI {
                RecordingOverlay(
                    duration: recordingDuration,
                    waveform: recordingWaveform,
                    onCancel: cancelRecording,
                    onComplete: completeRecording,
                    isUploading: isUploading,
                    uploadedURL: uploadedURL,
                    onPreview: playPreview,
                    onPublish: publishRecording,
                    isPlaying: isPlaying,
                    playbackProgress: playbackProgress,
                    playbackWaveformProgress: playbackWaveformProgress,
                    replyingTo: appState.replyingTo
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Floating record button - hide when recording overlay is shown
            if !showingRecordingUI {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        RecordButton(
                            isRecording: $appState.isRecording,
                            onStartRecording: startRecording,
                            onStopRecording: stopRecording
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Relay selector modal
            if showRelaySelector {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showRelaySelector = false
                    }
                    .zIndex(1)
                
                RelaySelectorView(
                    selectedRelay: $selectedRelay,
                    isPresented: $showRelaySelector
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showRelaySelector)
        .onAppear {
            startStreamingAudioEvents()
        }
        .onChange(of: selectedRelay) { _, _ in
            // Restart streaming with new relay filter
            startStreamingAudioEvents()
        }
        .onChange(of: appState.replyingTo) { _, newValue in
            // Start recording when reply context is set
            if newValue != nil {
                startRecording()
            }
        }
        .onDisappear {
            dataSourceTask?.cancel()
        }
    }
    
    private func startStreamingAudioEvents() {
        guard let ndk = nostrManager.ndk else { return }
        
        // Cancel any existing task
        dataSourceTask?.cancel()
        
        // Clear events when switching relays
        audioEvents.removeAll()
        
        // Create filter for audio events
        let filter = NDKFilter(
            kinds: [1222, 1244]
        )
        
        // If a specific relay is selected, use it; otherwise use all relays
        let relayUrls: Set<String>? = selectedRelay != nil ? [selectedRelay!] : nil
        
        // Start streaming task
        dataSourceTask = Task {
            // Stream audio events
            // When a specific relay is selected, use networkOnly to ensure we only get events from that relay
            // (cached events don't store relay information, so exclusiveRelays can't filter them)
            let dataSource: NDKDataSource<NDKEvent>
            if let relayUrls = relayUrls {
                // Use networkOnly to ensure we only get events from the selected relay
                dataSource = ndk.observe(filter: filter, maxAge: 0, cachePolicy: .networkOnly, relays: relayUrls, exclusiveRelays: true)
            } else {
                // For all relays, use cache for better performance
                dataSource = ndk.observe(filter: filter, maxAge: 0, cachePolicy: .cacheWithNetwork)
            }
            
            for await event in dataSource.events {
                // Check if task was cancelled
                if Task.isCancelled { break }
                
                // Skip muted users if session data is available
                if let sessionData = ndk.sessionData, sessionData.isMuted(event.pubkey) {
                    continue
                }
                
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
                            withAnimation(.easeOut(duration: 0.3)) {
                                self.audioEvents.append(audioEvent)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func refreshAudioEvents() async {
        guard nostrManager.ndk != nil else { return }
        
        // Clear existing events for a fresh feed
        await MainActor.run {
            audioEvents.removeAll()
        }
        
        // Re-start the streaming with fresh data
        // This will fetch from network due to maxAge: 0 in the main stream
        startStreamingAudioEvents()
    }
    
    private func startRecording() {
        // Request microphone permission
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            if granted {
                await MainActor.run {
                    setupRecording()
                }
            }
        }
    }
    
    private func setupRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("voice_\(Date().timeIntervalSince1970).m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            
            audioRecorder?.record()
            
            appState.isRecording = true
            appState.recordingStartTime = Date()
            showingRecordingUI = true
            recordingDuration = 0
            fullWaveform = [] // Reset waveform data
            
            // Start timer for duration and waveform
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                updateRecording()
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func updateRecording() {
        guard let recorder = audioRecorder,
              let startTime = appState.recordingStartTime else { return }
        
        recorder.updateMeters()
        
        recordingDuration = Date().timeIntervalSince(startTime)
        
        // Update waveform using peak power for more responsive visualization
        // Peak power gives instantaneous levels, average power is too smoothed
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Convert from decibels to linear scale (0-1 range)
        // Peak power range is typically -160 (silence) to 0 (max)
        // Clamp to reasonable range for better visualization
        let clampedPower = max(-50, peakPower) // Clamp to -50 dB minimum
        let normalizedValue = pow(10, clampedPower / 20)
        
        recordingWaveform.append(CGFloat(normalizedValue))
        
        // Store normalized amplitude value for imeta (0-1 range)
        fullWaveform.append(Double(normalizedValue))
        
        // Keep last 50 samples for UI display
        if recordingWaveform.count > 50 {
            recordingWaveform.removeFirst()
        }
        
        // Auto-stop at 60 seconds
        if recordingDuration >= 60 {
            stopRecording()
        }
    }
    
    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        appState.isRecording = false
        
        // Show completion UI
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            // Transition to publish state
        }
    }
    
    private func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        audioRecorder = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Clean up playback state
        stopPlaybackTracking()
        
        appState.isRecording = false
        appState.replyingTo = nil  // Clear reply context
        showingRecordingUI = false
        recordingWaveform = []
        fullWaveform = []
        isUploading = false
        self.uploadedURL = nil
        isShowingPreview = false
    }
    
    private func completeRecording() {
        guard let recorder = audioRecorder,
              let ndk = nostrManager.ndk,
              let signer = ndk.signer else { return }
        
        // Stop the timer and recording first
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        recorder.stop()
        appState.isRecording = false
        
        let audioUrl = recorder.url
        
        // Start upload process
        isUploading = true
        
        Task {
            do {
                // Read audio file data
                let audioData = try Data(contentsOf: audioUrl)
                
                // Check if we have actual audio data
                guard audioData.count > 1000 else { // At least 1KB of data
                    throw NSError(domain: "RecordingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording file is too small or empty"])
                }
                
                // Upload to Blossom servers with fallback
                var uploadResult: String? = nil
                var uploadError: Error? = nil
                
                let servers = ["https://blossom.primal.net"] // Default to primal.net for now
                for server in servers {
                    do {
                        // Create blossom client and upload
                        let blossomClient = BlossomClient()
                        
                        // Upload audio file with auth
                        let result = try await blossomClient.uploadWithAuth(
                            data: audioData,
                            mimeType: "audio/m4a",
                            to: server,
                            signer: signer,
                            ndk: ndk
                        )
                        
                        uploadResult = result.url
                        print("Successfully uploaded audio to \(server)")
                        break // Success, no need to try other servers
                        
                    } catch {
                        print("Failed to upload to \(server): \(error)")
                        uploadError = error
                        continue // Try next server
                    }
                }
                
                guard let finalUploadedURL = uploadResult else {
                    throw uploadError ?? BlossomError.uploadFailed
                }
                
                await MainActor.run {
                    self.uploadedURL = finalUploadedURL
                    self.isUploading = false
                    self.isShowingPreview = true
                }
                
            } catch {
                print("Failed to upload audio: \(error)")
                await MainActor.run {
                    self.isUploading = false
                    // TODO: Show error to user
                }
            }
        }
    }
    
    private func compressWaveform(_ waveform: [Double], targetSamples: Int) -> [Double] {
        guard waveform.count > targetSamples else { return waveform }
        
        var compressed: [Double] = []
        let bucketSize = Double(waveform.count) / Double(targetSamples)
        
        for i in 0..<targetSamples {
            let startIndex = Int(Double(i) * bucketSize)
            let endIndex = min(Int(Double(i + 1) * bucketSize), waveform.count)
            
            if startIndex < endIndex {
                // Take the average of values in this bucket
                let bucketValues = waveform[startIndex..<endIndex]
                let average = bucketValues.reduce(0.0, +) / Double(bucketValues.count)
                compressed.append(average)
            }
        }
        
        return compressed
    }
    
    private func playPreview() {
        guard let uploadedURL = uploadedURL,
              let url = URL(string: uploadedURL) else { return }
        
        Task {
            do {
                // Download and play the audio
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    do {
                        // Configure audio session for playback with Bluetooth support
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
                        try audioSession.setActive(true)
                        
                        self.audioPlayer = try AVAudioPlayer(data: data)
                        self.audioPlayer?.volume = 1.0
                        self.audioPlayer?.play()
                        
                        // Start playback tracking
                        self.isPlaying = true
                        self.playbackProgress = 0
                        self.playbackWaveformProgress = 0
                        
                        // Start timer to track playback progress
                        self.playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            self.updatePlaybackProgress()
                        }
                    } catch {
                        // Failed to play audio preview
                    }
                }
            } catch {
                // Failed to download audio for preview
            }
        }
    }
    
    private func updatePlaybackProgress() {
        guard let player = audioPlayer, player.isPlaying else {
            // Playback finished or stopped
            stopPlaybackTracking()
            return
        }
        
        playbackProgress = player.currentTime
        
        // Update waveform progress based on playback time and total duration
        if player.duration > 0 {
            let progressRatio = player.currentTime / player.duration
            playbackWaveformProgress = Int(progressRatio * Double(recordingWaveform.count))
        }
    }
    
    private func stopPlaybackTracking() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0
        playbackWaveformProgress = 0
    }
    
    private func publishRecording() {
        guard let recorder = audioRecorder,
              let uploadedURL = uploadedURL,
              let ndk = nostrManager.ndk else { return }
        
        let finalDuration = recordingDuration
        
        // Compress waveform to less than 100 values as recommended
        let compressedWaveform = compressWaveform(fullWaveform, targetSamples: 50)
        
        Task {
            do {
                // Create imeta tag with waveform and duration
                var imetaComponents = ["imeta"]
                imetaComponents.append("url \(uploadedURL)")
                imetaComponents.append("m audio/m4a")
                imetaComponents.append("duration \(Int(finalDuration))")
                
                // Add waveform data as space-separated values
                let waveformString = compressedWaveform
                    .map { String(format: "%.2f", $0) }
                    .joined(separator: " ")
                imetaComponents.append("waveform \(waveformString)")
                
                // Publish audio event
                _ = try await ndk.publish { builder in
                    let eventBuilder = builder
                        .kind(appState.replyingTo != nil ? 1244 : 1222) // Use 1244 for replies
                        .content(uploadedURL)
                        .tag(imetaComponents)
                    
                    // Add reply tags if replying
                    if let replyingTo = appState.replyingTo {
                        eventBuilder
                            .tag(["e", replyingTo.id, "", "reply"]) // Reply to original event
                            .tag(["p", replyingTo.author.pubkey]) // Mention original author
                    }
                    
                    return eventBuilder
                }
                
                await MainActor.run {
                    showingRecordingUI = false
                    recordingWaveform = []
                    fullWaveform = []
                    audioRecorder = nil
                    self.uploadedURL = nil
                    self.isShowingPreview = false
                    audioPlayer?.stop()
                    audioPlayer = nil
                    appState.replyingTo = nil  // Clear reply context after publishing
                    
                    // Clean up playback state
                    self.stopPlaybackTracking()
                }
                
                // Clean up local file
                try? FileManager.default.removeItem(at: recorder.url)
                
            } catch {
                print("Failed to publish audio event: \(error)")
                await MainActor.run {
                    showingRecordingUI = false
                    // TODO: Show error to user
                }
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nostrManager: NostrManager
    @Binding var selectedRelay: String?
    @Binding var showRelaySelector: Bool
    
    @State private var selectedRelayInfo: NDKRelayInformation?
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                // Relay icon if available
                if let icon = selectedRelayInfo?.icon,
                   let iconURL = URL(string: icon) {
                    AsyncImage(url: iconURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                
                // Title - Shows relay name or AMBULANDO
                Text(displayTitle)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.8))
            }
            .contentShape(Rectangle()) // Make entire area tappable
            .onTapGesture {
                showRelaySelector = true
            }
            
            Spacer()
            
            // Settings button
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .task {
            await loadRelayInfo()
        }
        .onChange(of: selectedRelay) { _, _ in
            Task {
                await loadRelayInfo()
            }
        }
    }
    
    private var displayTitle: String {
        if selectedRelay == nil {
            return "AMBULANDO"
        } else if let name = selectedRelayInfo?.name, !name.isEmpty {
            return name.uppercased()
        } else if let relay = selectedRelay {
            return formatRelayForDisplay(relay).uppercased()
        } else {
            return "AMBULANDO"
        }
    }
    
    private func loadRelayInfo() async {
        guard let selectedRelay = selectedRelay,
              let ndk = nostrManager.ndk else {
            selectedRelayInfo = nil
            return
        }
        
        // Find the relay in the pool
        let relays = await ndk.relays
        for relay in relays {
            if relay.url == selectedRelay {
                selectedRelayInfo = await relay.info
                break
            }
        }
    }
    
    private func formatRelayForDisplay(_ url: String) -> String {
        var formatted = url
        if formatted.hasPrefix("wss://") {
            formatted = String(formatted.dropFirst(6))
        } else if formatted.hasPrefix("ws://") {
            formatted = String(formatted.dropFirst(5))
        }
        if formatted.hasSuffix("/") {
            formatted = String(formatted.dropLast())
        }
        // Truncate long URLs
        if formatted.count > 20 {
            return String(formatted.prefix(17)) + "..."
        }
        return formatted
    }
}

// MARK: - Empty Feed View
struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.6),
                            Color.blue.opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("No voices yet")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Be the first to share your journey")
                    .font(.system(size: 16))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

// MARK: - Record Button
struct RecordButton: View {
    @Binding var isRecording: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    
    @State private var pulseScale: CGFloat = 1
    @State private var pulseOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // Pulse effect when recording
            if isRecording {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 92, height: 92)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
            }
            
            // Main button
            Button(action: {
                if isRecording {
                    onStopRecording()
                } else {
                    onStartRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isRecording ? Color.red : Color.purple,
                                    isRecording ? Color.red.opacity(0.8) : Color(red: 0.5, green: 0.1, blue: 0.9)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: isRecording ? Color.red.opacity(0.5) : Color.purple.opacity(0.5), 
                               radius: 15, x: 0, y: 5)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isRecording ? 1.1 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        }
        .onAppear {
            if isRecording {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                    pulseOpacity = 0
                }
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                    pulseOpacity = 0
                }
            } else {
                pulseScale = 1
                pulseOpacity = 0.5
            }
        }
    }
}

// MARK: - Recording Overlay
struct RecordingOverlay: View {
    let duration: TimeInterval
    let waveform: [CGFloat]
    let onCancel: () -> Void
    let onComplete: () -> Void
    let isUploading: Bool
    let uploadedURL: String?
    let onPreview: () -> Void
    let onPublish: () -> Void
    let isPlaying: Bool
    let playbackProgress: TimeInterval
    let playbackWaveformProgress: Int
    let replyingTo: AudioEvent?
    
    @State private var rotationAngle: Double = 0
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isRecordingComplete: Bool {
        !isUploading && uploadedURL == nil
    }
    
    var isPreviewReady: Bool {
        !isUploading && uploadedURL != nil
    }
    
    var formattedPlaybackProgress: String {
        let minutes = Int(playbackProgress) / 60
        let seconds = Int(playbackProgress) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack {
                // Reply context at the top
                if let replyingTo = replyingTo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replying to")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.6))
                        
                        HStack {
                            NDKProfilePicture(pubkey: replyingTo.author.pubkey, size: 32)
                            
                            VStack(alignment: .leading) {
                                Text(String(replyingTo.author.pubkey.prefix(8)))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Voice message")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<waveform.count, id: \.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        // Show different colors for played vs unplayed parts
                                        index < playbackWaveformProgress ? Color.green : Color.purple,
                                        index < playbackWaveformProgress ? Color.mint : Color.blue
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4, height: 20 + waveform[index] * 80)
                            .animation(.easeOut(duration: 0.1), value: waveform[index])
                            .animation(.easeInOut(duration: 0.2), value: playbackWaveformProgress)
                    }
                }
                .frame(height: 100)
                
                // Duration - show playback progress when playing, recording duration otherwise
                Text(isPlaying ? formattedPlaybackProgress : formattedDuration)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 30)
                
                Spacer()
            }
            
            // Bottom controls
            VStack {
                Spacer()
                HStack {
                    // Cancel button (bottom left)
                    Button(action: onCancel) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Preview button (when upload is complete)
                        if isPreviewReady {
                            Button(action: onPreview) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Main action button (right side)
                        Button(action: {
                            if isRecordingComplete {
                                onComplete()
                            } else if isPreviewReady {
                                onPublish()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.purple,
                                                Color(red: 0.5, green: 0.1, blue: 0.9)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Color.purple.opacity(0.5), radius: 15, x: 0, y: 5)
                                
                                if isUploading {
                                    // Upload animation
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                    
                                    Circle()
                                        .trim(from: 0, to: 0.3)
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                        .rotationEffect(Angle(degrees: rotationAngle))
                                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                                } else {
                                    Image(systemName: isPreviewReady ? "paperplane.fill" : "checkmark")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isUploading)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if isUploading {
                rotationAngle = 360
            }
        }
        .onChange(of: isUploading) { _, newValue in
            if newValue {
                rotationAngle = 360
            } else {
                rotationAngle = 0
            }
        }
    }
}
