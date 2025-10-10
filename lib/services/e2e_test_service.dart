/// End-to-End Test Service
///
/// Automated testing of complete Firebase integration flow:
/// - Generate test profile
/// - Sync to Firestore
/// - Verify sync success
/// - Validate website URL
/// - Generate comprehensive test report
library;

import 'dart:developer' as developer;
import 'package:tap_card/core/models/profile_models.dart';
import 'package:tap_card/services/firebase_test_service.dart';
import 'package:tap_card/services/mock_data_generator.dart';
import 'package:tap_card/services/firestore_sync_service.dart';

/// Individual test step result
class TestStepResult {
  final String stepName;
  final bool passed;
  final String message;
  final String? errorDetails;
  final Duration duration;

  TestStepResult({
    required this.stepName,
    required this.passed,
    required this.message,
    this.errorDetails,
    required this.duration,
  });

  @override
  String toString() {
    return '${passed ? "✅" : "❌"} $stepName: $message (${duration.inMilliseconds}ms)';
  }
}

/// Complete E2E test result
class E2ETestResult {
  final List<TestStepResult> steps;
  final bool allPassed;
  final Duration totalDuration;
  final ProfileData? testProfile;
  final String? websiteUrl;

  E2ETestResult({
    required this.steps,
    required this.allPassed,
    required this.totalDuration,
    this.testProfile,
    this.websiteUrl,
  });

  int get passedCount => steps.where((step) => step.passed).length;
  int get failedCount => steps.where((step) => !step.passed).length;
  int get totalSteps => steps.length;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('🧪 E2E Test Results:');
    buffer.writeln('   • Total Steps: $totalSteps');
    buffer.writeln('   • Passed: $passedCount');
    buffer.writeln('   • Failed: $failedCount');
    buffer.writeln('   • Duration: ${totalDuration.inSeconds}s');
    buffer.writeln('   • Overall: ${allPassed ? "✅ PASS" : "❌ FAIL"}');

    if (websiteUrl != null) {
      buffer.writeln('\n🌐 Test Profile URL:');
      buffer.writeln('   $websiteUrl');
    }

    buffer.writeln('\n📋 Steps:');
    for (final step in steps) {
      buffer.writeln('   $step');
    }

    return buffer.toString();
  }
}

/// Service for running end-to-end integration tests
class E2ETestService {
  /// Run complete end-to-end test flow
  static Future<E2ETestResult> runCompleteTest() async {
    final startTime = DateTime.now();
    final steps = <TestStepResult>[];
    ProfileData? testProfile;
    String? websiteUrl;

    developer.log(
      '🧪 Starting end-to-end integration test...',
      name: 'E2ETest.Start',
    );

    // Step 1: Check Firebase initialization
    final step1Start = DateTime.now();
    final initResult = FirebaseTestService.testInitialization();
    steps.add(TestStepResult(
      stepName: 'Firebase Initialization',
      passed: initResult.success,
      message: initResult.message,
      errorDetails: initResult.errorDetails,
      duration: DateTime.now().difference(step1Start),
    ));

    if (!initResult.success) {
      return _completeTest(steps, startTime, null, null);
    }

    // Step 2: Test Firestore connection
    final step2Start = DateTime.now();
    final firestoreResult = await FirebaseTestService.testFirestoreRead();
    steps.add(TestStepResult(
      stepName: 'Firestore Connection',
      passed: firestoreResult.success,
      message: firestoreResult.message,
      errorDetails: firestoreResult.errorDetails,
      duration: DateTime.now().difference(step2Start),
    ));

    if (!firestoreResult.success) {
      return _completeTest(steps, startTime, null, null);
    }

    // Step 3: Generate test profile
    final step3Start = DateTime.now();
    try {
      testProfile = MockDataGenerator.generatePersonalProfile();
      testProfile = testProfile.regenerateDualPayloadCache();

      steps.add(TestStepResult(
        stepName: 'Generate Test Profile',
        passed: true,
        message: 'Created profile: ${testProfile.name}',
        errorDetails: 'ID: ${testProfile.id}',
        duration: DateTime.now().difference(step3Start),
      ));
    } catch (e) {
      steps.add(TestStepResult(
        stepName: 'Generate Test Profile',
        passed: false,
        message: 'Failed to generate profile',
        errorDetails: e.toString(),
        duration: DateTime.now().difference(step3Start),
      ));
      return _completeTest(steps, startTime, null, null);
    }

    // Step 4: Sync to Firestore
    final step4Start = DateTime.now();
    try {
      final syncResult = await FirestoreSyncService.syncProfileToFirestore(testProfile);
      final syncSuccess = syncResult != null;

      steps.add(TestStepResult(
        stepName: 'Sync to Firestore',
        passed: syncSuccess,
        message: syncSuccess ? 'Profile synced successfully' : 'Sync failed',
        errorDetails: syncSuccess ? 'Profile uploaded to Firestore' : 'Check logs for details',
        duration: DateTime.now().difference(step4Start),
      ));

      if (!syncSuccess) {
        return _completeTest(steps, startTime, testProfile, null);
      }
    } catch (e) {
      steps.add(TestStepResult(
        stepName: 'Sync to Firestore',
        passed: false,
        message: 'Sync error',
        errorDetails: e.toString(),
        duration: DateTime.now().difference(step4Start),
      ));
      return _completeTest(steps, startTime, testProfile, null);
    }

    // Step 5: Verify sync (read back from Firestore)
    final step5Start = DateTime.now();
    try {
      final fetchedProfile = await FirestoreSyncService.fetchProfileFromFirestore(testProfile.id);

      final verified = fetchedProfile != null &&
          fetchedProfile.name == testProfile.name &&
          fetchedProfile.id == testProfile.id;

      steps.add(TestStepResult(
        stepName: 'Verify Sync',
        passed: verified,
        message: verified ? 'Profile verified in Firestore' : 'Verification failed',
        errorDetails: verified ? 'Data matches original profile' : 'Profile not found or data mismatch',
        duration: DateTime.now().difference(step5Start),
      ));

      if (!verified) {
        return _completeTest(steps, startTime, testProfile, null);
      }
    } catch (e) {
      steps.add(TestStepResult(
        stepName: 'Verify Sync',
        passed: false,
        message: 'Verification error',
        errorDetails: e.toString(),
        duration: DateTime.now().difference(step5Start),
      ));
      return _completeTest(steps, startTime, testProfile, null);
    }

    // Step 6: Generate and validate website URL
    final step6Start = DateTime.now();
    try {
      websiteUrl = MockDataGenerator.getWebsiteUrl(testProfile.id);
      final expectedPattern = RegExp(r'^https://tap-card-site\.vercel\.app/share/test_personal_\d+_\d+$');
      final urlValid = expectedPattern.hasMatch(websiteUrl);

      steps.add(TestStepResult(
        stepName: 'Website URL Generation',
        passed: urlValid,
        message: urlValid ? 'URL generated correctly' : 'URL format invalid',
        errorDetails: websiteUrl,
        duration: DateTime.now().difference(step6Start),
      ));
    } catch (e) {
      steps.add(TestStepResult(
        stepName: 'Website URL Generation',
        passed: false,
        message: 'URL generation failed',
        errorDetails: e.toString(),
        duration: DateTime.now().difference(step6Start),
      ));
    }

    return _completeTest(steps, startTime, testProfile, websiteUrl);
  }

  /// Quick smoke test (minimal checks)
  static Future<E2ETestResult> runQuickTest() async {
    final startTime = DateTime.now();
    final steps = <TestStepResult>[];

    developer.log(
      '⚡ Running quick smoke test...',
      name: 'E2ETest.Quick',
    );

    // Test 1: Firebase initialized
    final step1Start = DateTime.now();
    final initResult = FirebaseTestService.testInitialization();
    steps.add(TestStepResult(
      stepName: 'Firebase Init',
      passed: initResult.success,
      message: initResult.message,
      duration: DateTime.now().difference(step1Start),
    ));

    // Test 2: Firestore accessible
    final step2Start = DateTime.now();
    final firestoreReady = await FirebaseTestService.isFirebaseReady();
    steps.add(TestStepResult(
      stepName: 'Firestore Ready',
      passed: firestoreReady,
      message: firestoreReady ? 'Firestore accessible' : 'Firestore not accessible',
      duration: DateTime.now().difference(step2Start),
    ));

    return _completeTest(steps, startTime, null, null);
  }

  /// Helper to complete test and calculate results
  static E2ETestResult _completeTest(
    List<TestStepResult> steps,
    DateTime startTime,
    ProfileData? testProfile,
    String? websiteUrl,
  ) {
    final allPassed = steps.every((step) => step.passed);
    final totalDuration = DateTime.now().difference(startTime);

    final result = E2ETestResult(
      steps: steps,
      allPassed: allPassed,
      totalDuration: totalDuration,
      testProfile: testProfile,
      websiteUrl: websiteUrl,
    );

    developer.log(
      result.toString(),
      name: 'E2ETest.Complete',
    );

    return result;
  }

  /// Run connectivity tests only (no profile creation)
  static Future<E2ETestResult> runConnectivityTest() async {
    final startTime = DateTime.now();
    final steps = <TestStepResult>[];

    developer.log(
      '🔌 Running connectivity test...',
      name: 'E2ETest.Connectivity',
    );

    // Run all Firebase connectivity tests
    final testResults = await FirebaseTestService.runAllTests();

    for (final entry in testResults.entries) {
      steps.add(TestStepResult(
        stepName: entry.key,
        passed: entry.value.success,
        message: entry.value.message,
        errorDetails: entry.value.errorDetails,
        duration: entry.value.duration ?? Duration.zero,
      ));
    }

    return _completeTest(steps, startTime, null, null);
  }
}
