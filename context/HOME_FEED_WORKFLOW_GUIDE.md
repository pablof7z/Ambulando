Of course. Here is a comprehensive technical documentation for the **Home Feed & Recording Workflow** module, located at `Sources/Ambulando/Views/HomeFeedView.swift`.

---

## Technical Documentation: HomeFeedView Module

### 1. Module Overview

#### Purpose and Responsibilities

The `HomeFeedView` is the central user interface of the Ambulando application. It serves two primary functions:

1.  **Content Consumption:** It displays a dynamic, real-time feed of audio events from the Nostr network. Users can scroll, refresh, and filter this feed by specific relays.
2.  **Content Creation:** It manages the entire workflow for creating and publishing new audio content. This is a complex, multi-stage process that includes audio recording, file uploading to a Blossom server, previewing the recording, and finally publishing the corresponding event to the Nostr network.

The module is responsible for orchestrating interactions between the user, the underlying Nostr protocol via `NDKSwift`, the device's audio hardware via `AVFoundation`, and external storage services (Blossom).

#### Key Interfaces and Entry Points

*   **`HomeFeedView` (struct):** The main SwiftUI `View` that constitutes the module. It's the primary entry point.
*   **User Interactions:**
    *   **Record Button:** A floating button that initiates the audio recording sequence.
    *   **Pull-to-Refresh:** Triggers a refresh of the audio event feed.
    *   **Relay Selector:** A UI element in the header that allows users to filter the feed to a single relay.
    *   **Reply Action:** While the button is in `AudioEventCard`, the logic to handle a reply (initiating a recording session with context) is managed within `HomeFeedView` by observing `appState.replyingTo`.

#### Dependencies and Relationships

*   **`NostrManager` (@EnvironmentObject):** Provides access to the configured `NDK` instance, which is essential for all Nostr-related operations (fetching events, publishing, accessing user session data).
*   **`AppState` (@EnvironmentObject):** A shared state manager used to communicate global app state. `HomeFeedView` uses it to manage the recording state (`isRecording`), the identity of the currently playing audio (`currentlyPlayingId`), and the context for a reply (`replyingTo`).
*   **`AVFoundation` (Framework):** Used directly for low-level audio operations, specifically `AVAudioRecorder` for capturing audio and `AVAudioPlayer` for previewing recordings.
*   **`AudioEventCard` (View):** A child view rendered for each item in the feed. It can initiate a reply by updating the `appState`, which this module listens to.
*   **`RelaySelectorView` (View):** A modal child view used to select a relay for filtering the feed. The selection is communicated back via a `@Binding`.

### 2. Technical Architecture

#### Internal Structure and Organization

The `HomeFeedView` is built around a `ZStack` to facilitate the layering of its different UI states:

1.  **Base Layer (`VStack`):** Contains the main feed UI, including the `HeaderView` and the `ScrollView` of `AudioEventCard`s. This is always visible unless fully obscured.
2.  **Recording Overlay Layer (`RecordingOverlay`):** A modal-like view that appears on top of the feed when a recording is in progress. This view itself contains multiple sub-states (recording, uploading, previewing).
3.  **Record Button Layer:** A floating action button for initiating a recording. It is hidden when the `RecordingOverlay` is visible.
4.  **Relay Selector Layer (`RelaySelectorView`):** A modal view for filtering the feed, displayed on top of everything else when active.

State is managed through a combination of `@State` for local UI properties and `@EnvironmentObject` for global, cross-component state.

#### Key Classes/Functions and Their Roles

| Component/Function           | Role                                                                                                                                                                                            |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `HomeFeedView` (struct)      | The main container view responsible for orchestrating all subviews and state transitions.                                                                                                         |
| `startStreamingAudioEvents()` | Initializes and manages the data stream from `NDKSwift`. It creates the appropriate Nostr filter, handles relay selection logic, and processes incoming events into `AudioEvent` models.        |
| `refreshAudioEvents()`       | Implements the pull-to-refresh logic by clearing the current event list and re-initiating the data stream.                                                                                        |
| `startRecording()`           | Kicks off the recording workflow. It requests permissions, sets up the `AVAudioRecorder`, and transitions the UI to the recording state by showing the `RecordingOverlay`.                           |
| `updateRecording()`          | Fired by a `Timer` during recording. It updates the UI with the current duration and samples the microphone's peak power to generate a live waveform visualization. It also enforces the 60s limit. |
| `completeRecording()`        | This function acts as the bridge between recording and uploading. It stops the recorder and initiates the asynchronous upload task to a Blossom server.                                            |
| `publishRecording()`         | The final step. It constructs and publishes the Nostr event (Kind 1222 or 1244) with the `uploadedURL` and a compressed waveform in an `imeta` tag.                                                |
| `RecordingOverlay` (View)    | A critical sub-view that acts as a state machine, presenting a different UI for each stage of the content creation flow: active recording, uploading, and preview/publish.                        |
| `HeaderView` (View)          | The top navigation bar of the feed, displaying the app title or selected relay and providing access to settings and the relay selector.                                                             |

#### Data Flow

The module has two primary data flows:

1.  **Feed Consumption (Inbound):**
    `NDKSwift` → `dataSourceTask` → `audioEvents: [AudioEvent]` → `sortedEvents` → `ScrollView` of `AudioEventCard`s.
    Events are streamed from relays, processed into a local `AudioEvent` model (including a `webOfTrustScore`), stored in the `@State` variable `audioEvents`, sorted, and then rendered.

2.  **Content Creation (Outbound):**
    `User Tap` → `startRecording()` → `AVAudioRecorder` writes to a local file → `completeRecording()` reads the file data → Uploads to Blossom Server → `uploadedURL` state is set → `publishRecording()` → `NDKSwift.publish()` sends event to relays.
    This is a linear, multi-stage flow where the output of one step becomes the input for the next, with the UI (`RecordingOverlay`) updating at each stage.

### 3. Implementation Details

#### Core Algorithms or Business Logic

*   **Feed Sorting:** The feed is not purely chronological. `sortedEvents` computes a `sortScore` for each `AudioEvent`: `(webOfTrustScore * 0.7) + (recencyScore * 0.3)`. This prioritizes content from users closer in the social graph while still valuing freshness.
*   **Live Waveform Generation:** The `updateRecording()` function generates the live waveform. Instead of using average power, it uses `recorder.peakPower(forChannel: 0)` which provides a more dynamic and visually appealing representation of the user's voice. The decibel value is converted to a normalized linear scale (0-1) for UI rendering.
*   **Waveform Compression:** For publishing, the `fullWaveform` (a high-resolution array of amplitude values) is passed to `compressWaveform()`. This function uses a simple bucketing and averaging algorithm to reduce the number of samples to a target of 50, which is a practical limit for including in a Nostr event tag.
*   **Relay-Specific Filtering:** When a single relay is selected, the `startStreamingAudioEvents` function changes the `cachePolicy` to `.networkOnly` and sets the `exclusiveRelays` flag. This is a crucial decision to ensure that when a user selects "Relay X", they *only* see events from that specific relay, bypassing the aggregated local cache.

#### Important Patterns or Design Decisions

*   **State-Driven UI:** The entire recording workflow is managed by a set of `@State` and `@EnvironmentObject` properties (`showingRecordingUI`, `isUploading`, `uploadedURL`). The `RecordingOverlay` view uses these states to conditionally render the correct UI and controls for each stage, creating a robust state machine.
*   **Modal Workflow for Recording:** The recording process takes place in a modal overlay that prevents the user from interacting with the main feed. This is a deliberate design choice to simplify state management and guide the user through the linear creation process without interruption.
*   **Decoupled Reply Mechanism:** The reply action is initiated in `AudioEventCard`, but the logic is handled in `HomeFeedView`. This is achieved by having the card update a shared `appState.replyingTo` property. `HomeFeedView` uses `.onChange(of: appState.replyingTo)` to detect this change and automatically trigger the recording workflow in a "reply" context. This decouples the components effectively.
*   **Asynchronous Task Management:** The `dataSourceTask` is carefully managed. It's stored as a `@State` property, allowing it to be cancelled (`.onDisappear`) and restarted (e.g., when the selected relay changes) to prevent memory leaks or multiple conflicting data streams.

#### Configuration and Customization

*   **Recording Limit:** The maximum recording duration is hardcoded to 60 seconds inside `updateRecording()`.
*   **Blossom Server:** The server for uploads is currently hardcoded to `https://blossom.primal.net`. The code structure in `completeRecording` with a `for server in servers` loop indicates a design intention for this to be configurable in the future.
*   **Nostr Event Kinds:** The module uses Kind `1222` for original audio posts and Kind `1244` for replies, a distinction made during the `publishRecording` step.

### 4. Integration Points

*   **`NostrManager` / `NDKSwift`:** This is the most critical integration. `HomeFeedView` relies on `nostrManager.ndk` to:
    *   Observe events for the feed (`ndk.observe`).
    *   Publish new events (`ndk.publish`).
    *   Access the current user's session data for context (`ndk.sessionData`), like the mute list and Web of Trust scores.
    *   Access the current signer for authenticating Blossom uploads (`ndk.signer`).
*   **`AppState`:**
    *   **Writes to `AppState`:** Sets `isRecording` and `recordingStartTime`.
    *   **Reads from `AppState`:** Checks `replyingTo` to determine if a new recording is a reply. It also reads `currentlyPlayingId` to coordinate audio playback across `AudioEventCard`s.
*   **`BlossomClient` / Blossom Network:**
    *   Although `BlossomClient` is not defined in this file, the logic within `completeRecording` shows the direct integration.
    *   It prepares audio `Data` and a `mimeType`.
    *   It calls an `uploadWithAuth` method, passing the data and the current `NDKSigner` to generate the necessary `Authorization` header for the Blossom server.
*   **`AudioEventCard`:**
    *   Receives `AudioEvent` data from `HomeFeedView`.
    *   Communicates back to `HomeFeedView` by updating `appState.replyingTo` when the user taps reply.

### 5. Usage Guide

#### How to Properly Use This Module

`HomeFeedView` is designed to be the primary view for authenticated users. It should be placed inside a `NavigationView` and have `NostrManager` and `AppState` provided as environment objects.

**Example Integration:**
```swift
// In a parent view like ContentView.swift
struct ContentView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        // ... authentication check
        if appState.isAuthenticated {
            NavigationView {
                HomeFeedView()
            }
            // Provide the NDK instance to the environment for child views
            .environment(\.ndk, nostrManager.ndk)
        } else {
            AuthenticationView()
        }
        // ...
    }
}
```

#### Common Patterns and Best Practices

*   **Initiating a Reply:** To programmatically start a recording as a reply to a specific event, set the `appState.replyingTo` property to the target `AudioEvent`. `HomeFeedView` will automatically detect this change and launch the recording UI with the correct context.

    ```swift
    // From another view, e.g., AudioEventCard
    appState.replyingTo = self.audioEvent
    ```

*   **Handling Data Flow:** The module is designed to handle a continuous stream of events. The `dataSourceTask` automatically manages fetching and updating the UI. To force a full refresh, call `refreshAudioEvents()`, which is already implemented for the pull-to-refresh action.

*   **State Management:** The recording workflow is self-contained within the `RecordingOverlay`. Avoid manipulating its internal state flags (like `isUploading`) from outside the module. The designed entry points are the record button and the `appState.replyingTo` property.