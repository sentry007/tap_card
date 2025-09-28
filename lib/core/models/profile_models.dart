import 'dart:convert';
import 'package:flutter/material.dart';

/// Card aesthetic settings for each profile (color-based, not template indices)
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
  }) {
    return CardAesthetics(
      templateIndex: templateIndex ?? this.templateIndex,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      blurLevel: blurLevel ?? this.blurLevel,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
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
  final String? _cachedNfcPayload; // Pre-computed JSON for instant NFC sharing

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
  }) : cardAesthetics = cardAesthetics ?? CardAesthetics.defaultForType(type),
       _cachedNfcPayload = cachedNfcPayload;

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
    // Generate initial NFC cache for empty profile
    return profile.regenerateNfcCache();
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
  String getFreshNfcPayload() {
    if (needsNfcCacheUpdate) {
      return _generateNfcPayload();
    }
    return nfcPayload;
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