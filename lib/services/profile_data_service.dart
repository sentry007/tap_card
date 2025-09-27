import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/unified_models.dart';

/// Service for managing user profile data and privacy controls
class ProfileDataService {
  static const String _profileKey = 'user_profile';
  static const String _activeProfileIdKey = 'active_profile_id';

  // Current: Local storage
  // Future: Firebase Firestore sync

  /// Load current active user profile (currently from SharedPreferences)
  static Future<ProfileData?> getCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_profileKey);
    if (profileJson == null) return null;

    try {
      return ProfileData.fromJson(jsonDecode(profileJson));
    } catch (e) {
      print('Error parsing stored profile: $e');
      return null;
    }
  }

  /// Save user profile (currently local, future: sync to Firestore)
  static Future<void> saveProfile(ProfileData profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));

    // TODO: When Firebase is added, sync to Firestore here
    // await FirebaseFirestore.instance
    //   .collection('users')
    //   .doc(profile.id)
    //   .set(profile.toFirestoreJson());

    // Prepare for Firebase sync
    await _syncToFirebase(profile);
  }

  /// Sync profile to Firebase Firestore (Future implementation)
  static Future<void> _syncToFirebase(ProfileData profile) async {
    // TODO: Implement when Firebase is added
    // try {
    //   await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(profile.id)
    //     .set(profile.toFirestoreJson());
    //   print('🔄 Firebase sync completed for: ${profile.name}');
    // } catch (e) {
    //   print('⚠️ Firebase sync error: $e');
    // }

    // For now, just log that sync would happen
    print('🔄 Firebase sync ready for: ${profile.name} (${profile.id})');
  }

  /// Manual Firebase sync trigger (for future use)
  static Future<void> syncToFirebase(ProfileData profile) async {
    // await _syncToFirebase(profile);
    print('🔄 Firebase sync triggered for: ${profile.name} (placeholder)');
  }

  /// Generate shareable contact data based on privacy settings
  static ContactData extractContactData(ProfileData profile, String privacyLevel) {
    switch (privacyLevel.toLowerCase()) {
      case 'minimal':
        return ContactData(name: profile.name);

      case 'basic':
        return ContactData(
          name: profile.name,
          title: profile.title,
          company: profile.company,
        );

      case 'professional':
        return ContactData(
          name: profile.name,
          title: profile.title,
          company: profile.company,
          email: profile.email,
        );

      case 'full':
        return ContactData(
          name: profile.name,
          title: profile.title,
          company: profile.company,
          phone: profile.phone,
          email: profile.email,
          website: profile.website,
          socialMedia: profile.socialMedia,
        );

      default:
        return ContactData(name: profile.name);
    }
  }

  /// Generate contact metadata based on profile completeness and privacy level
  static Map<String, dynamic> generateContactMetadata(ProfileData profile, [String? privacyLevel]) {
    final defaultPrivacy = privacyLevel ?? _getDefaultPrivacyLevel(profile.type);

    final hasPhoto = profile.profileImagePath != null;
    final hasSocials = profile.socialMedia.isNotEmpty;
    final hasWebsite = profile.website != null && profile.website!.isNotEmpty;
    final hasBio = false; // Current ProfileData doesn't have bio field

    // Filter metadata based on privacy level
    switch (defaultPrivacy.toLowerCase()) {
      case 'minimal':
        return {
          'hasPhoto': false,
          'hasSocials': false,
          'hasWebsite': false,
          'hasBio': false,
          'privacyLevel': defaultPrivacy,
        };

      case 'basic':
        return {
          'hasPhoto': false,
          'hasSocials': false,
          'hasWebsite': hasWebsite,
          'hasBio': false,
          'privacyLevel': defaultPrivacy,
        };

      case 'professional':
      case 'full':
        return {
          'hasPhoto': hasPhoto,
          'hasSocials': hasSocials,
          'hasWebsite': hasWebsite,
          'hasBio': hasBio,
          'privacyLevel': defaultPrivacy,
        };

      default:
        return {
          'hasPhoto': hasPhoto,
          'hasSocials': hasSocials,
          'hasWebsite': hasWebsite,
          'hasBio': hasBio,
          'privacyLevel': defaultPrivacy,
        };
    }
  }

  /// Get default privacy level based on profile type
  static String _getDefaultPrivacyLevel(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return 'basic';
      case ProfileType.professional:
        return 'professional';
      case ProfileType.custom:
        return 'full';
    }
  }

  /// Get profile completeness score (0-100)
  static int getProfileCompleteness(ProfileData profile) {
    int score = 0;
    const int maxScore = 100;

    // Required fields (40 points)
    if (profile.name.isNotEmpty) score += 20;
    if (profile.email != null && profile.email!.isNotEmpty) score += 20;

    // Important fields (30 points)
    if (profile.phone != null && profile.phone!.isNotEmpty) score += 10;
    if (profile.title != null && profile.title!.isNotEmpty) score += 10;
    if (profile.company != null && profile.company!.isNotEmpty) score += 10;

    // Optional fields (30 points)
    if (profile.website != null && profile.website!.isNotEmpty) score += 10;
    if (profile.profileImagePath != null) score += 10;
    if (profile.socialMedia.isNotEmpty) score += 10;

    return (score * maxScore / 100).round();
  }

  /// Get missing fields for profile completion
  static List<String> getMissingFields(ProfileData profile) {
    final missing = <String>[];

    if (profile.name.isEmpty) missing.add('name');
    if (profile.email == null || profile.email!.isEmpty) missing.add('email');
    if (profile.phone == null || profile.phone!.isEmpty) missing.add('phone');

    // Type-specific fields
    switch (profile.type) {
      case ProfileType.professional:
        if (profile.title == null || profile.title!.isEmpty) missing.add('title');
        if (profile.company == null || profile.company!.isEmpty) missing.add('company');
        break;
      case ProfileType.personal:
        // Personal profiles are more flexible
        break;
      case ProfileType.custom:
        // Custom profiles depend on user preference
        break;
    }

    return missing;
  }

  /// Create a user ID (currently timestamp, future: Firebase Auth UID)
  static String generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Check if profile exists
  static Future<bool> hasProfile() async {
    final profile = await getCurrentProfile();
    return profile != null;
  }

  /// Delete profile (for account deletion/reset)
  static Future<void> deleteProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_activeProfileIdKey);
    print('🗑️ Profile data cleared');
  }

  /// Get profile stats for analytics
  static Map<String, dynamic> getProfileStats(ProfileData profile) {
    return {
      'type': profile.type.name,
      'completeness': getProfileCompleteness(profile),
      'has_photo': profile.profileImagePath != null,
      'social_count': profile.socialMedia.length,
      'created_days_ago': DateTime.now().difference(profile.lastUpdated).inDays,
      'is_active': profile.isActive,
    };
  }

  /// Validate profile data
  static List<String> validateProfile(ProfileData profile) {
    final errors = <String>[];

    if (profile.name.trim().isEmpty) {
      errors.add('Name is required');
    }

    if (profile.email != null && profile.email!.isNotEmpty) {
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(profile.email!)) {
        errors.add('Invalid email format');
      }
    }

    if (profile.phone != null && profile.phone!.isNotEmpty) {
      if (profile.phone!.length < 10) {
        errors.add('Phone number too short');
      }
    }

    if (profile.website != null && profile.website!.isNotEmpty) {
      if (!profile.website!.startsWith('http')) {
        errors.add('Website must start with http:// or https://');
      }
    }

    return errors;
  }
}