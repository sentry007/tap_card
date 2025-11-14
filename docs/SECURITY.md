# TapCard Security Documentation

This document provides a comprehensive overview of security measures implemented in the TapCard application.

## Table of Contents

1. [Security Architecture](#security-architecture)
2. [Authentication & Authorization](#authentication--authorization)
3. [Data Validation](#data-validation)
4. [Rate Limiting](#rate-limiting)
5. [Firebase Security Rules](#firebase-security-rules)
6. [Environment Configuration](#environment-configuration)
7. [Privacy & Compliance](#privacy--compliance)
8. [Best Practices](#best-practices)
9. [Security Testing](#security-testing)

---

## Security Architecture

### Defense in Depth

TapCard implements multiple layers of security:

```
┌─────────────────────────────────────────┐
│  Layer 1: Client-Side Validation       │  ← ValidationService
├─────────────────────────────────────────┤
│  Layer 2: Rate Limiting                 │  ← RateLimiter
├─────────────────────────────────────────┤
│  Layer 3: Firebase Authentication      │  ← Auth Guards
├─────────────────────────────────────────┤
│  Layer 4: Firestore Security Rules     │  ← Server-Side Rules
├─────────────────────────────────────────┤
│  Layer 5: Storage Security Rules       │  ← File Upload Rules
└─────────────────────────────────────────┘
```

### Key Security Components

1. **ValidationService** (`lib/services/validation_service.dart`)
   - Validates all user inputs before processing
   - Prevents injection attacks and malformed data
   - Enforces size limits and allowed characters

2. **RateLimiter** (`lib/services/rate_limiter.dart`)
   - Prevents API abuse and DoS attacks
   - Configurable per-action limits
   - Automatic lockout on excessive requests

3. **SecurityConstants** (`lib/core/constants/security_constants.dart`)
   - Centralized security configuration
   - Validation patterns and size limits
   - Rate limit thresholds

4. **EnvConfig** (`lib/core/config/env_config.dart`)
   - Secure environment variable management
   - No hardcoded credentials
   - Environment-specific configuration

---

## Authentication & Authorization

### Firebase Authentication

- **Provider:** Google Sign-In (OAuth 2.0)
- **Session Duration:** 24 hours
- **Token Refresh:** Every 1 hour
- **Logout:** Automatic on session timeout

### Authorization Model

```dart
// Users can only access their own data
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### User Permissions

| Resource | Owner | Other Users | Anonymous |
|----------|-------|-------------|-----------|
| Profile (private) | Read/Write | None | None |
| Profile (public) | Read/Write | Read | Read |
| Images | Read/Write | None | None |
| Analytics | Read/Write | None | None |

---

## Data Validation

### ValidationService

All user inputs are validated using `ValidationService` before being sent to Firebase.

#### Validated Fields

```dart
// Example: Profile Update
final validation = ValidationService.validateProfileUpdate({
  'fullName': 'John Doe',           // ✓ Alphanumeric + safe chars
  'email': 'john@example.com',      // ✓ Valid email format
  'phone': '+1234567890',           // ✓ International format
  'imageUrl': 'https://...',        // ✓ HTTPS URL
});

if (!validation.isValid) {
  print(validation.errors); // Show user-friendly errors
}
```

#### Validation Rules

| Field | Max Length | Pattern | Special Rules |
|-------|------------|---------|---------------|
| Name | 100 chars | `[a-zA-Z0-9\s\-'.]` | No special chars |
| Email | 255 chars | RFC 5322 | Must have @ and domain |
| Phone | 20 chars | `\+?[\d]{10,15}` | International format |
| URL | 2048 chars | `https?://...` | Must be HTTP/HTTPS |
| NFC Payload | 10 KB | Binary | Size limit enforced |

#### File Upload Validation

```dart
// Image upload validation
ValidationService.validateImageUpload(
  fileBytes: imageBytes,
  fileName: 'profile.jpg',
  mimeType: 'image/jpeg',
);

// Checks:
// ✓ File size ≤ 5MB
// ✓ Extension: jpg, jpeg, png, webp
// ✓ MIME type matches extension
// ✓ No executable files
```

---

## Rate Limiting

### RateLimiter Service

Prevents abuse by limiting requests per user per time window.

#### Rate Limits

| Action | Max Requests | Time Window | Lockout Duration |
|--------|--------------|-------------|------------------|
| Profile Update | 10 | 1 minute | 5 minutes |
| Image Upload | 20 | 1 hour | 1 hour |
| Firestore Read | 50 | 1 minute | 2 minutes |
| Firestore Write | 20 | 1 minute | 5 minutes |
| NFC Write | 5 | 1 minute | 5 minutes |
| NFC Read | 30 | 1 minute | 2 minutes |

#### Usage Example

```dart
// Automatic rate limiting
try {
  await RateLimiter().executeWithLimit(
    action: 'profile_update',
    task: () => profileService.updateProfile(data),
  );
} on RateLimitException catch (e) {
  showError('Too many requests. Try again in ${e.retryAfter}');
}
```

#### Rate Limit Response

When rate limit is exceeded:
- User-friendly error message
- Countdown until retry allowed
- Automatic unlock after lockout period

---

## Firebase Security Rules

### Firestore Rules

Located in: `firestore.rules`

#### Key Rules

1. **Authentication Required**
   ```javascript
   // All operations require authentication
   match /{document=**} {
     allow read, write: if request.auth != null;
   }
   ```

2. **User Data Isolation**
   ```javascript
   // Users can only modify their own data
   match /users/{userId} {
     allow write: if request.auth.uid == userId;
   }
   ```

3. **Data Validation**
   ```javascript
   // Server-side validation
   allow create: if
     request.resource.data.fullName is string &&
     request.resource.data.fullName.size() <= 100 &&
     request.resource.data.email.matches('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
   ```

4. **Rate Limiting**
   ```javascript
   // Max 10 writes per minute
   allow write: if
     request.time > resource.data.lastUpdate + duration.value(6, 's');
   ```

### Storage Rules

Located in: `storage.rules`

#### Key Rules

1. **Authentication Required**
   ```javascript
   allow read, write: if request.auth != null;
   ```

2. **File Type Validation**
   ```javascript
   allow write: if
     request.resource.contentType.matches('image/(jpeg|png|webp)');
   ```

3. **File Size Limit**
   ```javascript
   allow write: if
     request.resource.size < 5 * 1024 * 1024; // 5MB
   ```

4. **User Path Isolation**
   ```javascript
   // Users can only upload to their own folder
   match /users/{userId}/{allPaths=**} {
     allow write: if request.auth.uid == userId;
   }
   ```

---

## Environment Configuration

### .env File Setup

**NEVER commit `.env` to version control!**

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in your Firebase credentials:
   ```bash
   FIREBASE_API_KEY=your_actual_api_key
   FIREBASE_APP_ID=your_actual_app_id
   # ... etc
   ```

3. Set environment:
   ```bash
   APP_ENV=production
   ENFORCE_HTTPS=true
   ENABLE_DEBUG_LOGGING=false
   ```

### Security Configuration

```bash
# Production Settings (REQUIRED)
APP_ENV=production
ENFORCE_HTTPS=true
ENABLE_DEBUG_LOGGING=false
ENABLE_RATE_LIMITING=true

# Development Settings (for testing)
APP_ENV=development
ENFORCE_HTTPS=false
ENABLE_DEBUG_LOGGING=true
ENABLE_RATE_LIMITING=false
```

### Loading Environment Variables

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await EnvConfig.init();

  // Initialize Firebase with env config
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: EnvConfig.firebaseApiKey,
      appId: EnvConfig.firebaseAppId,
      // ... etc
    ),
  );

  runApp(MyApp());
}
```

---

## Privacy & Compliance

### GDPR Compliance

TapCard is GDPR-compliant with the following features:

1. **User Consent**
   - Privacy policy displayed on first launch
   - Explicit consent for data collection
   - Analytics opt-out available

2. **Data Export**
   - Users can export all their data
   - JSON format for portability
   - Includes all profile and analytics data

3. **Right to Deletion**
   - Users can delete their account
   - All data permanently removed
   - Cascading delete for related data

4. **Data Minimization**
   - Only collect necessary data
   - No excessive tracking
   - Clear purpose for each data point

### Data Privacy Features

```dart
// Export user data
await PrivacyService.exportUserData(userId);

// Delete account
await PrivacyService.deleteAccount(userId);

// Opt-out of analytics
await PrivacyService.disableAnalytics();
```

### What We Collect

| Data | Purpose | Shared? |
|------|---------|---------|
| Name | Profile display | No |
| Email | Authentication | No |
| Phone | Contact info | User choice |
| Profile image | Visual identity | User choice |
| Usage analytics | App improvement | Anonymized |
| NFC interactions | Feature functionality | No |

---

## Best Practices

### For Developers

1. **Never Hardcode Credentials**
   ```dart
   // ❌ BAD
   final apiKey = 'AIza...1234';

   // ✅ GOOD
   final apiKey = EnvConfig.firebaseApiKey;
   ```

2. **Always Validate Inputs**
   ```dart
   // ❌ BAD
   await firestore.collection('users').doc(uid).update(data);

   // ✅ GOOD
   final validation = ValidationService.validateProfileUpdate(data);
   if (validation.isValid) {
     await firestore.collection('users').doc(uid).update(data);
   }
   ```

3. **Use Rate Limiting**
   ```dart
   // ❌ BAD
   await uploadImage(file);

   // ✅ GOOD
   await RateLimiter().executeWithLimit(
     action: 'image_upload',
     task: () => uploadImage(file),
   );
   ```

4. **Handle Errors Gracefully**
   ```dart
   // ❌ BAD
   print('Error: ${error.toString()}'); // May expose sensitive data

   // ✅ GOOD
   logger.error('Profile update failed', error); // Sanitized logging
   showError('Could not update profile. Please try again.');
   ```

5. **Test Security Rules**
   ```bash
   # Always test with Firebase emulator
   firebase emulators:start
   ```

### For Users

1. **Keep App Updated**
   - Install security updates promptly
   - Check for updates weekly

2. **Review Permissions**
   - Only grant necessary permissions
   - Review privacy settings regularly

3. **Report Issues**
   - Report suspicious activity
   - Contact support for security concerns

---

## Security Testing

### Manual Testing Checklist

- [ ] Try accessing another user's data (should fail)
- [ ] Try uploading oversized file (should fail)
- [ ] Try uploading non-image file (should fail)
- [ ] Try XSS in name field (should be sanitized)
- [ ] Try SQL injection in inputs (should be blocked)
- [ ] Exceed rate limit (should lockout)
- [ ] Try invalid email format (should reject)

### Automated Testing

```dart
// Unit test for validation
test('should reject invalid email', () {
  final result = ValidationService.validateEmail('invalid-email');
  expect(result.isValid, false);
  expect(result.errors, contains('Invalid email format'));
});

// Integration test for rate limiting
test('should enforce rate limit', () async {
  final limiter = RateLimiter();

  // Make 10 requests (limit)
  for (int i = 0; i < 10; i++) {
    await limiter.executeWithLimit(
      action: 'test_action',
      task: () => Future.value(),
    );
  }

  // 11th request should fail
  expect(
    () => limiter.executeWithLimit(
      action: 'test_action',
      task: () => Future.value(),
    ),
    throwsA(isA<RateLimitException>()),
  );
});
```

### Penetration Testing

For production deployments, consider:
- Third-party security audit
- Automated vulnerability scanning
- Penetration testing by security experts

---

## Incident Response

### If You Discover a Security Issue

1. **Don't Panic**
   - Document what you found
   - Don't disclose publicly yet

2. **Assess Impact**
   - How severe is it?
   - Who is affected?
   - What data is at risk?

3. **Report Immediately**
   - Contact: [Your security email]
   - Include: Steps to reproduce, impact assessment

4. **Follow Up**
   - Work with team on fix
   - Test thoroughly
   - Deploy to production
   - Notify affected users if needed

---

## Security Updates

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-14 | 1.0.0 | Initial security implementation |

---

## Contact

For security concerns or questions:
- **Email:** [Your security email]
- **Response Time:** 24-48 hours
- **Emergency:** [Your emergency contact]

---

**Remember:** Security is a continuous process. Stay vigilant, keep learning, and always prioritize user privacy and data protection.

**Last Updated:** 2025-11-14
**Next Review:** Monthly
