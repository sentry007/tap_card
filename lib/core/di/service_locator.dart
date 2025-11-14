/// Service Locator (Dependency Injection Container)
///
/// Centralized dependency injection using GetIt
/// Manages all service and repository instances
///
/// Benefits:
/// - Single source of truth for dependencies
/// - Easy to swap implementations (e.g., mock for testing)
/// - Clear dependency graph
library;

import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Repositories
import '../repositories/profile_repository.dart';
import '../repositories/local_profile_repository.dart';
import '../repositories/firebase_profile_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../repositories/storage_repository.dart';
import '../repositories/firebase_storage_repository.dart';

// Services
import '../services/profile_service.dart';
import '../services/auth_service.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Initialize dependency injection container
///
/// Call this ONCE at app startup (in main.dart)
/// before using any services or repositories
Future<void> setupServiceLocator() async {
  // ========== Firebase Instances (Singletons) ==========
  // These are provided by Firebase and should be singletons

  getIt.registerLazySingleton<FirebaseAuth>(
    () => FirebaseAuth.instance,
  );

  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );

  getIt.registerLazySingleton<FirebaseStorage>(
    () => FirebaseStorage.instance,
  );

  getIt.registerLazySingleton<GoogleSignIn>(
    () => GoogleSignIn(),
  );

  // ========== Repositories ==========
  // Repositories handle data access

  // Local Profile Repository (SharedPreferences)
  getIt.registerLazySingleton<LocalProfileRepository>(
    () => LocalProfileRepository(),
  );

  // Firebase Profile Repository (Firestore + Storage)
  getIt.registerLazySingleton<FirebaseProfileRepository>(
    () => FirebaseProfileRepository(
      firestore: getIt<FirebaseFirestore>(),
      storage: getIt<FirebaseStorage>(),
    ),
  );

  // Profile Repository (defaults to Firebase, falls back to local)
  // This is the main repository used by services
  getIt.registerLazySingleton<ProfileRepository>(
    () => getIt<FirebaseProfileRepository>(),
  );

  // Auth Repository
  getIt.registerLazySingleton<AuthRepository>(
    () => FirebaseAuthRepository(
      auth: getIt<FirebaseAuth>(),
      googleSignIn: getIt<GoogleSignIn>(),
    ),
  );

  // Storage Repository
  getIt.registerLazySingleton<StorageRepository>(
    () => FirebaseStorageRepository(
      storage: getIt<FirebaseStorage>(),
    ),
  );

  // ========== Services ==========
  // Services handle business logic

  // Profile Service (uses repositories)
  getIt.registerLazySingleton<ProfileService>(
    () => ProfileService.withDependencies(
      profileRepository: getIt<ProfileRepository>(),
      localRepository: getIt<LocalProfileRepository>(),
      authRepository: getIt<AuthRepository>(),
    ),
  );

  // Auth Service (uses repositories)
  getIt.registerLazySingleton<AuthService>(
    () => AuthService.withDependencies(
      authRepository: getIt<AuthRepository>(),
    ),
  );
}

/// Reset service locator (for testing only)
///
/// Clears all registered dependencies
/// Use in tearDown() of tests
Future<void> resetServiceLocator() async {
  await getIt.reset();
}

/// Register mock dependencies (for testing only)
///
/// Example usage:
/// ```dart
/// setupMockServiceLocator(
///   profileRepository: MockProfileRepository(),
///   authRepository: MockAuthRepository(),
/// );
/// ```
Future<void> setupMockServiceLocator({
  ProfileRepository? profileRepository,
  LocalProfileRepository? localRepository,
  AuthRepository? authRepository,
  StorageRepository? storageRepository,
}) async {
  // Reset first
  await resetServiceLocator();

  // Register mocks
  if (profileRepository != null) {
    getIt.registerLazySingleton<ProfileRepository>(() => profileRepository);
  }

  if (localRepository != null) {
    getIt.registerLazySingleton<LocalProfileRepository>(() => localRepository);
  }

  if (authRepository != null) {
    getIt.registerLazySingleton<AuthRepository>(() => authRepository);
  }

  if (storageRepository != null) {
    getIt.registerLazySingleton<StorageRepository>(() => storageRepository);
  }

  // Register services with mocked dependencies
  getIt.registerLazySingleton<ProfileService>(
    () => ProfileService.withDependencies(
      profileRepository: getIt<ProfileRepository>(),
      localRepository: getIt<LocalProfileRepository>(),
      authRepository: getIt<AuthRepository>(),
    ),
  );

  getIt.registerLazySingleton<AuthService>(
    () => AuthService.withDependencies(
      authRepository: getIt<AuthRepository>(),
    ),
  );
}
