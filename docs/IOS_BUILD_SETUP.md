# iOS Build Setup Guide

This guide explains how to set up iOS builds for Atlas Linq using GitHub Actions CI/CD.

## Overview

Since you're developing on Windows, you cannot build iOS locally. This setup uses GitHub Actions with macOS runners to build your iOS app and produce an IPA file that you can sideload onto your iPhone.

---

## Prerequisites

### 1. GitHub Repository
- Your code must be pushed to a GitHub repository
- The repository can be public or private (private repos have limited free CI minutes)

### 2. Firebase iOS App (Required)
You need to configure Firebase for iOS:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `tap-card-app-75c37`
3. Click **Add app** → Select **iOS**
4. Enter Bundle ID: `com.atlaslinq.app`
5. Download `GoogleService-Info.plist`
6. **Important**: Update `lib/firebase_options.dart` with the real iOS values from the plist file

### 3. Apple Developer Account (Optional but Recommended)
- For sideloading unsigned IPAs: Not strictly required
- For signed builds: Required ($99/year at developer.apple.com)

---

## Step-by-Step Setup

### Step 1: Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

#### Required Secrets:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ENV_FILE_CONTENTS` | Contents of your `.env` file | Copy the entire contents of your local `.env` file |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | Firebase iOS config (base64 encoded) | See instructions below |

#### How to create `GOOGLE_SERVICE_INFO_PLIST_BASE64`:

**On Mac/Linux:**
```bash
base64 -i GoogleService-Info.plist | pbcopy
# The base64 string is now in your clipboard
```

**On Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("GoogleService-Info.plist")) | Set-Clipboard
# The base64 string is now in your clipboard
```

**Online tool (if needed):**
Use https://www.base64encode.org/ to encode the file contents

### Step 2: Update Firebase Options

Edit `lib/firebase_options.dart` and replace the placeholder iOS values:

```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_IOS_API_KEY',      // From GoogleService-Info.plist: API_KEY
  appId: 'YOUR_ACTUAL_IOS_APP_ID',        // From GoogleService-Info.plist: GOOGLE_APP_ID
  messagingSenderId: '319083477759',       // Same as Android
  projectId: 'tap-card-app-75c37',         // Same as Android
  storageBucket: 'tap-card-app-75c37.firebasestorage.app',
  iosBundleId: 'com.atlaslinq.app',
);
```

Find these values in your `GoogleService-Info.plist`:
- `API_KEY` → `apiKey`
- `GOOGLE_APP_ID` → `appId`
- `GCM_SENDER_ID` → `messagingSenderId`
- `PROJECT_ID` → `projectId`
- `STORAGE_BUCKET` → `storageBucket`
- `BUNDLE_ID` → `iosBundleId`

### Step 3: Push Your Code

```bash
git add .
git commit -m "feat: add iOS build configuration and CI/CD pipeline"
git push origin main
```

### Step 4: Run the Build

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Select **Build iOS IPA** workflow
4. Click **Run workflow**
5. Select build mode (release recommended)
6. Click **Run workflow** button
7. Wait ~15-20 minutes for the build to complete

### Step 5: Download the IPA

1. Once the workflow completes (green checkmark), click on the workflow run
2. Scroll down to **Artifacts**
3. Download `atlas-linq-ios-release-X` (X is the run number)
4. Unzip the downloaded file to get the `.ipa` file

---

## Sideloading the IPA to Your iPhone

Since the IPA is unsigned, you need to use a sideloading tool:

### Option A: Sideloadly (Recommended for Windows)

1. Download [Sideloadly](https://sideloadly.io/) for Windows
2. Connect your iPhone via USB
3. Open Sideloadly
4. Drag the `.ipa` file into Sideloadly
5. Enter your Apple ID (creates a free 7-day certificate)
6. Click **Start**
7. On your iPhone: **Settings** → **General** → **VPN & Device Management** → Trust the developer certificate

### Option B: AltStore

1. Download [AltServer](https://altstore.io/) for Windows
2. Install AltStore on your iPhone via AltServer
3. Open AltStore on iPhone
4. Go to **My Apps** → **+** → Select the IPA file
5. Wait for installation

### Option C: Diawi (No software needed)

1. Go to [diawi.com](https://www.diawi.com/)
2. Upload your IPA file
3. Get the installation link/QR code
4. Open the link on your iPhone
5. Install the app

**Note**: Sideloaded apps expire after 7 days with a free Apple ID. You'll need to reinstall periodically.

---

## iOS Feature Differences

Due to iOS platform limitations, some features work differently:

| Feature | Android | iOS |
|---------|---------|-----|
| **Share via NFC tap** | ✅ Write to tag / P2P | ❌ Not supported |
| **Share via AirDrop** | ❌ Not available | ✅ Primary method |
| **Share via QR Code** | ✅ Works | ✅ Works |
| **Share via Link** | ✅ Works | ✅ Works |
| **Read NFC tags** | ✅ Works | ✅ Works (read-only) |

On iOS, tapping the main share FAB will open the share modal with AirDrop, QR code, and link options.

---

## Troubleshooting

### Build fails with "GoogleService-Info.plist not found"
- Make sure you added the `GOOGLE_SERVICE_INFO_PLIST_BASE64` secret
- Verify the base64 encoding is correct (no extra newlines)

### Build fails with "CocoaPods error"
- This usually resolves on retry
- If persistent, the Podfile.lock might be stale - delete it and let it regenerate

### App crashes on launch
- Check Firebase configuration matches your bundle ID
- Ensure all required permissions are in Info.plist

### Sideloading fails with "Unable to install"
- Make sure your device is connected and trusted
- Try restarting both the computer and iPhone
- Free Apple IDs have a 3-app limit

---

## Cost Considerations

### GitHub Actions (Free Tier)
- 2,000 minutes/month for private repos
- macOS runners use 10x multiplier
- ~15-20 min per build = ~150-200 "minutes"
- **Free tier allows ~10-13 builds/month**

### Apple Developer Account (Optional)
- $99/year for signed builds
- Required for TestFlight distribution
- Not needed for sideloading with tools like Sideloadly

---

## Future Improvements

Once you're ready to distribute more broadly:

1. **Add Apple Developer Account** - For proper code signing
2. **Set up TestFlight** - For beta distribution
3. **Add Fastlane** - For automated certificate management
4. **Automatic builds** - Trigger on push to main instead of manual

---

## Files Modified for iOS Support

- `ios/Runner/Info.plist` - Added permission descriptions
- `ios/Runner/Runner.entitlements` - Added NFC capability
- `ios/Runner.xcodeproj/project.pbxproj` - Updated bundle ID and entitlements
- `lib/firebase_options.dart` - Added iOS Firebase config
- `lib/services/nfc_service.dart` - Added iOS platform detection
- `lib/screens/home/home_screen.dart` - iOS-specific behavior
- `lib/widgets/home/nfc_fab_widget.dart` - iOS-specific UI text
- `.github/workflows/build-ios.yml` - CI/CD workflow
- `.gitignore` - Exclude sensitive files
