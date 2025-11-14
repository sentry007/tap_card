/// Privacy Service
///
/// Handles GDPR-compliant privacy features:
/// - User consent management
/// - Data export
/// - Account deletion
/// - Analytics opt-out
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth_service.dart';

/// Privacy consent status
class ConsentStatus {
  final bool analyticsConsent;
  final bool dataProcessingConsent;
  final DateTime consentDate;

  ConsentStatus({
    required this.analyticsConsent,
    required this.dataProcessingConsent,
    required this.consentDate,
  });

  Map<String, dynamic> toJson() => {
        'analyticsConsent': analyticsConsent,
        'dataProcessingConsent': dataProcessingConsent,
        'consentDate': consentDate.toIso8601String(),
      };

  factory ConsentStatus.fromJson(Map<String, dynamic> json) {
    return ConsentStatus(
      analyticsConsent: json['analyticsConsent'] ?? false,
      dataProcessingConsent: json['dataProcessingConsent'] ?? false,
      consentDate: DateTime.parse(json['consentDate']),
    );
  }
}

/// Privacy service for GDPR compliance
class PrivacyService {
  static const String _consentKey = 'user_consent';
  static const String _analyticsOptOutKey = 'analytics_opt_out';

  // ========== Consent Management ==========

  /// Check if user has given consent
  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_consentKey);
  }

  /// Get current consent status
  Future<ConsentStatus?> getConsentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final consentJson = prefs.getString(_consentKey);

    if (consentJson == null) return null;

    try {
      return ConsentStatus.fromJson(jsonDecode(consentJson));
    } catch (e) {
      developer.log(
        '❌ Error parsing consent: $e',
        name: 'PrivacyService.GetConsent',
      );
      return null;
    }
  }

  /// Save user consent
  Future<void> saveConsent({
    required bool analyticsConsent,
    required bool dataProcessingConsent,
  }) async {
    final consent = ConsentStatus(
      analyticsConsent: analyticsConsent,
      dataProcessingConsent: dataProcessingConsent,
      consentDate: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_consentKey, jsonEncode(consent.toJson()));

    developer.log(
      '✅ User consent saved\n'
      '   • Analytics: $analyticsConsent\n'
      '   • Data Processing: $dataProcessingConsent',
      name: 'PrivacyService.SaveConsent',
    );

    // Also save to Firestore for backup
    final uid = AuthService().uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('privacy')
          .doc('consent')
          .set(consent.toJson());
    }
  }

  /// Update consent preferences
  Future<void> updateConsent({
    bool? analyticsConsent,
    bool? dataProcessingConsent,
  }) async {
    final currentConsent = await getConsentStatus();
    if (currentConsent == null) {
      throw Exception('No existing consent found');
    }

    await saveConsent(
      analyticsConsent: analyticsConsent ?? currentConsent.analyticsConsent,
      dataProcessingConsent:
          dataProcessingConsent ?? currentConsent.dataProcessingConsent,
    );
  }

  // ========== Analytics Opt-Out ==========

  /// Check if analytics is enabled
  Future<bool> isAnalyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final optedOut = prefs.getBool(_analyticsOptOutKey) ?? false;
    final consent = await getConsentStatus();

    return !optedOut && (consent?.analyticsConsent ?? false);
  }

  /// Enable analytics
  Future<void> enableAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsOptOutKey, false);

    developer.log(
      '✅ Analytics enabled',
      name: 'PrivacyService.EnableAnalytics',
    );
  }

  /// Disable analytics
  Future<void> disableAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsOptOutKey, true);

    developer.log(
      '📴 Analytics disabled',
      name: 'PrivacyService.DisableAnalytics',
    );
  }

  // ========== Data Export ==========

  /// Export all user data (GDPR Right to Data Portability)
  Future<Map<String, dynamic>> exportUserData() async {
    final uid = AuthService().uid;
    if (uid == null) {
      throw Exception('User not signed in');
    }

    developer.log(
      '📥 Exporting user data for: $uid',
      name: 'PrivacyService.ExportData',
    );

    final exportData = <String, dynamic>{
      'exportDate': DateTime.now().toIso8601String(),
      'userId': uid,
    };

    // Export profiles
    try {
      final profilesSnapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where('uid', isEqualTo: uid)
          .get();

      exportData['profiles'] = profilesSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      developer.log(
        '✅ Exported ${profilesSnapshot.docs.length} profiles',
        name: 'PrivacyService.ExportData',
      );
    } catch (e) {
      developer.log(
        '⚠️  Error exporting profiles: $e',
        name: 'PrivacyService.ExportData',
      );
      exportData['profiles'] = [];
    }

    // Export analytics
    try {
      final analyticsSnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .where('uid', isEqualTo: uid)
          .get();

      exportData['analytics'] = analyticsSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      developer.log(
        '✅ Exported ${analyticsSnapshot.docs.length} analytics events',
        name: 'PrivacyService.ExportData',
      );
    } catch (e) {
      developer.log(
        '⚠️  Error exporting analytics: $e',
        name: 'PrivacyService.ExportData',
      );
      exportData['analytics'] = [];
    }

    // Export privacy settings
    final consent = await getConsentStatus();
    if (consent != null) {
      exportData['privacy'] = consent.toJson();
    }

    developer.log(
      '✅ Data export complete',
      name: 'PrivacyService.ExportData',
    );

    return exportData;
  }

  /// Export user data as JSON string
  Future<String> exportUserDataAsJson() async {
    final data = await exportUserData();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ========== Account Deletion ==========

  /// Delete all user data (GDPR Right to Erasure)
  Future<void> deleteUserData() async {
    final uid = AuthService().uid;
    if (uid == null) {
      throw Exception('User not signed in');
    }

    developer.log(
      '🗑️  Starting account deletion for: $uid',
      name: 'PrivacyService.DeleteAccount',
    );

    // Delete profiles from Firestore
    try {
      final profilesSnapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where('uid', isEqualTo: uid)
          .get();

      for (final doc in profilesSnapshot.docs) {
        await doc.reference.delete();
      }

      developer.log(
        '✅ Deleted ${profilesSnapshot.docs.length} profiles from Firestore',
        name: 'PrivacyService.DeleteAccount',
      );
    } catch (e) {
      developer.log(
        '❌ Error deleting profiles: $e',
        name: 'PrivacyService.DeleteAccount',
      );
    }

    // Delete analytics
    try {
      final analyticsSnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .where('uid', isEqualTo: uid)
          .get();

      for (final doc in analyticsSnapshot.docs) {
        await doc.reference.delete();
      }

      developer.log(
        '✅ Deleted ${analyticsSnapshot.docs.length} analytics events',
        name: 'PrivacyService.DeleteAccount',
      );
    } catch (e) {
      developer.log(
        '❌ Error deleting analytics: $e',
        name: 'PrivacyService.DeleteAccount',
      );
    }

    // Delete images from Storage
    try {
      final storageRef = FirebaseStorage.instance.ref().child('users/$uid');
      final listResult = await storageRef.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      developer.log(
        '✅ Deleted ${listResult.items.length} files from Storage',
        name: 'PrivacyService.DeleteAccount',
      );
    } catch (e) {
      developer.log(
        '❌ Error deleting storage files: $e',
        name: 'PrivacyService.DeleteAccount',
      );
    }

    // Delete user document
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      developer.log(
        '✅ Deleted user document',
        name: 'PrivacyService.DeleteAccount',
      );
    } catch (e) {
      developer.log(
        '❌ Error deleting user document: $e',
        name: 'PrivacyService.DeleteAccount',
      );
    }

    // Delete local data
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      developer.log(
        '✅ Cleared local data',
        name: 'PrivacyService.DeleteAccount',
      );
    } catch (e) {
      developer.log(
        '❌ Error clearing local data: $e',
        name: 'PrivacyService.DeleteAccount',
      );
    }

    // Delete Firebase Auth account
    try {
      await AuthService().deleteAccount();

      developer.log(
        '✅ Account deletion complete',
        name: 'PrivacyService.DeleteAccount',
      );
    } catch (e) {
      developer.log(
        '❌ Error deleting auth account: $e',
        name: 'PrivacyService.DeleteAccount',
      );
      throw Exception('Failed to delete account: $e');
    }
  }
}
