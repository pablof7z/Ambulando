Of course. Here is the comprehensive technical documentation for the **Home Feed & Recording Workflow** module, `Sources/Ambulando/Views/HomeFeedView.swift`.

---

## Technical Documentation: HomeFeedView Module

### 1. Module Overview

#### 1.1. Purpose and Responsibilities

The `HomeFeedView` is the central user interface of the Ambulando application, displayed immediately after successful authentication. It serves two primary, complex functions:

1.  **Content Consumption:** It presents a dynamic, real-time feed of audio events from the Nostr network. This feed is uniquely sorted by a Web of Trust algorithm, not just chronologically. Users can scroll, refresh, and filter this feed to view content from specific relays.
2.  **Content Creation:** It orchestrates the entire workflow for creating and publishing new audio content. This is a multi-stage process involving audio recording via `AVFoundation`, asynchronous file uploading to a Blossom server, previewing the recording, and finally, publishing the corresponding Nostr event.

The module acts as a high-level controller, managing interactions between the user, the underlying Nostr protocol (via `NostrManager`), the device's audio hardware (`AVFoundation`), and external storage services (Blossom).

#### 1.2. Key Interfaces and Entry Points

*   **View:** `HomeFeedView()` - The primary SwiftUI `View` struct.
*   **Dependencies (Injected via `@EnvironmentObject`):**
    *   `NostrManager`: The service layer for all Nostr operations. Used for fetching events, publishing, and accessing the user's session data (e.g., mute lists, Web of Trust scores).
    *   `AppState`: A shared, app-wide state object. Used to communicate global state like the current recording status (`isRecording`), the identity of the currently playing audio (`currentlyPlayingId`), and the context for a reply (`replyingTo`).
*   **User Interaction Entry Points:**
    *   **Record Button:** A floating button that initiates the audio recording sequence.
    *   **Pull-to-Refresh:** Triggers a refresh of the audio event feed by calling `refreshAudioEvents()`.
    *   **Relay Selector:** A UI element in the header that allows users to filter the feed to a single relay, updating the `@State private var selectedRelay` property.
    *   **Reply Action:** Initiated from a child view (`AudioEventCard`), which updates `appState.replyingTo`. `HomeFeedView` observes this change and triggers the recording workflow with the appropriate context.

#### 1.3. Dependencies and Relationships

*   **`NostrManager` & `AppState`:** The core architectural bridge to the rest of the application, providing services and shared state.
*   **`AVFoundation`:** The Apple framework used directly for low-level audio operations, specifically `AVAudioRecorder` for capturing audio and `AVAudioPlayer` for previewing recordings.
*   **`AudioEventCard`:** A child view rendered for each item in the feed. It is responsible for its own display and playback logic but communicates the user's intent to reply back to `HomeFeedView` by modifying `AppState`.
*   **`RelaySelectorView`:** A modal child view for selecting a relay. The selection is communicated back via a `@Binding` to the `selectedRelay` state variable.
*   **`RecordingOverlay`:** A private, nested sub-view that encapsulates the entire UI for the recording, uploading, and publishing workflow.

---

### 2. Technical Architecture

#### 2.1. Internal Structure and Organization

The `HomeFeedView` is built around a `ZStack` to facilitate the layering of its different UI states, ensuring a clean separation of concerns:

1.  **Base Layer (`VStack`):** Contains the main feed UI, including the `HeaderView` and the `ScrollView` that renders the list of `AudioEventCard`s. This is always visible unless fully obscured.
2.  **Recording Overlay Layer (`RecordingOverlay`):** A modal-like view presented on top of the feed when a recording is in progress or being prepared for publishing. This view is a state machine itself, showing different UIs for recording, uploading, and previewing.
3.  **Record Button Layer:** A floating action button (`RecordButton`) for initiating a recording. It is conditionally hidden when the `RecordingOverlay` is visible to prevent conflicting user actions.
4.  **Relay Selector Layer (`RelaySelectorView`):** A modal view for filtering the feed, presented on top of all other content when active.

State is managed through a combination of `@State` for local UI properties (e.g., `audioEvents`, `showingRecordingUI`) and `@EnvironmentObject` for global, cross-component state (`appState`, `nostrManager`).

#### 2.2. Key Classes/Functions and Their Roles

| Component/Function            | Role                                                                                                                                                                                                                                           |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `HomeFeedView` (struct)       | The main container view responsible for orchestrating all subviews, managing the primary data tasks, and handling state transitions.                                                                                                            |
| `startStreamingAudioEvents()` | Initializes and manages the data stream from `NDKSwift`. It constructs the Nostr filter, handles relay selection logic (including bypassing the cache for single-relay views), and processes incoming events into `AudioEvent` models.        |
| `refreshAudioEvents()`        | Implements the pull-to-refresh logic by clearing the current event list (`audioEvents`) and calling `startStreamingAudioEvents()` to re-initiate the data stream.                                                                                 |
| `startRecording()`            | Kicks off the recording workflow. It requests microphone permissions, sets up the `AVAudioRecorder` with the correct settings, and transitions the UI to the recording state by setting `showingRecordingUI = true`.                             |
| `updateRecording()`           | Fired by a `Timer` during recording. It updates the UI with the elapsed duration and samples the microphone's `peakPower(forChannel:)` to generate a live waveform visualization. It also enforces the 60-second recording limit.                |
| `completeRecording()`         | Acts as the bridge between recording and uploading. It stops the `AVAudioRecorder` and initiates an asynchronous task to read the recorded file data and upload it to a Blossom server. It manages the `isUploading` state.                 |
| `publishRecording()`          | The final step in content creation. It constructs the Nostr event (Kind 1222 for original posts or 1244 for replies), including the `uploadedURL` and a compressed waveform in an `imeta` tag, and publishes it via `NostrManager`.       |
| `RecordingOverlay` (View)     | A critical sub-view that acts as a state machine. It uses state variables (`isUploading`, `uploadedURL`) to present the correct UI for each stage of the content creation flow: active recording, uploading, and preview/publish.               |
| `HeaderView` (View)           | The top navigation bar of the feed. It displays the app title or selected relay name and provides access to the settings screen and the relay selector modal.                                                                               |

#### 2.3. Data Flow

The module has two primary, distinct data flows:

1.  **Feed Consumption (Inbound):**
    `NDKSwift` → `dataSourceTask` → `audioEvents: [AudioEvent]` → `sortedEvents` (computed) → `ScrollView` of `AudioEventCard`s.
    Events are streamed from relays, hydrated into a local `AudioEvent` model (which includes a pre-computed `webOfTrustScore`), stored in the `@State` variable `audioEvents`, sorted on-the-fly by the `sortedEvents` computed property, and then rendered.

2.  **Content Creation (Outbound):**
    `User Tap` → `startRecording()` → `AVAudioRecorder` writes to local file → `completeRecording()` reads file data → Uploads to Blossom Server → `uploadedURL` state is set → `publishRecording()` → `NDKSwift.publish()` sends event to relays.
    This is a linear, multi-stage flow where the output of one step is the input for the next. The UI, encapsulated in the `RecordingOverlay`, updates reactively at each stage based on state variables like `isUploading` and `uploadedURL`.

---

### 3. Implementation Details

#### 3.1. Core Algorithms or Business Logic

*   **Feed Sorting:** The feed is not chronological. The `sortedEvents` computed property leverages the `sortScore` from the `AudioEvent` model, which calculates a weighted score: `(webOfTrustScore * 0.7) + (recencyScore * 0.3)`. This algorithm is central to the app's philosophy, prioritizing content from users closer in the social graph while still valuing freshness.
*   **Live Waveform Generation:** During recording, `updateRecording()` generates the live waveform. It uses `recorder.peakPower(forChannel: 0)`, which provides a more dynamic and visually appealing representation of the user's voice intensity compared to average power. The raw decibel value is clamped and converted to a normalized linear scale (0-1) for UI rendering.
*   **Waveform Compression:** Before publishing, the `fullWaveform` (a high-resolution array of amplitude values) is passed to `compressWaveform()`. This function implements a bucketing and averaging algorithm to reduce the number of samples to a target of 50. This is a practical compromise to keep the data small enough to be included in a Nostr event's `imeta` tag without significant overhead.
*   **Relay-Specific Filtering:** When a single relay is selected, `startStreamingAudioEvents()` makes a critical architectural decision: it changes the `cachePolicy` to `.networkOnly` and sets the `exclusiveRelays` flag. This ensures that when a user selects "Relay X," they see *only* events streamed directly from that relay in real-time, bypassing the aggregated local cache which does not store relay-of-origin information.

#### 3.2. Important Patterns or Design Decisions

*   **State-Driven UI Machine:** The entire recording workflow is managed by a set of `@State` and `@EnvironmentObject` properties (`showingRecordingUI`, `isUploading`, `uploadedURL`). The `RecordingOverlay` view uses these states to conditionally render the correct UI and controls for each stage, creating a robust and predictable state machine.
*   **Modal Recording Workflow:** The recording, preview, and publishing process takes place in a full-screen modal overlay. This is a deliberate design choice to simplify state management and guide the user through a linear creation process without the distraction of or interaction with the main feed.
*   **Decoupled Reply Mechanism:** The reply action is initiated in `AudioEventCard`, but the logic is handled in `HomeFeedView`. This is achieved by having the card update a shared `appState.replyingTo` property. `HomeFeedView` uses an `.onChange(of: appState.replyingTo)` modifier to detect this change and automatically trigger the recording workflow in a "reply" context. This effectively decouples the components while enabling communication.
*   **Asynchronous Task Management:** The `dataSourceTask` that streams feed data is stored as a `@State` property. This allows it to be explicitly managed: it is cancelled in `.onDisappear` and restarted when the selected relay changes. This prevents memory leaks and avoids multiple, conflicting data streams from running simultaneously.

#### 3.3. Configuration and Customization

*   **Recording Limit:** The maximum recording duration is hardcoded to 60 seconds inside `updateRecording()`.
*   **Blossom Server:** The server for uploads is currently hardcoded to `https://blossom.primal.net`. The code structure in `completeRecording` with a `for server in servers` loop indicates a design intention for this to be user-configurable in the future via `BlossomSettingsView`.
*   **Nostr Event Kinds:** The module correctly distinguishes between original posts and replies during `publishRecording`, using Kind `1222` for the former and Kind `1244` for the latter.

---

### 4. Integration Points

*   **`NostrManager` / `NDKSwift`:** This is the most critical integration. `HomeFeedView` relies on `nostrManager.ndk` to:
    *   Observe events for the feed (`ndk.observe`).
    *   Publish new audio events (`ndk.publish`).
    *   Access the current user's session data (`ndk.sessionData`) for context like the mute list and Web of Trust scores.
    *   Access the current `NDKSigner` for authenticating Blossom uploads (`ndk.signer`).
*   **`AppState`:**
    *   **Writes to `AppState`:** Sets `isRecording` and `recordingStartTime` to signal the start of a recording session.
    *   **Reads from `AppState`:** Checks `replyingTo` to determine if a new recording is a reply. It also reads `currentlyPlayingId` to coordinate audio playback and ensure only one `AudioEventCard` plays at a time.
*   **Blossom Network (`BlossomClient`):**
    *   The `completeRecording` function implements the client-side logic for interacting with Blossom servers.
    *   It prepares audio `Data` and a `mimeType`.
    *   It calls an `uploadWithAuth` method (conceptually part of a `BlossomClient`), passing the data and the current `NDKSigner` to generate the necessary `Authorization` header required by the Blossom protocol.
*   **`AudioEventCard`:**
    *   Receives `AudioEvent` data models from `HomeFeedView`.
    *   Communicates back to `HomeFeedView` by updating `appState.replyingTo` when the user taps the reply button, initiating the reply workflow.

---

### 5. Usage Guide

#### 5.1. How to Properly Use This Module

`HomeFeedView` is designed to be the primary view for authenticated users. It should be placed inside a `NavigationView` to enable navigation to settings and other screens. It requires both `NostrManager` and `AppState` to be provided as environment objects.

**Example Integration (from `ContentView.swift`):**
```swift
struct ContentView: View {
    @EnvironmentObject var nostrManager: NostrManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        // ... authentication check
        if isAuth { // Assuming `isAuth` is derived from AppState or NostrManager
            NavigationView {
                HomeFeedView()
            }
            .environment(\.ndk, nostrManager.ndk)
        } else {
            AuthenticationView()
        }
    }
}
```

#### 5.2. Common Patterns and Best Practices

*   **Initiating a Reply Programmatically:** To start a recording session as a reply to a specific event from any other view, set the `appState.replyingTo` property to the target `AudioEvent`. `HomeFeedView` will automatically detect this change and launch the `RecordingOverlay` with the correct reply context.

    ```swift
    // From another view, e.g., AudioEventCard.swift
    appState.replyingTo = self.audioEvent
    ```

*   **Handling Data Flow:** The module is designed to handle a continuous stream of events via its `dataSourceTask`. To force a full refresh (e.g., after changing follow lists), call `refreshAudioEvents()`, which is already implemented for the standard pull-to-refresh user action.

*   **State Management:** The recording workflow is self-contained within `HomeFeedView` and its private `RecordingOverlay`. Avoid manipulating its internal state flags (like `isUploading`) from outside the module. The designed entry points are the main record button and the `appState.replyingTo` property.