/// Profile Data Models
///
/// Core data models for the Tap Card application including:
/// - **ProfileData**: Main user profile with contact information
/// - **CardAesthetics**: Visual styling for profile cards
/// - **ProfileSettings**: App-wide profile configuration
/// - **ValidationResult**: Profile validation results
///
/// **Profile Architecture:**
/// - Supports 3 profile types: Personal, Professional, Custom
/// - Each profile has unique aesthetic styling
/// - NFC payload caching for instant sharing
/// - Local storage with JSON serialization
/// - Future: Firebase cloud sync
///
/// **NFC Optimization:**
/// - Compact JSON payload format for NTAG213 (144 bytes)
/// - Shortened field names ('n', 'p', 'e', 'c')
/// - Cached payload with 5-minute refresh
/// - Essential fields only for size optimization
///
/// TODO: Firebase - Add Firestore sync methods
/// TODO: Add profile image compression utilities
/// TODO: Implement profile validation rules engine
library;

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

/// Card aesthetic settings for each profile
///
/// Defines the visual appearance of profile cards including colors,
/// gradients, blur effects, and background images.
class CardAesthetics {
  final int templateIndex;     // For UI compatibility (0-3)
  final Color primaryColor;    // Main card color
  final Color secondaryColor;  // Accent/gradient color
  final Color borderColor;     // Border color
  final Color? backgroundColor; // Optional solid background
  final double blurLevel;      // Glassmorphic blur level
  final String? backgroundImagePath; // Local path → Future: Firebase URL

  const CardAesthetics({
    this.templateIndex = 0,
    this.primaryColor = const Color(0xFFFF6B35),     // Orange default
    this.secondaryColor = const Color(0xFFFF8E53),   // Light orange
    this.borderColor = Colors.white,
    this.backgroundColor,
    this.blurLevel = 10.0,
    this.backgroundImagePath,
  });

  CardAesthetics copyWith({
    int? templateIndex,
    Color? primaryColor,
    Color? secondaryColor,
    Color? borderColor,
    Color? backgroundColor,
    double? blurLevel,
    String? backgroundImagePath,
    bool clearBackgroundImagePath = false,
  }) {
    return CardAesthetics(
      templateIndex: templateIndex ?? this.templateIndex,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      blurLevel: blurLevel ?? this.blurLevel,
      backgroundImagePath: clearBackgroundImagePath
        ? null
        : (backgroundImagePath ?? this.backgroundImagePath),
    );
  }

  /// Get gradient colors for card background
  LinearGradient get gradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, secondaryColor],
    );
  }

  /// Check if has background image
  bool get hasBackgroundImage => backgroundImagePath != null && backgroundImagePath!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'templateIndex': templateIndex,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'borderColor': borderColor.value,
      'backgroundColor': backgroundColor?.value,
      'blurLevel': blurLevel,
      'backgroundImagePath': backgroundImagePath,
    };
  }

  factory CardAesthetics.fromJson(Map<String, dynamic> json) {
    return CardAesthetics(
      templateIndex: json['templateIndex'] ?? 0,
      primaryColor: Color(json['primaryColor'] ?? 0xFFFF6B35),
      secondaryColor: Color(json['secondaryColor'] ?? 0xFFFF8E53),
      borderColor: Color(json['borderColor'] ?? 0xFFFFFFFF),
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor']) : null,
      blurLevel: (json['blurLevel'] ?? 10.0).toDouble(),
      backgroundImagePath: json['backgroundImagePath'],
    );
  }

  /// Default aesthetics for each profile type
  static CardAesthetics defaultForType(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return const CardAesthetics(
          templateIndex: 1, // Creative template for personal
          primaryColor: Color(0xFFFF6B35),   // Orange
          secondaryColor: Color(0xFFFF8E53), // Light orange
          borderColor: Colors.white,
          blurLevel: 12.0,
        );
      case ProfileType.professional:
        return const CardAesthetics(
          templateIndex: 0, // Professional template
          primaryColor: Color(0xFF2196F3),   // Blue
          secondaryColor: Color(0xFF64B5F6), // Light blue
          borderColor: Color(0xFF1976D2),   // Dark blue border
          blurLevel: 8.0,
        );
      case ProfileType.custom:
        return const CardAesthetics(
          templateIndex: 3, // Modern template for custom
          primaryColor: Color(0xFF9C27B0),   // Purple
          secondaryColor: Color(0xFFBA68C8), // Light purple
          borderColor: Colors.transparent,
          backgroundColor: Color(0xFF4A148C), // Dark purple background
          blurLevel: 15.0,
        );
    }
  }
}

enum ProfileType {
  personal('Personal', 'For friends, family & casual connections'),
  professional('Professional', 'For work, business & networking'),
  custom('Custom', 'Customizable fields for specific needs');

  const ProfileType(this.label, this.description);
  final String label;
  final String description;
}

class ProfileData {
  final String id;
  final String? uid; // Future: Firebase user UID for backend sync
  final ProfileType type;
  final String name;
  final String? title;
  final String? company;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String> socialMedia;
  final String? profileImagePath; // Local path → Future: Firebase URL
  final CardAesthetics cardAesthetics; // Color-based aesthetics
  final DateTime lastUpdated;
  final bool isActive;
  final String? _cachedNfcPayload; // Pre-computed JSON for instant NFC sharing (legacy)
  final String? _cachedVCard; // Pre-computed vCard for dual-payload NFC
  final String? _cachedCardUrl; // Pre-computed URL for dual-payload NFC
  final DateTime? _dualPayloadCacheTime; // When dual payload was last generated

  ProfileData({
    required this.id,
    this.uid,
    required this.type,
    required this.name,
    this.title,
    this.company,
    this.phone,
    this.email,
    this.website,
    this.socialMedia = const {},
    this.profileImagePath,
    CardAesthetics? cardAesthetics,
    required this.lastUpdated,
    this.isActive = false,
    String? cachedNfcPayload,
    String? cachedVCard,
    String? cachedCardUrl,
    DateTime? dualPayloadCacheTime,
  }) : cardAesthetics = cardAesthetics ?? CardAesthetics.defaultForType(type),
       _cachedNfcPayload = cachedNfcPayload,
       _cachedVCard = cachedVCard,
       _cachedCardUrl = cachedCardUrl,
       _dualPayloadCacheTime = dualPayloadCacheTime;

  ProfileData copyWith({
    String? id,
    String? uid,
    ProfileType? type,
    String? name,
    String? title,
    String? company,
    String? phone,
    String? email,
    String? website,
    Map<String, String>? socialMedia,
    String? profileImagePath,
    CardAesthetics? cardAesthetics,
    DateTime? lastUpdated,
    bool? isActive,
    String? cachedNfcPayload,
    String? cachedVCard,
    String? cachedCardUrl,
    DateTime? dualPayloadCacheTime,
  }) {
    return ProfileData(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      type: type ?? this.type,
      name: name ?? this.name,
      title: title ?? this.title,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      socialMedia: socialMedia ?? this.socialMedia,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      cardAesthetics: cardAesthetics ?? this.cardAesthetics,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      cachedNfcPayload: cachedNfcPayload ?? this._cachedNfcPayload,
      cachedVCard: cachedVCard ?? this._cachedVCard,
      cachedCardUrl: cachedCardUrl ?? this._cachedCardUrl,
      dualPayloadCacheTime: dualPayloadCacheTime ?? this._dualPayloadCacheTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'type': type.name,
      'name': name,
      'title': title,
      'company': company,
      'phone': phone,
      'email': email,
      'website': website,
      'socialMedia': socialMedia,
      'profileImagePath': profileImagePath,
      'cardAesthetics': cardAesthetics.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
      'cachedNfcPayload': _cachedNfcPayload,
      'cachedVCard': _cachedVCard,
      'cachedCardUrl': _cachedCardUrl,
      'dualPayloadCacheTime': _dualPayloadCacheTime?.toIso8601String(),
    };
  }

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final type = ProfileType.values.firstWhere((e) => e.name == json['type']);
    return ProfileData(
      id: json['id'],
      uid: json['uid'],
      type: type,
      name: json['name'],
      title: json['title'],
      company: json['company'],
      phone: json['phone'],
      email: json['email'],
      website: json['website'],
      socialMedia: Map<String, String>.from(json['socialMedia'] ?? {}),
      profileImagePath: json['profileImagePath'],
      cardAesthetics: json['cardAesthetics'] != null
        ? CardAesthetics.fromJson(json['cardAesthetics'])
        : CardAesthetics.defaultForType(type),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      isActive: json['isActive'] ?? false,
      cachedNfcPayload: json['cachedNfcPayload'],
      cachedVCard: json['cachedVCard'],
      cachedCardUrl: json['cachedCardUrl'],
      dualPayloadCacheTime: json['dualPayloadCacheTime'] != null
        ? DateTime.parse(json['dualPayloadCacheTime'])
        : null,
    );
  }

  // Get default fields for each profile type
  static List<String> getDefaultFields(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return ['name', 'phone', 'email', 'instagram', 'snapchat', 'tiktok'];
      case ProfileType.professional:
        return ['name', 'title', 'company', 'phone', 'email', 'linkedin', 'website'];
      case ProfileType.custom:
        return ['name', 'phone', 'email'];
    }
  }

  /// Get required fields for each profile type (for NFC sharing)
  static List<String> getRequiredFields(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return ['name', 'phone'];
      case ProfileType.professional:
        return ['name', 'phone', 'company'];
      case ProfileType.custom:
        return ['name', 'phone'];
    }
  }

  // Get available social media platforms for each profile type
  static List<String> getAvailableSocials(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return ['instagram', 'snapchat', 'tiktok', 'twitter', 'facebook', 'discord'];
      case ProfileType.professional:
        return ['linkedin', 'twitter', 'github', 'behance', 'dribbble'];
      case ProfileType.custom:
        return ['instagram', 'snapchat', 'tiktok', 'twitter', 'facebook', 'linkedin', 'github', 'discord', 'behance', 'dribbble', 'youtube', 'twitch'];
    }
  }

  // Create empty profile for a type
  static ProfileData createEmpty(ProfileType type) {
    final profile = ProfileData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      name: '',
      lastUpdated: DateTime.now(),
    );
    // Generate initial NFC cache (both legacy and dual-payload)
    return profile.regenerateDualPayloadCache();
  }

  /// Get essential fields for NFC transmission (ultra-compact for NTAG213)
  Map<String, dynamic> getEssentialFields() {
    final essential = <String, dynamic>{
      'n': name,  // Shortened field names for NTAG213
    };

    // Always include phone if available
    if (phone != null && phone!.isNotEmpty) {
      essential['p'] = phone;
    }

    // Include company for professional profiles
    if (type == ProfileType.professional && company != null && company!.isNotEmpty) {
      essential['c'] = company;
    }

    // Include email if available and space permits
    if (email != null && email!.isNotEmpty) {
      essential['e'] = email;
    }

    return essential;
  }

  /// Check if profile meets minimum requirements for NFC sharing
  bool get isNfcReady {
    // Name is always required
    if (name.isEmpty) return false;

    switch (type) {
      case ProfileType.personal:
        // Personal: name + phone
        return phone != null && phone!.isNotEmpty;
      case ProfileType.professional:
        // Professional: name + phone + company
        return phone != null && phone!.isNotEmpty &&
               company != null && company!.isNotEmpty;
      case ProfileType.custom:
        // Custom: name + phone
        return phone != null && phone!.isNotEmpty;
    }
  }

  /// Get required fields for this profile type
  List<String> get requiredFields {
    switch (type) {
      case ProfileType.personal:
        return ['name', 'phone'];
      case ProfileType.professional:
        return ['name', 'phone', 'company'];
      case ProfileType.custom:
        return ['name', 'phone'];
    }
  }

  /// Check if a specific field is required for this profile type
  bool isFieldRequired(String fieldName) {
    return requiredFields.contains(fieldName);
  }

  /// Validate profile completeness
  ValidationResult validate() {
    final missing = <String>[];
    final warnings = <String>[];

    for (final field in requiredFields) {
      switch (field) {
        case 'name':
          if (name.isEmpty) missing.add('name');
          break;
        case 'phone':
          if (phone == null || phone!.isEmpty) missing.add('phone');
          break;
        case 'company':
          if (company == null || company!.isEmpty) missing.add('company');
          break;
      }
    }

    // Add warnings for recommended fields
    if (email == null || email!.isEmpty) {
      warnings.add('Email recommended for better contact options');
    }

    return ValidationResult(
      isValid: missing.isEmpty,
      missingFields: missing,
      warnings: warnings,
      canShare: isNfcReady,
    );
  }

  /// Get the cached NFC payload or generate it if not cached
  String get nfcPayload => _cachedNfcPayload ?? _generateNfcPayload();

  /// Generate optimized JSON payload for NFC transmission (always fresh)
  String _generateNfcPayload() {
    // Ultra-compact payload for NTAG213 (144 bytes)
    final payload = {
      'a': 'tc',  // Shortened app identifier
      'v': '1',   // Shortened version
      'd': getEssentialFields(),
      't': (DateTime.now().millisecondsSinceEpoch / 1000).round(), // Seconds instead of ms
    };
    return jsonEncode(payload);
  }

  /// Create a new ProfileData with regenerated NFC cache
  ProfileData regenerateNfcCache() {
    final newPayload = _generateNfcPayload();
    return copyWith(
      cachedNfcPayload: newPayload,
      lastUpdated: DateTime.now(),
    );
  }

  /// Check if NFC cache needs regeneration (older than 5 minutes or missing)
  bool get needsNfcCacheUpdate {
    if (_cachedNfcPayload == null) return true;

    try {
      final cached = jsonDecode(_cachedNfcPayload!);
      final cacheTimeSeconds = cached['t'] ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cacheTimeSeconds * 1000);
      final age = DateTime.now().difference(cacheTime);
      return age.inMinutes > 5; // Refresh every 5 minutes
    } catch (e) {
      return true; // Invalid cache, regenerate
    }
  }

  /// Get fresh NFC payload, regenerating cache if needed
  ///
  /// Performance: Prefers cached payload for instant NFC sharing.
  /// Only regenerates if cache is missing or older than 5 minutes.
  String getFreshNfcPayload() {
    // Use cached payload if available (instant performance)
    if (_cachedNfcPayload != null && !needsNfcCacheUpdate) {
      return _cachedNfcPayload!;
    }
    // Regenerate only if cache is stale or missing
    return _generateNfcPayload();
  }

  // ============================================================================
  // DUAL-PAYLOAD NFC OPTIMIZATION (vCard + URL)
  // ============================================================================

  /// Generate optimized vCard 3.0 for NFC transmission
  ///
  /// Optimizations:
  /// - Uses \n instead of writeln() (saves ~15 bytes)
  /// - Skips empty optional fields
  /// - Truncates long titles (>20 chars)
  /// - Minimal formatting for maximum space efficiency
  String _generateOptimizedVCard() {
    final buffer = StringBuffer();
    buffer.write('BEGIN:VCARD\n');
    buffer.write('VERSION:3.0\n');
    buffer.write('FN:$name\n');

    // Structured name parsing (trim whitespace)
    final nameParts = name.split(' ').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (nameParts.length >= 2) {
      buffer.write('N:${nameParts.last};${nameParts.first};;;\n');
    } else {
      buffer.write('N:$name;;;;\n');
    }

    // Title (truncated if too long)
    if (title != null && title!.isNotEmpty) {
      final truncatedTitle = title!.length > 20 ? title!.substring(0, 20) : title;
      buffer.write('TITLE:$truncatedTitle\n');
    }

    // Organization
    if (company != null && company!.isNotEmpty) {
      buffer.write('ORG:$company\n');
    }

    // Phone
    if (phone != null && phone!.isNotEmpty) {
      buffer.write('TEL;TYPE=CELL:$phone\n');
    }

    // Email
    if (email != null && email!.isNotEmpty) {
      buffer.write('EMAIL:$email\n');
    }

    // Card URL - Primary link to full digital profile
    // Always include this as the main URL (replaces social media URLs)
    // When saved as contact, user can tap this to open full card online
    buffer.write('URL:${_generateCardUrl()}\n');

    buffer.write('END:VCARD');
    return buffer.toString();
  }

  /// Generate full URL from social media handle
  String? _generateSocialUrl(String platform, String handle) {
    // Trim whitespace and remove @ prefix
    final trimmedHandle = handle.trim();
    final cleanHandle = trimmedHandle.startsWith('@') ? trimmedHandle.substring(1).trim() : trimmedHandle;

    // If already a URL, return as-is
    if (trimmedHandle.startsWith('http://') || trimmedHandle.startsWith('https://')) {
      return trimmedHandle;
    }

    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$cleanHandle';
      case 'twitter':
      case 'x':
        return 'https://x.com/$cleanHandle';
      case 'instagram':
        return 'https://instagram.com/$cleanHandle';
      case 'github':
        return 'https://github.com/$cleanHandle';
      default:
        return null;
    }
  }

  /// Generate custom URL for full digital profile using unique UUID
  /// URL pattern: https://tap-card-site.vercel.app/share/[uuid]
  ///
  /// Benefits:
  /// - Globally unique (no collisions for same names)
  /// - Backend-ready (UUID = Firebase document ID)
  /// - Enables proper contact-to-profile linking
  /// - Ready for web profile viewer and analytics
  ///
  /// URL is clickable in saved contact → opens full card with all info, analytics
  String _generateCardUrl() {
    return 'https://tap-card-site.vercel.app/share/$id';
  }

  /// Check if dual payload cache is stale (>5 minutes old or missing)
  bool get needsDualPayloadCacheUpdate {
    if (_cachedVCard == null || _cachedCardUrl == null) return true;
    if (_dualPayloadCacheTime == null) return true;

    final age = DateTime.now().difference(_dualPayloadCacheTime!);
    return age.inMinutes > 5;
  }

  /// Regenerate dual-payload cache (vCard + URL)
  ProfileData regenerateDualPayloadCache() {
    final vCard = _generateOptimizedVCard();
    final url = _generateCardUrl();
    final now = DateTime.now();

    developer.log(
      '🔄 Regenerating dual-payload cache\n'
      '   • vCard: ${vCard.length} bytes\n'
      '   • URL: ${url.length} bytes\n'
      '   • Total: ${vCard.length + url.length} bytes',
      name: 'ProfileData.Cache'
    );

    return copyWith(
      cachedVCard: vCard,
      cachedCardUrl: url,
      dualPayloadCacheTime: now,
      cachedNfcPayload: _generateNfcPayload(), // Also refresh legacy payload
      lastUpdated: now,
    );
  }

  /// Get dual payload (vCard + URL) for instant NFC sharing
  ///
  /// Performance: Returns cached version if available (0ms lag!)
  /// Only regenerates if cache is stale or missing.
  Map<String, String> get dualPayload {
    // Use cached version if available and fresh
    if (_cachedVCard != null && _cachedCardUrl != null && !needsDualPayloadCacheUpdate) {
      developer.log(
        '✅ Using cached dual-payload (instant!)\n'
        '   • vCard: ${_cachedVCard!.length} bytes\n'
        '   • URL: ${_cachedCardUrl!.length} bytes',
        name: 'ProfileData.DualPayload'
      );
      return {
        'vcard': _cachedVCard!,
        'url': _cachedCardUrl!,
      };
    }

    // Cache is stale/missing - regenerate
    developer.log(
      '⚠️ Dual-payload cache expired, regenerating...',
      name: 'ProfileData.DualPayload'
    );
    final freshProfile = regenerateDualPayloadCache();
    return {
      'vcard': freshProfile._cachedVCard!,
      'url': freshProfile._cachedCardUrl!,
    };
  }
}

/// Validation result for profile completeness
class ValidationResult {
  final bool isValid;
  final List<String> missingFields;
  final List<String> warnings;
  final bool canShare;

  const ValidationResult({
    required this.isValid,
    required this.missingFields,
    required this.warnings,
    required this.canShare,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasMissingFields => missingFields.isNotEmpty;
}

class ProfileSettings {
  final bool multipleProfilesEnabled;
  final String activeProfileId;
  final List<String> profileOrder;

  ProfileSettings({
    this.multipleProfilesEnabled = false,
    required this.activeProfileId,
    this.profileOrder = const [],
  });

  ProfileSettings copyWith({
    bool? multipleProfilesEnabled,
    String? activeProfileId,
    List<String>? profileOrder,
  }) {
    return ProfileSettings(
      multipleProfilesEnabled: multipleProfilesEnabled ?? this.multipleProfilesEnabled,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profileOrder: profileOrder ?? this.profileOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'multipleProfilesEnabled': multipleProfilesEnabled,
      'activeProfileId': activeProfileId,
      'profileOrder': profileOrder,
    };
  }

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      multipleProfilesEnabled: json['multipleProfilesEnabled'] ?? false,
      activeProfileId: json['activeProfileId'],
      profileOrder: List<String>.from(json['profileOrder'] ?? []),
    );
  }
}