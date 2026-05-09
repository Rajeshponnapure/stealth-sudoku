# 🕵️‍♂️ Stealth Sudoku: The Personal Communication Vault

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**Stealth Sudoku** is not what it appears to be. On the surface, it is a fully functional, high-quality Sudoku puzzle game. However, beneath the grid lies a state-of-the-art **Stealth Communication Vault** designed for absolute privacy and secure collaboration.

---

## 🎭 The Disguise vs. The Reality

### 🧩 The Surface (Sudoku)
- Multiple difficulty levels (Easy, Medium, Hard, Expert).
- Elegant, minimalist UI with dark mode support.
- Note-taking, hints, and error highlighting.
- High-performance puzzle engine.

### 🔐 The Vault (Stealth Communicator)
Triggered by a specific sequence or security credential, the app transforms into a private communication hub:
- **Virtual Identities**: Register and login using only a Nickname and a 6-digit Secure PIN. No phone numbers or real emails required.
- **Private Rooms**: Collaborate in shared "Rooms" where only members with the unique Room ID can communicate.
- **End-to-End Encryption**: Every message is encrypted locally using **AES-256-GCM** before reaching the cloud.
- **Real-time Signal Isolation**: Unique physical hardware IDs ensure your identity is locked to your device, preventing cloud backup clones.

---

## 🚀 Key Features

### 📨 Secure Messaging
- **Instant Sync**: Real-time message delivery via Supabase.
- **Self-Destructing Logic**: Messages are kept in volatile memory and only persisted when strictly necessary.
- **Rich Media**: Support for file sharing and image exchange within the vault.

### 📞 Encrypted Calling
- **P2P Audio/Video**: Secure WebRTC signaling for low-latency calls.
- **Ghost Ringing Prevention**: Hardened signaling prevents loopbacks and identity duplication.

### 🛡️ Security Hardening
- **Panic Lock**: Instantly lock the vault and clear sensitive session data with a single tap or gesture.
- **Biometric Authentication**: Fingerprint/FaceID support for frictionless vault entry.
- **Hardware Stamp**: Identity is locked to the physical device hardware to prevent hijacking.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Backend**: [Supabase](https://supabase.com) (PostgreSQL, Realtime, Auth, Storage)
- **Push Notifications**: [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- **Calling Interface**: WebRTC
- **Database Architecture**: Room-based sharding with Row Level Security (RLS).

---

## 📖 How to Use

1. **The Game**: Open the app and play Sudoku as normal.
2. **The Entry**: Access the System Configuration via the settings or a hidden trigger.
3. **The Vault**: 
   - **Create a Room**: Generate a unique Room ID and invite your partner.
   - **Unlock**: Enter your Nickname and PIN to sync with your private vault.
4. **Communicate**: Once inside, your contacts in the same room will appear for instant, encrypted chat and calling.

---

## ⚖️ License

Distributed under the MIT License. See `LICENSE` for more information.

---

*“Privacy is not a luxury; it is a right disguised as a game.”*
