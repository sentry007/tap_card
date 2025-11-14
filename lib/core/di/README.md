# Dependency Injection Setup

## Overview
This app uses **GetIt** for dependency injection, following clean architecture principles.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│  UI Layer (Widgets/Screens)            │
├─────────────────────────────────────────┤
│  Services Layer (Business Logic)       │  ← ProfileService, AuthService
├─────────────────────────────────────────┤
│  Repository Layer (Data Access)        │  ← Firebase, Local, etc.
├─────────────────────────────────────────┤
│  Data Sources (Firebase, SharedPrefs)  │
└─────────────────────────────────────────┘
```

## Usage

### 1. Initialize at App Startup

In `main.dart`:

```dart
import 'package:tap_card/core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize DI container
  await setupServiceLocator();

  runApp(MyApp());
}
```

### 2. Access Services

```dart
import 'package:tap_card/core/di/service_locator.dart';

// Get repository instance
final profileRepo = getIt<ProfileRepository>();

// Get service instance
final authService = getIt<AuthService>();
```

### 3. Testing with Mocks

```dart
import 'package:tap_card/core/di/service_locator.dart';

void main() {
  setUp(() async {
    await setupMockServiceLocator(
      profileRepository: MockProfileRepository(),
      authRepository: MockAuthRepository(),
    );
  });

  tearDown(() async {
    await resetServiceLocator();
  });

  test('example test', () {
    final service = getIt<ProfileService>();
    // Test with mocked dependencies
  });
}
```

## Registered Dependencies

### Repositories
- `ProfileRepository` → FirebaseProfileRepository
- `LocalProfileRepository` → LocalProfileRepository
- `AuthRepository` → FirebaseAuthRepository
- `StorageRepository` → FirebaseStorageRepository

### Services
- `ProfileService` (uses ProfileRepository)
- `AuthService` (uses AuthRepository)

## Benefits

✅ **Testable** - Easy to inject mocks
✅ **Flexible** - Swap implementations without changing code
✅ **Clear Dependencies** - Explicit dependency graph
✅ **Single Source of Truth** - All dependencies in one place
