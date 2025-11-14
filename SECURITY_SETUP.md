# TapCard Security Setup Guide

Quick start guide for setting up security features in the TapCard application.

## Quick Setup (5 minutes)

### Step 1: Install Dependencies

```bash
flutter pub get
```

This will install the `flutter_dotenv` package needed for environment variables.

### Step 2: Create Environment File

```bash
# Copy the example file
cp .env.example .env
```

Edit `.env` and add your Firebase credentials:
```bash
FIREBASE_API_KEY=your_actual_firebase_api_key
FIREBASE_APP_ID=your_actual_firebase_app_id
FIREBASE_MESSAGING_SENDER_ID=your_actual_sender_id
FIREBASE_PROJECT_ID=your_actual_project_id
FIREBASE_STORAGE_BUCKET=your_actual_storage_bucket

# Set environment
APP_ENV=development  # Change to 'production' when deploying
```

**Where to find Firebase credentials:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click the gear icon → Project Settings
4. Scroll to "Your apps" → Select your app
5. Copy the values from the config object

### Step 3: Initialize Environment in main.dart

Update your `main.dart` file:

```dart
import 'package:flutter/material.dart';
import 'core/config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables FIRST
  await EnvConfig.init();

  // 2. Then initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: EnvConfig.firebaseApiKey,
      appId: EnvConfig.firebaseAppId,
      messagingSenderId: EnvConfig.firebaseMessagingSenderId,
      projectId: EnvConfig.firebaseProjectId,
      storageBucket: EnvConfig.firebaseStorageBucket,
    ),
  );

  // 3. Optional: Print config in development
  if (EnvConfig.isDevelopment) {
    EnvConfig.printConfig();
  }

  runApp(MyApp());
}
```

### Step 4: Deploy Firebase Security Rules

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done)
firebase init

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules
```

### Step 5: Test Security Rules (Optional but Recommended)

```bash
# Start Firebase emulators
firebase emulators:start

# Run your app against emulators
# The app will automatically connect to local emulators
```

## Files Created

### Security Services
- `lib/services/validation_service.dart` - Input validation
- `lib/services/rate_limiter.dart` - Rate limiting
- `lib/core/constants/security_constants.dart` - Security config
- `lib/core/config/env_config.dart` - Environment variables

### Firebase Rules
- `firestore.rules` - Database security rules
- `storage.rules` - File storage security rules

### Documentation
- `SECURITY_CHECKLIST.md` - Pre-deployment checklist
- `docs/SECURITY.md` - Comprehensive security docs
- `.env.example` - Environment template

## Using Security Features

### 1. Validate User Input

```dart
import 'package:tap_card/services/validation_service.dart';

// Validate profile update
final validation = ValidationService.validateProfileUpdate({
  'fullName': fullName,
  'email': email,
  'phone': phone,
});

if (!validation.isValid) {
  // Show errors to user
  showSnackbar(validation.errors.join('\n'));
  return;
}

// Proceed with update
await profileService.updateProfile(data);
```

### 2. Rate Limit Operations

```dart
import 'package:tap_card/services/rate_limiter.dart';

try {
  await RateLimiter().executeWithLimit(
    action: 'profile_update',
    task: () => profileService.updateProfile(data),
  );
  showSnackbar('Profile updated successfully!');
} on RateLimitException catch (e) {
  showSnackbar('Too many requests. ${e.message}');
}
```

### 3. Check Feature Flags

```dart
import 'package:tap_card/core/config/env_config.dart';

// Check if NFC is enabled
if (EnvConfig.featureNfcEnabled) {
  // Show NFC features
}

// Check environment
if (EnvConfig.isProduction) {
  // Production-specific code
}
```

## Pre-Deployment Checklist

Before deploying to production, review `SECURITY_CHECKLIST.md` and ensure:

- [ ] `.env` file is configured with production values
- [ ] `APP_ENV=production` in `.env`
- [ ] `ENABLE_DEBUG_LOGGING=false` in `.env`
- [ ] Firebase security rules deployed
- [ ] All validations tested
- [ ] Rate limiting enabled
- [ ] No hardcoded credentials in code
- [ ] `.env` is in `.gitignore` and NOT committed

## Common Issues

### "Missing required environment variable"
- Make sure you created `.env` from `.env.example`
- Verify all Firebase credentials are filled in
- Check that `.env` is in the root of your Flutter project
- Ensure `EnvConfig.init()` is called before accessing env vars

### "Permission denied" in Firebase
- Deploy your security rules: `firebase deploy --only firestore:rules`
- Check that user is authenticated
- Verify user is accessing their own data only

### Rate limit errors in development
- Set `ENABLE_RATE_LIMITING=false` in `.env` for development
- Or use `RateLimiter().clear()` to reset limits during testing

## Next Steps

1. Read `docs/SECURITY.md` for detailed documentation
2. Review `SECURITY_CHECKLIST.md` before deploying
3. Test all security features thoroughly
4. Set up error tracking (Sentry) for production
5. Schedule monthly security reviews

## Support

For security questions or issues:
- Check `docs/SECURITY.md` for detailed info
- Review `SECURITY_CHECKLIST.md` for common tasks
- Contact: [Your security email]

---

**Remember:** Never commit `.env` to version control!

**Quick verification:**
```bash
git status
# Make sure .env is NOT listed (should be in .gitignore)
```

Good luck, and stay secure! 🔒
