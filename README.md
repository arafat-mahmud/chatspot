# chatspot
----------

Folder Structure
lib/
│── main.dart
│
├── core/                 # Core utilities and constants
│   ├── constants.dart
│   ├── theme.dart
│   ├── encryption.dart   # Functions for encrypting/decrypting messages
│
│
├── views/
│   ├── auth/
│   │   ├── sign_in.dart
│   │   ├── sign_up.dart
│   │   ├── forgot_password.dart
│   │
│   ├── chat/ 
│   │   ├── chat_screen.dart
│   │   ├── call_screen.dart
│   │   ├── chat_list.dart
│   │
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── profile_screen.dart
│   │
│   ├── home_screen.dart  # Main UI after authentication
│
```

---

## Key Features
1. Authentication
   - Sign in / Sign up (Firebase Auth)
   // - Google & Email Authentication
   - Forgot Password

2. Chat & Encryption
   - One-to-One Messaging
   - End-to-End Encryption (AES & RSA)
   - Message Timestamp & Delivery Status

3. Voice & Video Calls (WebRTC)
   - Real-time Audio & Video Calling
   - Call Notifications (Firebase Cloud Messaging)
   - Peer-to-Peer Connection

4. Chat Features
   - Typing Indicator
   - Read Receipts
   - Message Deletion
   - Media Sharing (Images, Videos, Files)

5. Settings & Profile
   - Change Profile Picture
   - Block/Unblock Users
   - Privacy & Security Settings

---

Important Notes:
  - flutter pub get
  - flutter upgrade
  - flutter pub upgrade

open Runner.xcodeproj
