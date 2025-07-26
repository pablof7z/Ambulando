# Ambulando - Voice-First Social Network

<div align="center">
  <img src="Resources/ambulando-icon.png" alt="Ambulando Logo" width="200"/>
  
  [![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
  [![NDKSwift](https://img.shields.io/badge/NDKSwift-0.2.0-blue)](https://github.com/pablof7z/NDKSwift)
  [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
</div>

## Overview

Ambulando reimagines social media through the power of voice. Built on the [Nostr protocol](https://nostr.com), it creates an intimate, authentic space where people share wisdom, thoughts, and conversations through 60-second voice messages. The name "Ambulando" (Latin for "by walking") reflects our philosophy: thoughtful conversations that flow naturally, like talking while walking together.

## Philosophy

In a world of endless text posts and visual noise, Ambulando brings back the human element of communication. Voice carries emotion, nuance, and personality that text cannot convey. By limiting messages to 60 seconds, we encourage thoughtful, concise expression rather than endless scrolling.

## Features

### 🎙️ Voice Messaging
- **60-Second Posts**: Share your thoughts in up to 60 seconds of audio
- **Visual Waveforms**: Beautiful waveform visualizations during recording and playback
- **Voice Replies**: Respond to others with your own voice messages
- **Rich Metadata**: Automatic waveform generation and duration tracking

### 🌐 Web of Trust Discovery
- **Smart Feed Algorithm**: Content prioritized by social graph proximity (70%) and recency (30%)
- **Trust-Based Sorting**: Posts from your network appear first
- **Time Decay**: Fresh content naturally rises to the top
- **Mute Controls**: Filter unwanted content seamlessly

### 💾 Decentralized Storage (Blossom)
- **Multi-Server Redundancy**: Audio files stored across multiple servers
- **Server Discovery**: Find public Blossom servers via Nostr events
- **Custom Servers**: Add your own preferred storage servers
- **Published Preferences**: Your server list shared via Kind 10063 events

### 👥 Social Features
- **Emoji Reactions**: Express yourself with Nostr Kind 7 reactions
- **Hashtag Support**: Automatic hashtag extraction and display
- **User Profiles**: View profiles with NIP-05 verification
- **Follow System**: Build your trusted network
- **Reply Threading**: See conversation flows naturally

### 🔐 Advanced Nostr Integration
- **Flexible Authentication**:
  - Direct nsec (private key) login
  - NIP-46 Nostr Connect via bunker://
  - NIP-05 identity resolution
- **Relay Management**:
  - Add/remove custom relays
  - Real-time connection monitoring
  - Detailed relay statistics
  - Per-relay content filtering
- **Negentropy Sync**: Efficient follow list synchronization

### 🛠️ Developer Features
- **Debug Menu**:
  - Outbox configuration viewer
  - Relay connection inspector
  - Real-time message statistics
  - Network health monitoring
- **Event Types**:
  - Kind 1222: Original voice posts
  - Kind 1244: Voice replies

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/pablof7z/Ambulando.git
cd Ambulando
```

2. Install XcodeGen if you haven't already:
```bash
brew install xcodegen
```

3. Generate the Xcode project:
```bash
./refresh-project.sh
```

4. Open the project in Xcode:
```bash
open Ambulando.xcodeproj
```

5. Build and run the project on your device or simulator

### TestFlight

Coming soon! We'll be releasing Ambulando on TestFlight for beta testing.

## Development

### Building

```bash
# Refresh project after file changes
./refresh-project.sh

# Build with clean output
./build.sh

# Build for specific device
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro" ./build.sh
```

### Deploying to TestFlight

```bash
./deploy.sh
```

## Architecture

Ambulando is built with modern iOS technologies:

- **SwiftUI** for declarative, animated UI
- **NDKSwift** for Nostr protocol operations
- **AVFoundation** for professional audio handling
- **Swift Concurrency** for efficient networking
- **Combine** for reactive data flow

### Design Philosophy

- **Dark Theme**: Elegant purple gradient aesthetics
- **Smooth Animations**: Carefully crafted transitions
- **Haptic Feedback**: Tactile responses throughout
- **Visual Feedback**: Waveforms and progress indicators
- **Footprint Theme**: Unique branding representing your voice journey

## Use Cases

- **Daily Reflections**: Share morning thoughts or evening wisdom
- **Voice Journaling**: Create an audio diary on the decentralized web
- **Micro-Podcasting**: Share expertise in bite-sized audio
- **Language Practice**: Perfect for language learners
- **Accessibility**: Ideal for users who prefer voice over text
- **Community Building**: Create intimate voice-based communities

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Roadmap

- [ ] Voice transcription with AI
- [ ] Audio effects and filters
- [ ] Voice rooms for group conversations
- [ ] Scheduled voice posts
- [ ] Voice-to-text accessibility
- [ ] Multi-language support
- [ ] Voice message threading view
- [ ] Audio bookmarking
- [ ] Export conversations as podcasts

## Why Ambulando?

- **Human Connection**: Voice brings authenticity text cannot match
- **Mindful Sharing**: 60-second limit encourages thoughtful communication
- **Decentralized**: Your voice, your data, your control
- **Trust-Based**: Content from people you trust, not algorithms
- **Beautiful Design**: A joy to use with smooth animations and haptic feedback
- **Privacy First**: No central servers, no data mining

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [NDKSwift](https://github.com/pablof7z/NDKSwift)
- Uses the [Nostr Protocol](https://nostr.com)
- Storage via [Blossom](https://github.com/hzrd149/blossom)
- Inspired by the power of human voice

## Contact

- Nostr: `npub1l2vyh47mk2p0qlsku7hg0vn29faehy9hy34ygaclpn66ukqp3afqutajft`
- GitHub: [@pablof7z](https://github.com/pablof7z)

---

<div align="center">
  Made with 🎙️ for meaningful conversations
</div>