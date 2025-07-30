# Project Specification: Ambulando

## 1. Project Name

**Ambulando**: Latin for "by walking."

---

## 2. Core Purpose & Philosophy

The single most important purpose of Ambulando is to foster **intimate and thoughtful connection** through voice. It is a direct response to the noise, performativity, and engagement-hacking of mainstream social media.

The core philosophy is rooted in the experience of an unhurried, walking conversation with a trusted friend. The entire user experience is optimized to create a feeling of calm, connection, and being heard.

**User Feeling:** When a user closes the app, they should feel **calm, connected, and heard**—not drained or anxious.

---

## 3. Target Audience

Ambulando is for individuals who feel alienated by the current social media landscape. This includes:

*   **Reflective Individuals**: Writers, artists, thinkers, and anyone who values deep conversation over fleeting content.
*   **"Social Media Dropouts"**: People actively seeking a more human-scale, trust-based online community.
*   **Privacy-Conscious Users**: Individuals who value the decentralization, data ownership, and censorship-resistance provided by the Nostr protocol.

---

## 4. Core Feature Set (What it IS)

The initial version of Ambulando is defined by a focused set of features that directly serve its core purpose.

*   **Voice-First Communication**: The fundamental unit of content is the **60-second voice post**, visualized as a waveform. This is the primary and only medium for sharing.
*   **Threaded Voice Replies**: Conversations are central. The application supports threaded replies (Kind 1244) to foster dialogue.
*   **Trust-Based Feed**: The main feed is **not chronological**. It is sorted by a weighted score of **Web of Trust (70%) and recency (30%)**. This is a non-negotiable feature that intentionally creates a "slow social" experience, prioritizing personal connection over virality.
*   **Basic Social Graph**: Users can maintain profiles and follow others. This graph is the foundation of the Web of Trust sorting algorithm.
*   **Emoji Reactions**: A simple, low-pressure way (Kind 7 events) to acknowledge a post without the need for a full voice reply.

---

## 5. Non-Goals (What it is NOT)

To maintain its unique identity and purpose, Ambulando will explicitly avoid the following:

*   **It is NOT a "Viral" Platform**: The core mechanics are designed to prevent virality. Connection is valued over clout.
*   **It is NOT a Text or Video Platform**: It is strictly **voice-first**. Other media are permanently out of scope as they would dilute the core experience.
*   **It is NOT Ad-Supported**: The decentralized and privacy-first ethos is fundamentally incompatible with an advertising model.
*   **It is NOT a Real-Time Chat App**: The architecture is built for **asynchronous conversation**.
*   **It is NOT for "Content Creators"**: The platform is not designed for influencer marketing or the optimization of engagement metrics.

---

## 6. Guiding Principles & Assumptions

*   **Decentralization is Philosophical**: The use of Nostr is a foundational commitment to user control, privacy, and censorship resistance. It is not just a technical choice.
*   **Asynchronicity is Intentional**: The app's asynchronous nature supports a more thoughtful and less pressured mode of communication.
