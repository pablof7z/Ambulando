Of course. Here is a comprehensive inventory of the Ambulando codebase.

### Codebase Inventory: Ambulando

---

### 1. Project Overview

Ambulando is a voice-first, decentralized social media application built on the Nostr protocol. Its core purpose is to foster intimate and thoughtful connections through 60-second voice posts. The project philosophy, as outlined in `context/PROJECT.md`, is a direct response to the noise and performativity of mainstream social media, aiming to create an experience of a calm, walking conversation with a friend. The feed is intentionally not chronological, prioritizing a "Web of Trust" score (70%) over recency (30%) to encourage a "slow social" experience.

-   **Main Technologies**:
    -   **UI**: Swift, SwiftUI
    -   **Protocol & Networking**: Nostr via `NDKSwift`, `AVFoundation` for audio, `URLSession` for network requests.
    -   **Project Generation**: XcodeGen is used to generate the `.xcodeproj` from a `project.yml` file, making project settings version-controllable.
    -   **Dependencies**: Swift Package Manager manages dependencies, including `NDKSwift` and its UI components (`NDKSwiftUI`).
-   **Architecture Style**:
    -   The application uses a modern **MVVM (Model-View-ViewModel)** architecture, which is idiomatic for SwiftUI.
    -   Global state is managed through `@EnvironmentObject`s: `NostrManager` (for all Nostr logic and session data) and `AppState` (for transient UI state like recording status).
    -   Local view state is handled with `@State` and `@StateObject`.
    -   Data flow is reactive, using Swift's `async/await` and `AsyncStream` (via `NDKSwift`) for live updates from the Nostr network.

---

### 2. Directory Structure

The repository is organized into a clean, modern iOS project structure that promotes a clear separation of concerns.

| Path                          | Purpose                                                                                                                                                                                                                           |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/workflows/`          | Contains GitHub Actions workflows for Continuous Integration (`ci.yml`) and TestFlight deployment (`testflight.yml`).                                                                                                               |
| `context/`                    | Project documentation, including the core project specification (`PROJECT.md`), technical guides for complex workflows like Authentication and the Home Feed, and this inventory file. `PROJECT.md` is a new and vital document.      |
| `Sources/Ambulando/`          | The main application source code, structured by feature and MVVM component type.                                                                                                                                                    |
| `┣━ Models/`                  | Core data models like `AudioEvent`, `BlossomError`, and `OutboxDebugModels`. These are simple Swift structs representing application data.                                                                                         |
| `┣━ Networking/`              | Networking utilities, notably a `URLSession` extension to configure a custom User-Agent, a best practice for identifying the client to external APIs.                                                                             |
| `┣━ Shapes/`                  | Custom SwiftUI `Shape` definitions, such as the `FootprintShape` used for branding.                                                                                                                                               |
| `┣━ ViewModels/`              | ViewModels that hold presentation logic for complex views. For example, `OutboxDebugViewModel` manages the state for the outbox debugging screen.                                                                                   |
| `┣━ Views/`                   | All SwiftUI views, organized into subdirectories by feature.                                                                                                                                                                      |
| `┃  ┗━ Debug/`                | A comprehensive suite of debug views for inspecting internal app state like caching (`CacheDebugView`), active subscriptions, and the Nostr outbox model. This is critical for developing on a decentralized protocol.                 |
| **(Root Directory)**          | **Configuration & Scripts**                                                                                                                                                                                                       |
| `┣━ project.yml`              | The XcodeGen spec file. This is the source of truth for the Xcode project's structure, targets, dependencies, and build settings.                                                                                                  |
| `┣━ refresh-project.sh`        | A utility script to run `xcodegen generate`, ensuring the Xcode project is always in sync with the file system and `project.yml`.                                                                                                 |
| `┣━ build.sh` & `deploy.sh`   | Scripts to automate the build and TestFlight deployment processes, essential for CI/CD and consistent local builds.                                                                                                                 |
| `┣━ ExportOptions-TestFlight.plist` | An Apple-specific configuration file that defines how to export an archived app for TestFlight distribution.                                                                                                                  |
| `┣━ .gitignore`               | Standard Git ignore file for Xcode projects, keeping the repository clean of build artifacts and user-specific files.                                                                                                             |

---

### 3. Significant Files

These files are central to the application's functionality, architecture, and configuration.

| File Path                               | Description                                                                                                                                                                                                |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`context/PROJECT.md`** (untracked)    | **The project's constitution.** Defines the core philosophy, target audience, feature set, and non-goals. It is the guiding document for all development.                                                       |
| `Sources/Ambulando/AmbulandoApp.swift`  | The main entry point of the app. Initializes and injects the core `NostrManager` and `AppState` environment objects into the view hierarchy.                                                                   |
| `Sources/Ambulando/ContentView.swift`   | The root view that acts as a router. It checks the authentication state and directs the user to either `AuthenticationView` or `HomeFeedView`.                                                                  |
| `Sources/Ambulando/Views/HomeFeedView.swift` | The application's core screen. It displays the audio feed and orchestrates the entire audio recording, uploading (to Blossom), and publishing workflow.                                                        |
| `Sources/Ambulando/Views/AuthenticationView.swift` | Manages the complex user login process, supporting multiple Nostr authentication methods like `nsec` (private key) and `NIP-46` (remote signing).                                                            |
| **`Sources/Ambulando/Views/SettingsView.swift`** (modified) | **The main user settings hub.** Provides navigation to Relays, Blossom Servers, Muted Users, and Debug Tools. It also displays account info and handles the sign-out process.                    |
| `Sources/Ambulando/Views/AudioEventCard.swift` | A complex, self-contained view for a single audio post. It manages its own audio playback, fetches and displays reactions, and handles user interactions like replying.                                      |
| `AmbulandoApp.swift` > `NostrManager`   | The central orchestrator for all Nostr protocol interactions. It configures and wraps `NDKSwift`, manages the user session, and handles relay connections.                                                         |
| `AmbulandoApp.swift` > `AppState`       | A global `ObservableObject` for shared UI state that doesn't belong in the Nostr manager, such as `isRecording`, `currentlyPlayingId`, and reply context.                                                          |
| `project.yml`                           | The canonical definition of the Xcode project. It specifies targets, dependencies, build settings, and file structure, avoiding `.xcodeproj` merge conflicts.                                                    |

---

### 4. Architectural Insights

-   **State Management**: The app uses a clear, layered state management strategy.
    -   **Persistent/Global State**: `NostrManager` is the source of truth for all Nostr-related data (user session, relays, events). It's a long-lived object provided via `@EnvironmentObject`.
    -   **Transient UI State**: `AppState` manages UI state that needs to be shared across different views (e.g., the context for a reply, which `AudioEventCard` sets and `HomeFeedView` consumes).
    -   **Local View State**: Standard SwiftUI `@State` and `@StateObject` are used for state confined to a single view.

-   **Data Flow**:
    -   **Inbound**: Data flow is reactive and asynchronous. `NostrManager` uses `NDKSwift`'s `observe` function to create `AsyncStream`s of events from relays. Views subscribe to `@Published` properties on the manager, which are updated from these streams, causing the UI to update automatically.
    -   **Outbound**: User actions (e.g., publishing a voice note) call methods on `NostrManager`, which then uses `NDKSwift` to construct and publish events to the appropriate Nostr relays.

-   **Key Design Decisions**:
    -   **Decoupled Project Definition**: Using `xcodegen` (`project.yml`) makes the project's structure transparent, version-controllable, and less prone to merge conflicts compared to a binary `.xcodeproj` file.
    -   **Modular, Reusable Components**: The architecture leverages libraries like `NDKSwiftUI` for components like `NDKUIProfilePicture` and `QRScannerView`, reducing redundant code.
    -   **Comprehensive Debug Suite**: The `Views/Debug/` directory is an intentional and significant feature. For a decentralized app with complex state, built-in tools to inspect caches, relay subscriptions, and outbox models are crucial for development and troubleshooting.
    -   **Explicit Context Documentation**: The presence of `AUTHENTICATION_FLOW_GUIDE.md` and `HOME_FEED_WORKFLOW_GUIDE.md` indicates a commitment to documenting complex, high-stakes areas of the code, onboarding developers more quickly.

---

### 5. High-Complexity Modules

The codebase contains a few modules with significant business logic, state management, and interaction with external frameworks, making them more complex than others.

1.  **Home Feed & Recording Workflow**
    -   **File Path**: `Sources/Ambulando/Views/HomeFeedView.swift`
    -   **Reason for Complexity**: This view is the app's centerpiece and juggles multiple, overlapping responsibilities. It manages a live-streaming, custom-sorted feed; the entire `AVFoundation` audio recording lifecycle (permissions, metering, timers); an asynchronous upload process to an external Blossom server (which requires Nostr-signed authentication); a preview playback state; and the final construction and publishing of a formatted Nostr event. This coordination of network, hardware, and UI state is highly complex.

2.  **Authentication Flow**
    -   **File Path**: `Sources/Ambulando/Views/AuthenticationView.swift`
    -   **Reason for Complexity**: This module is responsible for handling multiple, distinct Nostr authentication schemes, each with its own asynchronous flow. The `nsec` (private key) method is straightforward, but the `NIP-46` (Nostr Connect) flow is far more complex. It requires initiating a connection to a remote signer (e.g., another app or hardware device) via a "bunker", potentially receiving and displaying an auth URL to the user, and concurrently waiting for external approval before completing the login. The view also has intricate, state-driven animations, adding to its complexity.

---