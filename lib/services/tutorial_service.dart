/// Tutorial Service
///
/// Manages tutorial state and progress for interactive user onboarding.
/// Supports automatic first-time tutorial and manual re-triggering from settings.
library;

import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _keyTutorialCompleted = 'tutorial_completed';
  static const String _keyTutorialCurrentStep = 'tutorial_current_step';
  static const String _keyTutorialSkipped = 'tutorial_skipped';
  static const String _keyAutoShowTutorial = 'auto_show_tutorial';

  static SharedPreferences? _prefs;

  /// Initialize the tutorial service
  static Future<void> initialize() async {
    if (_prefs != null) return;

    _prefs = await SharedPreferences.getInstance();
    developer.log('📚 TutorialService initialized', name: 'TutorialService');
  }

  /// Check if tutorial has been completed
  static Future<bool> hasCompletedTutorial() async {
    await initialize();
    return _prefs?.getBool(_keyTutorialCompleted) ?? false;
  }

  /// Check if tutorial was skipped
  static Future<bool> wasTutorialSkipped() async {
    await initialize();
    return _prefs?.getBool(_keyTutorialSkipped) ?? false;
  }

  /// Get current tutorial step (for resuming)
  static Future<int> getCurrentStep() async {
    await initialize();
    return _prefs?.getInt(_keyTutorialCurrentStep) ?? 0;
  }

  /// Check if auto-show tutorial is enabled
  static Future<bool> isAutoShowEnabled() async {
    await initialize();
    return _prefs?.getBool(_keyAutoShowTutorial) ?? true; // Default: enabled
  }

  /// Mark tutorial as completed
  static Future<void> markTutorialCompleted() async {
    await initialize();
    await _prefs?.setBool(_keyTutorialCompleted, true);
    await _prefs?.setInt(_keyTutorialCurrentStep, 0);
    developer.log('✅ Tutorial marked as completed', name: 'TutorialService');
  }

  /// Mark tutorial as skipped
  static Future<void> markTutorialSkipped() async {
    await initialize();
    await _prefs?.setBool(_keyTutorialSkipped, true);
    await _prefs?.setBool(_keyTutorialCompleted, true); // Don't show again
    developer.log('⏭️  Tutorial skipped by user', name: 'TutorialService');
  }

  /// Save current tutorial step
  static Future<void> saveCurrentStep(int step) async {
    await initialize();
    await _prefs?.setInt(_keyTutorialCurrentStep, step);
    developer.log('💾 Saved tutorial progress: Step $step', name: 'TutorialService');
  }

  /// Reset tutorial (for manual restart from settings)
  static Future<void> resetTutorial() async {
    await initialize();
    await _prefs?.setBool(_keyTutorialCompleted, false);
    await _prefs?.setBool(_keyTutorialSkipped, false);
    await _prefs?.setInt(_keyTutorialCurrentStep, 0);
    developer.log('🔄 Tutorial reset - ready to show again', name: 'TutorialService');
  }

  /// Set auto-show tutorial preference
  static Future<void> setAutoShowEnabled(bool enabled) async {
    await initialize();
    await _prefs?.setBool(_keyAutoShowTutorial, enabled);
    developer.log('⚙️  Auto-show tutorial: $enabled', name: 'TutorialService');
  }

  /// Check if tutorial should be shown (not completed and auto-show enabled)
  static Future<bool> shouldShowTutorial() async {
    final completed = await hasCompletedTutorial();
    final autoShow = await isAutoShowEnabled();

    final shouldShow = !completed && autoShow;
    developer.log(
      '🎓 Should show tutorial: $shouldShow (completed: $completed, autoShow: $autoShow)',
      name: 'TutorialService',
    );

    return shouldShow;
  }

  /// Get tutorial progress percentage (0-100)
  static Future<int> getTutorialProgress() async {
    final completed = await hasCompletedTutorial();
    if (completed) return 100;

    final currentStep = await getCurrentStep();
    const totalSteps = 8; // Total number of tutorial steps

    return ((currentStep / totalSteps) * 100).round();
  }

  /// Clear all tutorial data (for debugging/testing)
  static Future<void> clearAllData() async {
    await initialize();
    await _prefs?.remove(_keyTutorialCompleted);
    await _prefs?.remove(_keyTutorialCurrentStep);
    await _prefs?.remove(_keyTutorialSkipped);
    await _prefs?.remove(_keyAutoShowTutorial);
    developer.log('🗑️  All tutorial data cleared', name: 'TutorialService');
  }
}
