/// Firebase Test Service
///
/// Provides utilities for testing Firebase connectivity and functionality:
/// - Connection status checks
/// - Firestore read/write tests
/// - Storage upload tests
/// - Detailed error reporting
library;

import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';

/// Test result model
class FirebaseTestResult {
  final bool success;
  final String message;
  final String? errorDetails;
  final DateTime timestamp;
  final Duration? duration;

  FirebaseTestResult({
    required this.success,
    required this.message,
    this.errorDetails,
    DateTime? timestamp,
    this.duration,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'FirebaseTestResult{'
        'success: $success, '
        'message: $message, '
        'duration: ${duration?.inMilliseconds}ms, '
        'error: $errorDetails}';
  }
}

/// Service for testing Firebase connectivity and operations
class FirebaseTestService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  /// Test Firebase initialization status
  static FirebaseTestResult testInitialization() {
    try {
      final app = Firebase.app();
      final options = app.options;

      developer.log(
        '🔥 Firebase Initialization Test\n'
        '   • App Name: ${app.name}\n'
        '   • Project ID: ${options.projectId}\n'
        '   • Storage Bucket: ${options.storageBucket}',
        name: 'FirebaseTest.Init',
      );

      return FirebaseTestResult(
        success: true,
        message: 'Firebase initialized successfully',
        errorDetails: 'Project: ${options.projectId}',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Firebase initialization test failed',
        name: 'FirebaseTest.Init',
        error: e,
        stackTrace: stackTrace,
      );

      return FirebaseTestResult(
        success: false,
        message: 'Firebase not initialized',
        errorDetails: e.toString(),
      );
    }
  }

  /// Test Firestore connection (read access)
  static Future<FirebaseTestResult> testFirestoreRead() async {
    final startTime = DateTime.now();

    try {
      developer.log(
        '📖 Testing Firestore read access...',
        name: 'FirebaseTest.FirestoreRead',
      );

      // Try to read from a collection (any collection)
      final query = await _firestore
          .collection('profiles')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      final duration = DateTime.now().difference(startTime);

      developer.log(
        '✅ Firestore read test successful\n'
        '   • Duration: ${duration.inMilliseconds}ms\n'
        '   • Documents found: ${query.docs.length}',
        name: 'FirebaseTest.FirestoreRead',
      );

      return FirebaseTestResult(
        success: true,
        message: 'Firestore read access OK',
        errorDetails: 'Found ${query.docs.length} documents',
        duration: duration,
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);

      developer.log(
        '❌ Firestore read test failed',
        name: 'FirebaseTest.FirestoreRead',
        error: e,
        stackTrace: stackTrace,
      );

      return FirebaseTestResult(
        success: false,
        message: 'Firestore read failed',
        errorDetails: e.toString(),
        duration: duration,
      );
    }
  }

  /// Test Firestore connection (write access)
  static Future<FirebaseTestResult> testFirestoreWrite() async {
    final startTime = DateTime.now();

    try {
      developer.log(
        '📝 Testing Firestore write access...',
        name: 'FirebaseTest.FirestoreWrite',
      );

      final testDocId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      // Write a test document
      await _firestore.collection('_test').doc(testDocId).set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Firebase connection test',
      });

      // Read it back to verify
      final doc = await _firestore.collection('_test').doc(testDocId).get();

      // Clean up - delete test document
      await _firestore.collection('_test').doc(testDocId).delete();

      final duration = DateTime.now().difference(startTime);

      developer.log(
        '✅ Firestore write test successful\n'
        '   • Duration: ${duration.inMilliseconds}ms\n'
        '   • Document verified: ${doc.exists}',
        name: 'FirebaseTest.FirestoreWrite',
      );

      return FirebaseTestResult(
        success: true,
        message: 'Firestore write access OK',
        errorDetails: 'Test document created and deleted',
        duration: duration,
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);

      developer.log(
        '❌ Firestore write test failed',
        name: 'FirebaseTest.FirestoreWrite',
        error: e,
        stackTrace: stackTrace,
      );

      return FirebaseTestResult(
        success: false,
        message: 'Firestore write failed',
        errorDetails: e.toString(),
        duration: duration,
      );
    }
  }

  /// Test Storage connection
  static Future<FirebaseTestResult> testStorage() async {
    final startTime = DateTime.now();

    try {
      developer.log(
        '💾 Testing Firebase Storage access...',
        name: 'FirebaseTest.Storage',
      );

      // Try to list files in profile_images folder (read access)
      final ref = _storage.ref().child('profile_images');
      final result = await ref.listAll();

      final duration = DateTime.now().difference(startTime);

      developer.log(
        '✅ Storage access test successful\n'
        '   • Duration: ${duration.inMilliseconds}ms\n'
        '   • Files found: ${result.items.length}',
        name: 'FirebaseTest.Storage',
      );

      return FirebaseTestResult(
        success: true,
        message: 'Storage access OK',
        errorDetails: 'Found ${result.items.length} files',
        duration: duration,
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);

      developer.log(
        '❌ Storage access test failed',
        name: 'FirebaseTest.Storage',
        error: e,
        stackTrace: stackTrace,
      );

      return FirebaseTestResult(
        success: false,
        message: 'Storage access failed',
        errorDetails: e.toString(),
        duration: duration,
      );
    }
  }

  /// Run all Firebase tests
  static Future<Map<String, FirebaseTestResult>> runAllTests() async {
    developer.log(
      '🧪 Running complete Firebase test suite...',
      name: 'FirebaseTest.Suite',
    );

    final results = <String, FirebaseTestResult>{};

    // Test 1: Initialization
    results['initialization'] = testInitialization();

    // Test 2: Firestore Read
    results['firestoreRead'] = await testFirestoreRead();

    // Test 3: Firestore Write
    results['firestoreWrite'] = await testFirestoreWrite();

    // Test 4: Storage
    results['storage'] = await testStorage();

    // Summary
    final allPassed = results.values.every((result) => result.success);
    final passedCount = results.values.where((result) => result.success).length;

    developer.log(
      allPassed ? '✅ All Firebase tests passed!' : '⚠️ Some Firebase tests failed',
      name: 'FirebaseTest.Suite',
    );

    developer.log(
      '📊 Test Summary:\n'
      '   • Total Tests: ${results.length}\n'
      '   • Passed: $passedCount\n'
      '   • Failed: ${results.length - passedCount}',
      name: 'FirebaseTest.Suite',
    );

    return results;
  }

  /// Get Firebase project info
  static Map<String, String> getProjectInfo() {
    try {
      final app = Firebase.app();
      final options = app.options;

      return {
        'appName': app.name,
        'projectId': options.projectId,
        'storageBucket': options.storageBucket ?? 'N/A',
        'authDomain': options.authDomain ?? 'N/A',
        'messagingSenderId': options.messagingSenderId ?? 'N/A',
      };
    } catch (e) {
      return {
        'error': 'Firebase not initialized',
        'details': e.toString(),
      };
    }
  }

  /// Check if Firebase is ready for use
  static Future<bool> isFirebaseReady() async {
    try {
      // Quick check: Can we read from Firestore?
      await _firestore
          .collection('profiles')
          .limit(1)
          .get(const GetOptions(source: Source.server, serverTimestampBehavior: ServerTimestampBehavior.estimate));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get connection health status
  static Future<String> getConnectionHealth() async {
    try {
      final startTime = DateTime.now();
      await _firestore
          .collection('profiles')
          .limit(1)
          .get(const GetOptions(source: Source.server));
      final latency = DateTime.now().difference(startTime).inMilliseconds;

      if (latency < 500) {
        return 'Excellent (${latency}ms)';
      } else if (latency < 1000) {
        return 'Good (${latency}ms)';
      } else if (latency < 2000) {
        return 'Fair (${latency}ms)';
      } else {
        return 'Slow (${latency}ms)';
      }
    } catch (e) {
      return 'Offline';
    }
  }
}
