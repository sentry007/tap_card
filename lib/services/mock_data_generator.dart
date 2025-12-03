/// Mock Data Generator Service
///
/// Generates realistic test profiles for Firebase integration testing:
/// - Creates profiles with test_ prefix (isolated from real data)
/// - Includes realistic names, emails, phone numbers
/// - Supports all 3 profile types
/// - Auto-syncs to Firestore
library;

import 'dart:developer' as developer;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_card/core/models/profile_models.dart';
import 'package:tap_card/services/firestore_sync_service.dart';

/// Service for generating mock profile data for testing
///
/// IMPORTANT: This service only works when Developer Mode is enabled in settings.
/// All methods will throw an exception if dev mode is OFF to prevent accidental
/// mock data generation in production/beta environments.
class MockDataGenerator {
  static final Random _random = Random();

  /// Check if dev mode is enabled
  static Future<bool> _isDevModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('settings_dev_mode') ?? false;
    } catch (e) {
      developer.log(
        '⚠️  Failed to check dev mode setting: $e',
        name: 'MockData.DevMode',
      );
      return false;
    }
  }

  /// Throw exception if dev mode is disabled
  static Future<void> _ensureDevModeEnabled() async {
    final devModeEnabled = await _isDevModeEnabled();
    if (!devModeEnabled) {
      throw Exception(
        'MockDataGenerator is disabled - Developer Mode is OFF.\n'
        'Enable Developer Mode in Settings > Advanced to use mock data generation.'
      );
    }
  }

  // Sample data pools for realistic profiles
  static const List<String> _firstNames = [
    'Alex', 'Jordan', 'Casey', 'Morgan', 'Riley',
    'Taylor', 'Sam', 'Avery', 'Quinn', 'Blake',
    'Skylar', 'River', 'Sage', 'Cameron', 'Parker'
  ];

  static const List<String> _lastNames = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones',
    'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
    'Wilson', 'Anderson', 'Taylor', 'Thomas', 'Moore'
  ];

  static const List<String> _companies = [
    'TechFlow Solutions', 'Innovation Labs', 'Digital Dynamics',
    'Cloud Nine Inc', 'Future Forward', 'Bright Ideas Co',
    'NextGen Systems', 'Quantum Leap', 'Pulse Technologies',
    'Zenith Consulting', 'Apex Solutions', 'Vertex Group'
  ];

  static const List<String> _jobTitles = [
    'Senior Product Designer', 'Software Engineer', 'Marketing Manager',
    'Sales Director', 'UX Researcher', 'Data Scientist',
    'Project Manager', 'Business Analyst', 'DevOps Engineer',
    'Content Strategist', 'Brand Manager', 'Operations Lead'
  ];

  static const List<String> _domains = [
    'gmail.com', 'outlook.com', 'yahoo.com', 'icloud.com',
    'proton.me', 'hey.com', 'fastmail.com'
  ];

  static const Map<String, List<String>> _socialHandles = {
    'instagram': ['photographer', 'designer', 'creator', 'artist', 'explorer'],
    'linkedin': ['professional', 'dev', 'tech', 'manager', 'consultant'],
    'twitter': ['tweets', 'tech', 'dev', 'thoughts', 'ideas'],
    'github': ['dev', 'code', 'builds', 'creates', 'engineer'],
    'tiktok': ['creative', 'content', 'fun', 'vibes', 'creator'],
    'snapchat': ['snaps', 'daily', 'life', 'moments', 'stories'],
  };

  /// Generate a random personal profile
  static Future<ProfileData> generatePersonalProfile() async {
    await _ensureDevModeEnabled();

    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final fullName = '$firstName $lastName';
    final username = '${firstName.toLowerCase()}${lastName.toLowerCase()}${_random.nextInt(100)}';

    final profile = ProfileData(
      id: 'test_personal_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      type: ProfileType.personal,
      name: fullName,
      phone: _generatePhoneNumber(),
      email: '$username@${_domains[_random.nextInt(_domains.length)]}',
      socialMedia: {
        'instagram': '@${username}_${_socialHandles['instagram']![_random.nextInt(5)]}',
        'snapchat': '$username.snaps',
        'tiktok': '@$username',
      },
      customLinks: [
        CustomLink(
          title: 'My Portfolio',
          url: 'https://$username.portfolio.com',
        ),
        CustomLink(
          title: 'Personal Blog',
          url: 'https://$username.blog.com',
        ),
      ],
      cardAesthetics: CardAesthetics.defaultForType(ProfileType.personal),
      lastUpdated: DateTime.now(),
      isActive: false,
    );

    developer.log(
      '👤 Generated Personal Profile\n'
      '   • ID: ${profile.id}\n'
      '   • Name: ${profile.name}\n'
      '   • Email: ${profile.email}\n'
      '   • Phone: ${profile.phone}',
      name: 'MockData.Personal',
    );

    return profile;
  }

  /// Generate a random professional profile
  static Future<ProfileData> generateProfessionalProfile() async {
    await _ensureDevModeEnabled();

    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final fullName = '$firstName $lastName';
    final username = '${firstName.toLowerCase()}${lastName.toLowerCase()}';
    final company = _companies[_random.nextInt(_companies.length)];
    final title = _jobTitles[_random.nextInt(_jobTitles.length)];

    final profile = ProfileData(
      id: 'test_professional_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      type: ProfileType.professional,
      name: fullName,
      title: title,
      company: company,
      phone: _generatePhoneNumber(),
      email: '$username@${company.toLowerCase().replaceAll(' ', '')}.com',
      website: '${company.toLowerCase().replaceAll(' ', '')}.com',
      socialMedia: {
        'linkedin': '/in/$username-${_socialHandles['linkedin']![_random.nextInt(5)]}',
        'twitter': '@$username',
      },
      customLinks: [
        CustomLink(
          title: 'Schedule Meeting',
          url: 'https://calendly.com/$username',
        ),
        CustomLink(
          title: 'Company Website',
          url: 'https://${company.toLowerCase().replaceAll(' ', '')}.com',
        ),
      ],
      cardAesthetics: CardAesthetics.defaultForType(ProfileType.professional),
      lastUpdated: DateTime.now(),
      isActive: false,
    );

    developer.log(
      '💼 Generated Professional Profile\n'
      '   • ID: ${profile.id}\n'
      '   • Name: ${profile.name}\n'
      '   • Title: ${profile.title}\n'
      '   • Company: ${profile.company}',
      name: 'MockData.Professional',
    );

    return profile;
  }

  /// Generate a random custom profile
  static Future<ProfileData> generateCustomProfile() async {
    await _ensureDevModeEnabled();

    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final fullName = '$firstName $lastName';
    final username = '${firstName.toLowerCase()}${lastName.toLowerCase()}';

    final profile = ProfileData(
      id: 'test_custom_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      type: ProfileType.custom,
      name: fullName,
      title: 'Content Creator',
      phone: _generatePhoneNumber(),
      email: '$username@creator.io',
      website: '$username.co',
      socialMedia: {
        'youtube': '@$username',
        'instagram': '@$username',
        'twitter': '@$username',
      },
      customLinks: [
        CustomLink(
          title: 'YouTube Channel',
          url: 'https://youtube.com/@$username',
        ),
        CustomLink(
          title: 'Merch Store',
          url: 'https://shop.$username.co',
        ),
      ],
      cardAesthetics: CardAesthetics.defaultForType(ProfileType.custom),
      lastUpdated: DateTime.now(),
      isActive: false,
    );

    developer.log(
      '🎨 Generated Custom Profile\n'
      '   • ID: ${profile.id}\n'
      '   • Name: ${profile.name}\n'
      '   • Title: ${profile.title}',
      name: 'MockData.Custom',
    );

    return profile;
  }

  /// Generate a phone number in US format
  static String _generatePhoneNumber() {
    final areaCode = 200 + _random.nextInt(800); // 200-999
    final exchange = 200 + _random.nextInt(800);
    final number = 1000 + _random.nextInt(9000);
    return '+1 ($areaCode) $exchange-$number';
  }

  /// Generate a complete set of test profiles (one of each type)
  static Future<List<ProfileData>> generateCompleteSet() async {
    await _ensureDevModeEnabled();

    developer.log(
      '📦 Generating complete profile set...',
      name: 'MockData.Set',
    );

    final profiles = [
      await generatePersonalProfile(),
      await generateProfessionalProfile(),
      await generateCustomProfile(),
    ];

    developer.log(
      '✅ Generated ${profiles.length} test profiles',
      name: 'MockData.Set',
    );

    return profiles;
  }

  /// Generate and sync a test profile to Firestore
  static Future<ProfileData?> generateAndSyncProfile(ProfileType type) async {
    await _ensureDevModeEnabled();

    developer.log(
      '🚀 Generating and syncing ${type.name} profile...',
      name: 'MockData.Sync',
    );

    ProfileData profile;
    switch (type) {
      case ProfileType.personal:
        profile = await generatePersonalProfile();
        break;
      case ProfileType.professional:
        profile = await generateProfessionalProfile();
        break;
      case ProfileType.custom:
        profile = await generateCustomProfile();
        break;
    }

    // Regenerate payload caches
    profile = profile.regeneratePayloadCache();

    // Sync to Firestore
    final syncResult = await FirestoreSyncService.syncProfileToFirestore(profile);
    final success = syncResult != null;

    if (success) {
      developer.log(
        '✅ Test profile synced successfully\n'
        '   • Profile ID: ${profile.id}\n'
        '   • View at: https://atlaslinq.com/share/${profile.id}',
        name: 'MockData.Sync',
      );
      return profile;
    } else {
      developer.log(
        '❌ Failed to sync test profile',
        name: 'MockData.Sync',
      );
      return null;
    }
  }

  /// Generate and sync a complete set of profiles
  static Future<List<ProfileData>> generateAndSyncCompleteSet() async {
    await _ensureDevModeEnabled();

    developer.log(
      '📦 Generating and syncing complete profile set...',
      name: 'MockData.SyncSet',
    );

    final profiles = await generateCompleteSet();
    final syncedProfiles = <ProfileData>[];

    for (final profile in profiles) {
      final profileWithCache = profile.regeneratePayloadCache();
      final syncResult = await FirestoreSyncService.syncProfileToFirestore(profileWithCache);

      if (syncResult != null) {
        syncedProfiles.add(profileWithCache);
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }

    developer.log(
      '✅ Synced ${syncedProfiles.length}/${profiles.length} profiles',
      name: 'MockData.SyncSet',
    );

    return syncedProfiles;
  }

  /// Clean up test profiles from Firestore
  static Future<int> cleanupTestProfiles() async {
    developer.log(
      '🧹 Cleaning up test profiles...',
      name: 'MockData.Cleanup',
    );

    // Note: This would require listing all documents and filtering by test_ prefix
    // For now, we'll return 0 as we don't want to implement full collection scan
    // Users can manually delete test profiles from Firebase Console if needed

    developer.log(
      '⚠️  Manual cleanup required: Delete test_ profiles from Firebase Console',
      name: 'MockData.Cleanup',
    );

    return 0;
  }

  /// Get website URL for a profile
  static String getWebsiteUrl(String profileId) {
    return 'https://atlaslinq.com/share/$profileId';
  }
}
