# AtlasLinq - NFC Digital Business Card

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)
![NFC](https://img.shields.io/badge/NFC-Enabled-4CAF50)
![License](https://img.shields.io/badge/License-MIT-blue)
![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)

**Share your contact instantly with a tap. No app needed on the receiving end.**

[The Problem](#-the-problem) • [Our Solution](#-our-solution) • [Features](#-features) • [Architecture](#-architecture) • [Tech Stack](#-tech-stack) • [Getting Started](#-getting-started)

</div>

---

## The Problem

Traditional business cards are broken:

- **Wasteful** — 88% of paper business cards are thrown away within a week
- **Static** — Can't update your info after printing
- **Easy to lose** — Physical cards get misplaced or damaged
- **Friction-heavy** — Manual data entry leads to typos and delays

Existing digital solutions require both parties to have the same app installed, creating adoption barriers.

---

## Our Solution

**AtlasLinq** is an NFC-powered digital business card that works with *any* smartphone — no app required on the receiving end.

### How It Works
1. **You tap** your phone to an NFC tag or another phone
2. **They receive** your full contact card instantly
3. **Their phone prompts** them to save it directly to contacts

**Key Innovation**: We use the vCard 3.0 standard with custom Type 4 Tag HCE emulation, ensuring universal compatibility with both Android and iPhone without requiring recipients to install anything.

### Why It Matters
- **Sustainable** — Eliminates paper waste from traditional business cards
- **Always Updated** — Change your info anytime, it's always current
- **Zero Friction** — Works with any NFC-enabled smartphone
- **Professional** — Multiple profile types for different contexts

---

## Features

### NFC Sharing
- **Tag Mode** — Write your contact to physical NFC tags (NTAG213/215/216)
- **P2P Mode** — Phone-to-phone sharing via custom HCE emulation
- **Universal Compatibility** — Works with iPhone and Android without requiring an app
- **Smart Payload Selection** — Automatically optimizes data based on tag capacity
- **Dual-Payload Support** — vCard for contact saving + URL for profile viewing

### Multiple Profile Types
- **Personal** — For friends, family, and casual connections (Instagram, Snapchat, TikTok)
- **Professional** — For business networking (LinkedIn, GitHub, company info)
- **Custom** — Fully configurable for any use case
- **Instant Switching** — Change active profile with one tap

### QR Code Backup
- **Customizable Colors** — Match your personal brand
- **Logo Options** — Atlas logo, your initials, or profile photo
- **Multiple Sizes** — Optimized for digital sharing or print
- **Error Correction** — 4 levels of damage recovery (7% to 30%)
- **Export & Share** — Save to device or share with rich messaging

### Smart History & Analytics
- **Connection Timeline** — Track sent, received, and tag writes
- **Location Context** — GPS coordinates with reverse geocoding
- **Profile Views** — See how many times your profiles are viewed
- **Contact Integration** — Auto-detects AtlasLinq contacts in your device
- **Search & Filter** — Find connections by date, method, or name

### Interactive Onboarding
- **4-Step Tutorial** — Guides new users through core features
- **Contextual Tips** — Smart positioning based on screen location
- **Progress Saving** — Resume where you left off
- **Responsive Design** — Adapts to all screen sizes

### Privacy & Security
- **GDPR Compliant** — Consent management, data export, account deletion
- **Analytics Opt-Out** — User-controlled data collection
- **Secure by Design** — Input validation, rate limiting, encrypted storage
- **Offline Support** — Works without internet, syncs when connected

### Polished UX
- **Glassmorphism Design** — Modern frosted glass aesthetic
- **Dark Theme** — Eye-friendly for all lighting conditions
- **Smooth Animations** — Fade, slide, and scale transitions
- **State Management** — Loading, error, and empty states handled gracefully
- **Haptic Feedback** — Tactile responses for key interactions

---

## Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────┐
│           Presentation Layer (UI)               │
│  Screens, Widgets, State Management             │
├─────────────────────────────────────────────────┤
│           Business Logic (Services)             │
│  ProfileService, NFCService, HistoryService     │
│  TutorialService, ValidationService, etc.       │
├─────────────────────────────────────────────────┤
│         Data Access (Repositories)              │
│  ProfileRepository, AuthRepository              │
│  StorageRepository (with caching layer)         │
├─────────────────────────────────────────────────┤
│      Data Sources (Firebase, Local)             │
│  Firestore, Storage, SharedPreferences          │
└─────────────────────────────────────────────────┘
```

### Navigation Flow

```
┌─────────────┐
│   Splash    │
└──────┬──────┘
       │
       ▼
┌─────────────┐      ┌──────────────────┐
│ Onboarding  │─────►│ Interactive      │
│   Screen    │      │ Tutorial (4 steps)│
└──────┬──────┘      └──────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│          Main App (Bottom Nav)          │
├─────────────┬─────────────┬─────────────┤
│    Home     │   Profile   │  History    │
│             │             │             │
│ • NFC FAB   │ • Editor    │ • Timeline  │
│ • Insights  │ • Types     │ • Filters   │
│ • Share     │ • QR Code   │ • Details   │
└─────────────┴─────────────┴─────────────┘
                    │
                    ▼
            ┌──────────────┐
            │   Settings   │
            │              │
            │ • QR Custom  │
            │ • Privacy    │
            │ • Account    │
            └──────────────┘
```

### Key Patterns

- **Repository Pattern** — Abstract data access with swappable implementations
- **Dependency Injection** — GetIt-based DI container for testability
- **Service Layer** — Business logic separated from UI
- **Provider + ChangeNotifier** — Reactive state management
- **Offline-First** — Queue operations when offline, sync when connected

---

## Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.10+ / Dart 3.0+ |
| **Backend** | Firebase (Firestore, Auth, Storage, Analytics, Crashlytics) |
| **NFC** | nfc_manager + Custom Type 4 Tag HCE |
| **State Management** | Provider + GetIt DI |
| **Navigation** | GoRouter |
| **UI** | Glassmorphism, Material 3, flutter_animate |
| **QR Codes** | pretty_qr_code |
| **Location** | geolocator + geocoding |
| **Images** | cached_network_image, image_picker, image_cropper |

---

## Getting Started

### Prerequisites
- Flutter SDK 3.10+
- Android device with NFC (API 21+)
- Firebase project configured

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/atlaslinq.git
cd atlaslinq

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with Flutter**

*Sustainable • Universal • Frictionless*

</div>
