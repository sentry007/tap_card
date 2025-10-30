# 📱 Atlas Linq - NFC Digital Business Card

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)
![NFC](https://img.shields.io/badge/NFC-Enabled-4CAF50)
![License](https://img.shields.io/badge/License-MIT-blue)
![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)

**A modern Flutter application for sharing contact information via NFC technology with glassmorphism UI**

[Features](#-features) • [Architecture](#-architecture) • [Setup](#-setup) • [Documentation](#-documentation)

</div>

---

## 🌟 Features

### 🏷️ **NFC Tag Writing**
- **Multi-Tag Support**: NTAG213 (144 bytes), NTAG215 (504 bytes), NTAG216 (888 bytes)
- **Intelligent Payload Selection**: Auto-detects tag capacity and chooses optimal payload
  - Dual-Payload (vCard + URL) for large tags
  - URL-only for small tags with automatic fallback
- **Payload Type Tracking**: Visual indicators show "Full card" vs "Mini card" writes
- **Record Order Optimization**: vCard-first for Android contact saving, URL-second for iOS fallback
- **Pre-cached Payloads**: Instant (0ms) NFC sharing with zero latency
- **vCard 3.0 Format**: Universal contact compatibility across all platforms

### 📲 **Phone-to-Phone Sharing (P2P)**
- **Custom Type 4 Tag Emulation**: Native NFC Forum Type 4 Tag implementation
- **iOS/iPhone Compatible**: Full CoreNFC support via proper APDU handling
- **Cross-Platform**: Works with Android and iPhone NFC readers
- **Dual-Payload HCE**: Same vCard + URL strategy as physical tags
- **Context-Aware Protocol**: Intelligent file selection (Capability Container vs NDEF)
- **No App Required**: Recipients don't need Atlas Linq installed
- **Auto-Save Contacts**: vCard format triggers native contact save on any phone

### 👤 **Multiple Profile Types**
- **Personal Profile**: Friends, family, casual connections
  - Social: Instagram, Snapchat, TikTok, Twitter, Facebook, Discord
  - Color: Orange gradient
- **Professional Profile**: Business networking, conferences
  - Social: LinkedIn, Twitter, GitHub, Behance, Dribbble
  - Company, Title, Website fields
  - Color: Blue gradient
- **Custom Profile**: Fully customizable for any use case
  - All fields and social platforms
  - Color: Purple gradient
- **Profile Switching**: Instant switching between active profiles
- **Visual Customization**: Gradient color pickers and background images
- **Cloud Storage**: Firebase Storage for profile and background images with caching

### 📊 **Smart History & Analytics**
- **Three Entry Types**: Sent, Received, and Tag Writes
- **Contact Scanning**: Auto-detects Atlas Linq contacts in device contacts
- **Firestore Integration**: Fetches full profile data for received contacts
- **Profile View Tracking**: Track how many times your profiles are viewed
- **Location Tracking**: GPS coordinates with reverse geocoding for addresses
- **Filters & Search**: Filter by date, method, type; search by name/location
- **Rich Metadata**:
  - Tag info (ID, type, capacity, payload type)
  - Share context (timestamp, method, location)
  - Device information
- **Firebase Analytics**: User event tracking for insights

### 🔥 **Firebase Backend**
- **Cloud Firestore**: Real-time profile and history sync
- **Firebase Storage**: Cloud-hosted images with automatic caching
- **Network Image Caching**: Optimized loading with cached_network_image
- **Background Image Management**: Upload, update, delete with cloud sync
- **Profile Views Service**: Track profile engagement metrics
- **Analytics Events**: User behavior tracking and insights

### 🎨 **Modern UI/UX**
- **Glassmorphism Design**: Frosted glass effects throughout
- **Five-State NFC FAB**: Inactive → Active → Writing → Success/Error
- **Breathing Animations**: Pulsing effects when waiting for NFC
- **Responsive Feedback**: Haptics, visual cues, and clear messaging
- **Dark Theme**: Eye-friendly design optimized for low-light use
- **Snackbar Consistency**: Icons and proper text wrapping across all screens
- **Profile Detail Modals**: Rich profile previews with full data
- **Badges & Polish**: Visual indicators for entry types and statuses

### ⚙️ **Settings & Preferences**
- **QR Code Settings**: Size, error correction, and color customization
- **App Settings Service**: Persistent preferences with SharedPreferences
- **Quick NFC Access**: Direct link to device NFC settings via app_settings
- **Settings Dialog**: Improved UX with real data integration

### 🔗 **Social Media Integration**
- **Android URL Scheme Support**: Native app deep links for:
  - Instagram, Twitter, LinkedIn, GitHub
  - Facebook, Snapchat, TikTok, Discord
  - Behance, Dribbble, and more
- **Fallback URLs**: Web profiles if native apps not installed
- **Email & Phone**: Direct mailto: and tel: scheme support

---

## 🏗️ Architecture

### Application Architecture

```mermaid
graph TB
    subgraph "Presentation Layer"
        A[Home Screen] --> B[Profile Screen]
        A --> C[History Screen]
        A --> D[Settings Screen]
    end

    subgraph "Business Logic"
        E[ProfileService] --> F[NFCService]
        E --> G[HistoryService]
        E --> H[ContactService]
        F --> I[NFC Discovery]
    end

    subgraph "Data Layer"
        J[SharedPreferences] --> E
        J --> G
        K[Firebase Firestore] -.-> E
        K -.-> G
        L[Device Contacts] --> H
    end

    A --> E
    B --> E
    C --> G
    C --> H
    A --> F

    style A fill:#FF6B35
    style E fill:#4A90E2
    style J fill:#9C27B0
    style K fill:#FFCA28
```

### NFC Tag Write Flow

```mermaid
sequenceDiagram
    participant User
    participant HomeScreen
    participant NFCService
    participant ProfileService
    participant Android
    participant NFCTag

    User->>HomeScreen: Tap NFC FAB
    HomeScreen->>ProfileService: Get Active Profile
    ProfileService-->>HomeScreen: Return Profile with cached dual-payload

    HomeScreen->>NFCService: writeData(dualPayload)
    NFCService->>NFCService: Check payload size

    alt Dual Payload Fits (vCard + URL)
        NFCService->>Android: writeDualPayload(vCard, URL)
    else URL Only
        NFCService->>Android: writeUrlOnly(URL)
    end

    NFCService->>Android: Enable Foreground Dispatch
    Android-->>NFCService: Waiting for tag...

    User->>NFCTag: Bring phone close to tag
    NFCTag-->>Android: Tag discovered

    Android->>NFCTag: Write NDEF Records
    alt vCard + URL
        Android->>NFCTag: Record 1: vCard (text/x-vcard)
        Android->>NFCTag: Record 2: URL
    else URL Only
        Android->>NFCTag: Record 1: URL
    end

    NFCTag-->>Android: Write success
    Android-->>NFCService: onWriteSuccess callback
    NFCService-->>HomeScreen: NFCResult.success
    HomeScreen->>HomeScreen: Update FAB to Success state
    HomeScreen->>User: Show success message
```

### Phone-to-Phone (P2P) Flow

```mermaid
sequenceDiagram
    participant User
    participant HomeScreen
    participant NFCService
    participant HCE_Service
    participant OtherPhone

    User->>HomeScreen: Long press FAB → Select P2P Mode
    HomeScreen->>NFCService: startCardEmulation(vCard)
    NFCService->>HCE_Service: Start HCE with vCard payload
    HCE_Service-->>NFCService: Service active
    NFCService-->>HomeScreen: Show "Ready for Tap"

    HomeScreen->>HomeScreen: FAB enters Active state
    HomeScreen->>HomeScreen: Breathing animation + Ripples

    User->>OtherPhone: Hold phones together
    OtherPhone->>HCE_Service: APDU SELECT command
    HCE_Service->>OtherPhone: Send vCard data
    OtherPhone->>OtherPhone: Parse vCard
    OtherPhone->>User: Show "Save Contact" dialog

    User->>HomeScreen: Tap FAB again to stop
    HomeScreen->>NFCService: stopCardEmulation()
    NFCService->>HCE_Service: Stop service
    HomeScreen->>HomeScreen: FAB returns to Inactive
```

### Profile Management Flow

```mermaid
graph LR
    A[App Launch] --> B{Profiles Exist?}
    B -->|No| C[Create Default Profiles]
    B -->|Yes| D[Load from Storage]

    C --> E[Personal Profile]
    C --> F[Professional Profile]
    C --> G[Custom Profile]

    D --> H[Set Active Profile]
    E --> H
    F --> H
    G --> H

    H --> I[Generate NFC Cache]
    I --> J[vCard Generation]
    I --> K[URL Generation]

    J --> L[Dual-Payload Ready]
    K --> L

    L --> M[App Ready for Sharing]

    style C fill:#FF6B35
    style I fill:#4CAF50
    style L fill:#9C27B0
```

### History & Contact Scanning Flow

```mermaid
graph TB
    A[History Screen Load] --> B{Permission Granted?}
    B -->|No| C[Show Permission Banner]
    B -->|Yes| D[Scan Device Contacts]

    C --> E[User Taps 'Allow Access']
    E --> F[Request Permission]
    F --> B

    D --> G[flutter_contacts.getContacts]
    G --> H{Check Websites Field}
    H -->|Contains tapcard.app/share/| I[Extract Profile ID]
    H -->|No URL| J[Skip Contact]

    I --> K{Validate ID Format}
    K -->|UUID Format| L[Mark as New Format]
    K -->|Name Format| M[Mark as Legacy]

    L --> N[Create HistoryEntry]
    M --> N

    N --> O[Merge with Local History]
    O --> P[Display in UI]

    style D fill:#4CAF50
    style N fill:#FF6B35
    style P fill:#4A90E2
```

### Data Persistence Architecture

```mermaid
graph TB
    subgraph "Local Storage"
        A[SharedPreferences]
        A --> B[Profiles JSON]
        A --> C[History JSON]
        A --> D[Settings JSON]
    end

    subgraph "Services"
        E[ProfileService] -.->|Read/Write| B
        F[HistoryService] -.->|Read/Write| C
        G[AppState] -.->|Read/Write| D
    end

    subgraph "Firebase Cloud"
        H[Firestore]
        H --> I[users/{uid}/profiles]
        H --> J[users/{uid}/history]
        H --> K[analytics/{uid}/events]
    end

    E -.->|Future: Sync| I
    F -.->|Future: Sync| J

    subgraph "External Data"
        L[Device Contacts]
        M[ContactService] --> L
    end

    style A fill:#9C27B0
    style H fill:#FFCA28
    style L fill:#4CAF50
```

---

## 🛠️ Technology Stack

### **Frontend**
- **Flutter 3.10+** - Cross-platform UI framework
- **Dart 3.0+** - Programming language
- **Provider** - State management
- **GoRouter** - Declarative routing

### **NFC Technology**
- **nfc_manager** - Core NFC reading/writing
- **Custom NfcTagEmulatorService** - Native Type 4 Tag emulation for iOS compatibility
- **ndef** - NDEF message formatting
- **Native Android** - Custom foreground dispatch & APDU handling

### **Backend & Storage**
- **Firebase Core** - Backend infrastructure
- **Cloud Firestore** - NoSQL cloud database
- **Firebase Storage** - File storage (profile images)
- **SharedPreferences** - Local key-value storage

### **UI/UX**
- **Glassmorphism** - Frosted glass effects
- **Lottie** - Complex animations
- **Flutter Animate** - Smooth transitions
- **Cached Network Image** - Optimized Firebase Storage image loading

### **Utilities**
- **flutter_contacts** - Contact management
- **geolocator** - Location services
- **geocoding** - Reverse geocoding for addresses
- **url_launcher** - External link handling (social media URL schemes)
- **share_plus** - Native sharing
- **qr_flutter** - QR code generation
- **mobile_scanner** - QR code scanning
- **app_settings** - Direct access to device settings

---

## 📁 Project Structure

```
tap_card/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart       # App-wide constants
│   │   │   ├── routes.dart              # Route definitions
│   │   │   └── widget_keys.dart         # Widget test keys
│   │   ├── models/
│   │   │   └── profile_models.dart      # Profile data structures
│   │   ├── navigation/
│   │   │   ├── app_router.dart          # GoRouter configuration
│   │   │   ├── glass_bottom_nav.dart    # Bottom navigation bar
│   │   │   └── navigation_wrapper.dart  # Navigation container
│   │   ├── providers/
│   │   │   └── app_state.dart           # Global app state
│   │   └── services/
│   │       ├── notification_service.dart # In-app notifications
│   │       └── profile_service.dart      # Profile management
│   ├── models/
│   │   ├── unified_models.dart          # Contact & share models
│   │   └── history_models.dart          # History entry models
│   ├── screens/
│   │   ├── home/
│   │   │   └── home_screen.dart         # Main NFC sharing screen
│   │   ├── profile/
│   │   │   └── profile_screen.dart      # Profile editor
│   │   ├── history/
│   │   │   └── history_screen.dart      # History viewer
│   │   ├── settings/
│   │   │   └── settings_screen.dart     # App settings
│   │   └── splash/
│   │       └── splash_screen.dart       # Loading screen
│   ├── services/
│   │   ├── nfc_service.dart             # NFC write/read logic
│   │   ├── nfc_discovery_service.dart   # NFC tag detection
│   │   ├── history_service.dart         # History CRUD
│   │   ├── contact_service.dart         # Contact scanning
│   │   ├── firebase_config.dart         # Firebase setup
│   │   └── firestore_sync_service.dart  # Cloud sync
│   ├── theme/
│   │   ├── app_colors.dart              # Color palette
│   │   ├── app_text_styles.dart         # Typography
│   │   └── app_theme.dart               # Theme configuration
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── glassmorphic_container.dart
│   │   │   └── profile_card_preview.dart
│   │   ├── history/
│   │   │   └── method_chip.dart         # Share method badge
│   │   ├── glass_card.dart              # Glass effect card
│   │   ├── app_button.dart              # Custom buttons
│   │   ├── glassmorphic_dialog.dart     # Modal dialogs
│   │   └── share_modal.dart             # Share options modal
│   ├── firebase_options.dart            # Firebase config (auto-gen)
│   └── main.dart                        # App entry point
├── android/
│   └── app/
│       ├── src/main/
│       │   ├── kotlin/com/example/tap_card/
│       │   │   ├── MainActivity.kt              # Native NFC handling
│       │   │   └── NfcTagEmulatorService.kt     # Custom Type 4 Tag HCE
│       │   └── AndroidManifest.xml              # Permissions & HCE service
│       ├── build.gradle.kts                     # Android config
│       └── google-services.json                 # Firebase credentials
├── assets/
│   └── images/                          # App images
├── pubspec.yaml                         # Dependencies
└── README.md                            # This file
```

---

## 🚀 Setup

### Prerequisites

- Flutter SDK 3.10+
- Dart SDK 3.0+
- Android Studio / VS Code
- Android device with NFC (API 19+)
- Firebase project (for backend features)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/tap_card.git
   cd tap_card
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**

   a. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

   b. Add Android app to Firebase project

   c. Download `google-services.json` and place in `android/app/`

   d. Generate Firebase options:
   ```bash
   flutterfire configure
   ```

4. **Android NFC Setup**

   The `AndroidManifest.xml` is already configured with:
   - NFC permissions
   - HCE service declaration
   - Foreground dispatch support
   - Social media URL schemes (Instagram, Twitter, LinkedIn, GitHub, etc.)
   - Email, phone, and SMS intents

   Verify `android/app/src/main/res/xml/apduservice.xml` exists for HCE.

5. **Run the app**
   ```bash
   flutter run
   ```

### Testing NFC Features

1. **Tag Write Mode**
   - Tap the NFC FAB on home screen
   - Bring NFC tag within 4cm
   - Wait for success confirmation

2. **Phone-to-Phone Mode**
   - Long-press the NFC FAB
   - Select "P2P Share" mode
   - Tap another NFC phone to yours
   - Other phone shows save contact dialog

---

## 📖 Documentation

### NFC Tag Writing

TapCard uses a **dual-payload strategy** for maximum compatibility:

#### Dual-Payload Approach
```
┌─────────────────────────────────────┐
│         NFC Tag Memory              │
├─────────────────────────────────────┤
│ Record 1: vCard (text/x-vcard)      │
│  - Name, Phone, Email, Company      │
│  - Auto-saveable on any device      │
│  - Universal compatibility          │
├─────────────────────────────────────┤
│ Record 2: URL                       │
│  - https://atlaslinq.com/share/[id] │
│  - Full digital profile link        │
│  - Analytics & tracking             │
└─────────────────────────────────────┘
```

**Benefits:**
- Recipients can **instantly save contact** (vCard)
- Recipients can **view full profile** (URL)
- Works on **any NFC phone** (no app required)
- Efficient use of tag memory

#### Supported NFC Tags

| Tag Type  | Capacity | Use Case                    |
|-----------|----------|-----------------------------|
| NTAG213   | 144 bytes| Basic contact info          |
| NTAG215   | 504 bytes| Full contact + socials      |
| NTAG216   | 888 bytes| Extended data + analytics   |

#### Payload Optimization

Atlas Linq pre-generates and caches payloads for **0ms sharing lag**:

```dart
// Cached in ProfileData
final dualPayload = profile.dualPayload;
// Returns: { 'vcard': '...', 'url': '...' }

// NFCService uses cached data instantly
await NFCService.writeData(dualPayload);
```

Cache refresh: Every 5 minutes or when profile changes.

### Phone-to-Phone Sharing (HCE) - Custom Type 4 Tag Emulation

**How it works:**

1. **Your phone** emulates an NFC Forum Type 4 Tag using custom HCE service
2. **Other phone** (Android or iPhone) initiates NFC read
3. **HCE service** handles APDU commands (SELECT, READ BINARY)
4. **Service** returns Capability Container and NDEF message
5. **Other phone** parses vCard + URL and shows "Save Contact" dialog

**Technical Implementation:**
- Custom `NfcTagEmulatorService` (Kotlin)
- Implements full NFC Forum Type 4 Tag specification
- APDU command handling:
  - SELECT Application (AID: D2760000850101)
  - SELECT Capability Container (File ID: E103)
  - SELECT NDEF File (File ID: E104)
  - READ BINARY with context-aware file selection
- Capability Container structure (15 bytes)
- NDEF file with 2-byte length prefix + message data
- State tracking for selected file (CC vs NDEF)

**Cross-Platform Compatibility:**
- ✅ **Android NFC**: Saves vCard contact automatically
- ✅ **iPhone iOS CoreNFC**: Opens URL in Safari (vCard fallback)
- ✅ **Handles APDU variations**: Optional Le (expected length) byte
- ✅ **Proper record order**: vCard first, URL second

**Advantages:**
- No physical tags needed
- Works with iPhone (iOS CoreNFC compatible)
- Instant profile updates
- Same dual-payload as physical tags
- No recipient app required

### Profile System

TapCard supports **3 profile types**:

#### 1. Personal Profile
```yaml
Fields:
  - Name (required)
  - Phone (required)
  - Email
  - Social: Instagram, Snapchat, TikTok, Twitter, Facebook, Discord

Color Scheme: Orange gradient
Use Case: Friends, family, casual networking
```

#### 2. Professional Profile
```yaml
Fields:
  - Name (required)
  - Phone (required)
  - Company (required)
  - Title
  - Email
  - Website
  - Social: LinkedIn, Twitter, GitHub, Behance, Dribbble

Color Scheme: Blue gradient
Use Case: Business networking, conferences, meetings
```

#### 3. Custom Profile
```yaml
Fields:
  - All fields customizable
  - Social: All platforms

Color Scheme: Purple gradient
Use Case: Flexible use cases, special events
```

**Profile Switching:**
- Instant switch via profile screen
- Active profile used for NFC sharing
- Each profile has unique aesthetic

### NFC Type 4 Tag Emulation Architecture

Atlas Linq implements a custom NFC Forum Type 4 Tag emulator for cross-platform P2P sharing:

#### File System Structure

```
NDEF Application (AID: D2760000850101)
├── Capability Container (E103) - 15 bytes
│   ├── Version: 2.0
│   ├── Max read: 59 bytes
│   ├── Max write: 52 bytes
│   └── NDEF file info (E104, 2048 byte max)
│
└── NDEF File (E104) - Variable size
    ├── NLEN (2 bytes) - Message length
    └── NDEF Message
        ├── Record 1: vCard (text/vcard)
        └── Record 2: URL
```

#### APDU Command Flow

```
Reader → SELECT Application (D2760000850101)
       ← OK (0x90 0x00)

Reader → SELECT CC File (E103)
       ← OK (0x90 0x00)

Reader → READ BINARY CC (15 bytes)
       ← [Capability Container] + OK

Reader → SELECT NDEF File (E104)
       ← OK (0x90 0x00)

Reader → READ BINARY offset=0, length=2
       ← [NLEN: 0x01 0x1E] + OK  (286 bytes)

Reader → READ BINARY offset=2, length=59
       ← [NDEF chunk 1] + OK

Reader → READ BINARY offset=61, length=59
       ← [NDEF chunk 2] + OK

... continues until all data read
```

#### State Management

The service tracks which file is currently selected:
- `NONE` - No file selected
- `CAPABILITY_CONTAINER` - CC file selected (returns CC data)
- `NDEF_FILE` - NDEF file selected (returns NLEN or NDEF data)

This context-aware approach ensures:
- Correct data returned based on selected file
- Proper handling of offset-based reads
- iPhone iOS compatibility (strict APDU conformance)

### History System

**Three entry types:**

1. **Sent** - You shared your card
   ```json
   {
     "type": "sent",
     "recipientName": "John Doe",
     "method": "nfc",
     "timestamp": "2025-10-10T14:30:00Z",
     "location": "37.7749, -122.4194"
   }
   ```

2. **Received** - You received a card
   ```json
   {
     "type": "received",
     "senderProfile": { /* ProfileData */ },
     "method": "nfc",
     "timestamp": "2025-10-10T14:30:00Z"
   }
   ```

3. **Tag** - You wrote to an NFC tag
   ```json
   {
     "type": "tag",
     "tagId": "04:5E:23:A2:B3:4F:80",
     "tagType": "NTAG213",
     "tagCapacity": 144,
     "method": "tag",
     "timestamp": "2025-10-10T14:30:00Z"
   }
   ```

**Contact Scanning:**
- Automatically detects Atlas Linq contacts in device
- Extracts profile IDs from URLs
- Shows in history as "received" entries
- Requires contacts permission

### UI/UX Design

#### Five-State NFC FAB

The floating action button (FAB) provides clear visual feedback:

| State      | Visual                      | Meaning                    |
|------------|-----------------------------|----------------------------|
| Inactive   | Dull white icon             | Ready to start             |
| Active     | Glowing white + breathing   | Waiting for tap            |
| Writing    | Loading spinner             | Writing data (brief)       |
| Success    | Green checkmark + scale     | Write successful           |
| Error      | Red X icon                  | Write failed               |

#### Animations
- **Breathing Effect**: FAB pulses when active
- **Ripple Waves**: Expand when device detected
- **Success Pop**: Elastic scale animation
- **Slide Transitions**: Smooth screen changes
- **Glassmorphism**: Frosted glass throughout

---

## 🔐 Security & Privacy

- **Local-First**: All data stored locally by default
- **No Cloud Requirement**: App works offline
- **Optional Sync**: Firebase sync opt-in
- **Permission Control**: Explicit permission requests
- **UUID-Based URLs**: No personal data in URLs
- **No Tracking**: Analytics opt-in only

---

## 🎯 Roadmap

### ✅ Completed
- [x] NFC tag writing (NTAG213/215/216)
- [x] Phone-to-phone sharing (HCE)
- [x] Custom NFC Type 4 Tag emulator (iOS/iPhone compatible P2P)
- [x] Intelligent tag capacity detection and payload optimization
- [x] Payload type tracking (dual vs url-only) with UI indicators
- [x] Multiple profile types
- [x] History tracking with Firestore integration
- [x] Contact scanning with profile fetching
- [x] Glassmorphism UI
- [x] Firebase integration (Firestore + Storage)
- [x] Firebase Analytics integration
- [x] Profile view tracking
- [x] Background image upload/deletion
- [x] Network image caching
- [x] Share context metadata
- [x] Location tracking with geocoding
- [x] QR code settings and customization
- [x] Settings persistence service
- [x] Snackbar consistency with icons
- [x] Social media URL scheme support (Android)

### 🚧 In Progress
- [ ] Analytics dashboard
- [ ] Cloud sync optimization

### 📋 Planned
- [ ] iOS app support (native iOS build)
- [ ] Batch tag writing
- [ ] Export history (CSV)
- [ ] Dark/light theme toggle
- [ ] Multi-language support
- [ ] Web profile viewer
- [ ] Enhanced share analytics dashboard

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow [Flutter style guide](https://flutter.dev/docs/development/tools/formatting)
- Add comments for complex logic
- Write tests for new features
- Update documentation
- Use conventional commits

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/atlas_linq/issues)
- **Email**: support@atlaslinq.com
- **Documentation**: [Wiki](https://github.com/yourusername/atlas_linq/wiki)

---

## 🙏 Acknowledgments

- **Flutter Team** - Amazing framework
- **Firebase** - Backend infrastructure
- **nfc_manager** - Core NFC functionality
- **Community** - Feedback and contributions

---

<div align="center">

**Built with ❤️ using Flutter**

[⬆ Back to Top](#-atlas-linq---nfc-digital-business-card)

</div>
