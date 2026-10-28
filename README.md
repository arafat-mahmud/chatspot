# chatspot
----------

# ChatSpot - Real-time Chat Application
----------

## 📱 About ChatSpot

ChatSpot is a modern, real-time chat application built with Flutter and Firebase. It provides secure messaging, user discovery, and a beautiful interface with support for both light and dark themes.

## 🏗️ Project Structure

```
lib/
├── main.dart                      # App entry point & routing
│
├── dashboard/                     # Main app dashboard
│   ├── chats&calls_button.dart   # Home page with bottom navigation
│   └── menu/                     # Drawer menu components
│       ├── main_drawer.dart      # Main navigation drawer
│       └── components/           # Menu sub-components
│           ├── my_profile.dart   # User profile management
│           └── settings/         # Settings pages
│               ├── settings.dart      # Main settings page
│               ├── account_settings.dart  # Account management
│               ├── theme.dart          # Theme service & management
│               └── email_verification.dart # Email verification
│
├── views/                        # UI screens and pages
│   ├── auth/                     # Authentication screens
│   │   ├── signin.dart          # Sign in page
│   │   ├── signup.dart          # Sign up page
│   │   └── forgot_password.dart # Password recovery
│   │
│   ├── call/                    # Voice & video calls
│   │   ├── call_screen.dart     # In-call UI (incoming / outgoing / connected)
│   │   └── call_history_screen.dart # Calls tab (history + call back)
│   │
│   ├── chat/                    # Chat-related screens
│   │   └── chat_main/           # Main chat functionality
│   │       ├── main_chat_screen.dart     # Individual chat screen
│   │       ├── chat_message_list.dart    # Message list display
│   │       ├── message_input.dart        # Message input widget
│   │       ├── message_builders.dart     # Message UI builders
│   │       ├── image_handler.dart        # Image upload/display
│   │       ├── date_formatters.dart      # Date formatting utilities
│   │       ├── user_profile_screen.dart  # User profile viewer
│   │       └── chats_list/              # Chat list components
│   │           ├── friend_chat_list.dart # Chats tab
│   │           └── chat_list_item.dart  # Individual chat item
│   │
│   ├── friends/friend_list_screen.dart  # Friends + requests
│   ├── common/                  # Shared widgets (avatar, empty/loading states)
│   └── search_bar/
│       └── friend_aware_search_page.dart # Find people by name / @username
│
└── services/                    # Backend services & utilities
    ├── firebase_options.dart    # Firebase configuration
    ├── cloudinary_service.dart  # Image upload service
    ├── session/                 # Starts/stops everything per signed-in user
    ├── user/                    # Profile cache, own profile, profile edits
    ├── friend/                  # Friends + requests (live, in memory)
    ├── chat/                    # Chat list, sending, per-chat paging
    ├── search/                  # Indexed user search, on-device history
    └── call/                    # WebRTC calls + Firestore signaling (see CALL_SYSTEM_README.md)

See ARCHITECTURE.md for how data is loaded and cached.
```
│
```

---

## Key Features

### 🔐 Authentication & User Management
1. **Authentication System**
   - Email/Password Sign In & Sign Up (Firebase Auth)
   - Forgot Password functionality
   - Email validation
   - Auto sign-in for returning users; unverified accounts can't enter
   - User agreement & privacy policy acceptance

2. **User Profile Management**
   - Profile picture upload & management
   - Username system with @ symbol
   - Display name customization
   - Date of birth and gender information
   - Username availability checking
   - Profile picture via camera or gallery

### 💬 Chat & Messaging
3. **Real-time Messaging**
   - One-to-One messaging
   - Real-time message synchronization
   - Message timestamps with smart formatting
   - Message delivery and read status
   - Chat list with latest message preview
   - Message ordering (newest first)

4. **Message Features**
   - Text messaging
   - Image sharing (camera & gallery)
   - Emoji picker integration
   - Message input with send button
   - Image viewing with photo viewer
   - Cloudinary integration for media storage

5. **Chat Management**
   - Chat initialization service
   - Chat caching for performance
   - Chat history persistence
   - Optimistic message updates
   - Real-time chat list updates

### 🔍 Search & Discovery
6. **User Search System**
   - Global user search functionality
   - Username-based search (@username)
   - Search history management
   - Recent searches display
   - Search result filtering
   - User discovery features

### 🎨 UI/UX Features
7. **Theme & Customization**
   - Dark/Light theme support
   - Theme persistence across sessions
   - Custom color schemes
   - Material Design principles
   - Responsive design elements

8. **Navigation & Interface**
   - Bottom navigation (Chats/Calls)
   - Custom drawer menu
   - Search functionality in app bar
   - Smooth animations and transitions
   - Loading states and indicators

### 📱 Platform Integration
9. **Device Features**
   - Image picker (camera/gallery)
   - Local storage with SharedPreferences
   - Network image caching
   - Loading animations
   - Material icons integration

### ⚙️ Settings & Configuration
10. **Settings Management**
    - Account settings page
    - Notification preferences
    - Privacy settings
    - Theme switching
    - Profile management
    - Sign out functionality

### 🔧 Technical Features
11. **Backend Integration**
    - Firebase Firestore database
    - Firebase Authentication
    - Cloudinary image hosting
    - Real-time data synchronization
    - Offline data caching

12. **Performance Optimization**
    - Image caching with CachedNetworkImage
    - Chat data caching service
    - Optimistic UI updates
    - Efficient data loading
    - Memory management

### 📞 Voice & Video Calls
13. **Call Features** (see [CALL_SYSTEM_README.md](CALL_SYSTEM_README.md))
    - HD voice calls (Opus fullband) and HD video calls (720p30) over WebRTC
    - Incoming call screen with ringtone, busy detection, missed calls
    - Mute, speaker, camera toggle, camera switch
    - Automatic reconnect on network change, background calling
    - Call history in the Calls tab

### 🔒 Security Features
14. **Data Protection**
    - Firebase security rules
    - User data validation
    - Secure image upload
    - Authentication state management
    - Privacy-focused design

---

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK 
- Firebase project setup
- Cloudinary account for image hosting
- iOS/Android development environment

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd chatspot
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `lib/services/firebase_options.dart` with your configuration

4. **Cloudinary Setup**
   - Create a Cloudinary account
   - Update the cloud name and upload preset in `lib/services/cloudinary_service.dart`

5. **Run the application**
   ```bash
   flutter run
   ```

### Build for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```
Then open `ios/Runner.xcworkspace` in Xcode for final build and distribution.

---

## 📋 Features Overview

### Current Implementation Status
✅ **Fully Implemented:**
- User Authentication (Sign Up/Sign In/Password Reset)
- Real-time Messaging
- Image Sharing
- User Search & Discovery
- Profile Management
- Theme Switching (Dark/Light)
- Chat Caching & Performance Optimization
- Search History
- Emoji Support
- HD Voice & Video Calling (WebRTC)

🚧 **In Development:**
- Call notifications when the app is closed (FCM / CallKit)
- Message Encryption
- Push Notifications
- Typing Indicators
- Message Deletion
- User Blocking

📋 **Planned Features:**
- Group Chats
- File Sharing
- Message Reactions
- Status/Stories
- Advanced Privacy Settings

---

## 🛠️ Technical Architecture

### State Management
- StatefulWidget with setState for local state
- ValueNotifier for theme management
- StreamBuilder for real-time Firebase data

### Data Layer
- Firebase Firestore for real-time database
- Local caching with SharedPreferences
- Cloudinary for media storage
- Custom caching service for chat data

### Security Considerations
- Firebase Authentication for user management
- Firestore security rules for data protection
- Input validation and sanitization
- Secure image upload handling

---

## 🎨 Design Principles

- **Material Design 3** guidelines
- **Responsive** layout for different screen sizes
- **Accessibility** considerations
- **Performance** optimized with caching
- **Dark/Light** theme support
- **Smooth animations** and transitions

---

## 🐛 Known Issues & Limitations

1. Incoming calls only ring while the app is open or recently backgrounded (no push yet)
2. No offline message queuing yet
3. Limited file type support (images only)
4. No message encryption implemented
5. Basic error handling in some areas

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 📞 Support

For support, email [your-email] or create an issue in the repository.

---

---

## 📦 Dependencies & Packages Used

### Core Firebase
- `firebase_core: ^3.12.0` - Firebase SDK initialization
- `firebase_auth: ^5.5.0` - Authentication services
- `cloud_firestore: ^5.6.4` - Real-time database

### UI & User Experience
- `emoji_picker_flutter: ^4.3.0` - Emoji picker widget
- `loading_animation_widget: ^1.3.0` - Loading animations
- `cupertino_icons: ^1.0.8` - iOS style icons
- `photo_view: ^0.15.0` - Image viewing with zoom/pan

### Image & Media Handling
- `image_picker: ^1.1.2` - Camera and gallery access
- `image_picker_android: ^0.8.12+22` - Android-specific image picker
- `image_picker_platform_interface: ^2.10.1` - Platform interface
- `cached_network_image: ^3.4.1` - Network image caching
- `cloudinary_flutter: ^1.3.0` - Cloudinary SDK
- `cloudinary_public: ^0.23.1` - Public Cloudinary API

### Calls
- `flutter_webrtc` - Peer-to-peer audio/video (WebRTC)
- `flutter_foreground_task` - Keeps calls alive in the background on Android
- `flutter_ringtone_player` - Incoming call ringtone

### Utilities
- `shared_preferences: ^2.5.2` - Local data storage
- `email_validator: ^3.0.0` - Email validation
- `http: ^1.3.0` - HTTP requests
- `intl: ^0.20.2` - Internationalization and date formatting

### Development Tools
- `flutter_launcher_icons: ^0.14.3` - App icon generation
- `flutter_lints: ^5.0.0` - Dart linting rules

---

## Setup Commands

**Basic Flutter Commands:**
```bash
flutter pub get
flutter upgrade  
flutter pub upgrade
```

**iOS Development:**
```bash
cd ios
open Runner.xcworkspace
```

**Android Development:**
- Ensure all Firebase configuration files are properly placed
- Verify Google Play Services are installed

---
