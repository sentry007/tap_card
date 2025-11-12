/// Profile Data Models
///
/// Core data models for the Atlas Linq application including:
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
import '../../models/history_models.dart';

/// Card aesthetic settings for each profile
///
/// Defines the visual appearance of profile cards including colors,
/// gradients, blur effects, and background images.
///
/// NOTE: Templates are now handled as preset color combinations in the UI,
/// not stored in the profile data. This simplifies the data model.
class CardAesthetics {
  final Color primaryColor;    // Main card color
  final Color secondaryColor;  // Accent/gradient color
  final Color borderColor;     // Border color
  final Color? backgroundColor; // Optional solid background
  final double blurLevel;      // Glassmorphic blur level
  final String? backgroundImagePath; // Local path → Future: Firebase URL

  const CardAesthetics({
    this.primaryColor = const Color(0xFFFF6B35),     // Orange default
    this.secondaryColor = const Color(0xFFFF8E53),   // Light orange
    this.borderColor = Colors.white,
    this.backgroundColor,
    this.blurLevel = 10.0,
    this.backgroundImagePath,
  });

  CardAesthetics copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? borderColor,
    Color? backgroundColor,
    double? blurLevel,
    String? backgroundImagePath,
    bool clearBackgroundImagePath = false,
  }) {
    return CardAesthetics(
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
      primaryColor: Color(json['primaryColor'] ?? 0xFFFF6B35),
      secondaryColor: Color(json['secondaryColor'] ?? 0xFFFF8E53),
      borderColor: Color(json['borderColor'] ?? 0xFFFFFFFF),
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor']) : null,
      blurLevel: (json['blurLevel'] ?? 10.0).toDouble(),
      // Support both field names for backward compatibility:
      // - 'backgroundImageUrl' from Firestore (Firebase Storage URLs)
      // - 'backgroundImagePath' from local storage (file paths)
      backgroundImagePath: json['backgroundImageUrl'] ?? json['backgroundImagePath'],
    );
  }

  /// Default aesthetics for each profile type
  static CardAesthetics defaultForType(ProfileType type) {
    switch (type) {
      case ProfileType.personal:
        return const CardAesthetics(
          primaryColor: Color(0xFFFF6B35),   // Orange
          secondaryColor: Color(0xFFFF8E53), // Light orange
          borderColor: Colors.white,
          blurLevel: 12.0,
        );
      case ProfileType.professional:
        return const CardAesthetics(
          primaryColor: Color(0xFF2196F3),   // Blue
          secondaryColor: Color(0xFF64B5F6), // Light blue
          borderColor: Color(0xFF1976D2),   // Dark blue border
          blurLevel: 8.0,
        );
      case ProfileType.custom:
        return const CardAesthetics(
          primaryColor: Color(0xFF9C27B0),   // Purple
          secondaryColor: Color(0xFFBA68C8), // Light purple
          borderColor: Colors.transparent,
          backgroundColor: Color(0xFF4A148C), // Dark purple background
          blurLevel: 15.0,
        );
    }
  }
}

/// Custom link model for user-defined links
///
/// Users can add up to 3 custom links with custom titles
/// These are displayed in the app and on the web profile
/// Not included in NFC/vCard payloads
class CustomLink {
  final String title;
  final String url;

  const CustomLink({
    required this.title,
    required this.url,
  });

  CustomLink copyWith({
    String? title,
    String? url,
  }) {
    return CustomLink(
      title: title ?? this.title,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }

  factory CustomLink.fromJson(Map<String, dynamic> json) {
    return CustomLink(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }

  /// Validate that both title and url are non-empty
  bool get isValid => title.trim().isNotEmpty && url.trim().isNotEmpty;
}

enum ProfileType {
  personal('Personal', 'For friends, family & casual connections'),
  professional('Professional', 'For work, business & networking'),
  custom('Custom', 'Customizable fields for specific needs');

  const ProfileType(this.label, this.description);
  final String label;
  final String description;

  /// Single digit code for compact vCard storage
  /// 1=Personal, 2=Professional, 3=Custom
  int get code {
    switch (this) {
      case ProfileType.personal:     return 1;
      case ProfileType.professional: return 2;
      case ProfileType.custom:       return 3;
    }
  }

  /// Decode from single digit
  static ProfileType fromCode(int code) {
    switch (code) {
      case 1: return ProfileType.personal;
      case 2: return ProfileType.professional;
      case 3: return ProfileType.custom;
      default: return ProfileType.personal;
    }
  }
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
  final List<CustomLink> customLinks; // Up to 3 custom links (app/web only, not in NFC)
  final String? profileImagePath; // Local path → Future: Firebase URL
  final CardAesthetics cardAesthetics; // Color-based aesthetics
  final DateTime lastUpdated;
  final bool isActive;
  final String? _cachedNfcPayload; // Pre-computed JSON for instant NFC sharing (legacy)
  final String? _cachedVCard; // Pre-computed vCard for dual-payload NFC
  final String? _cachedCardUrl; // Pre-computed URL for dual-payload NFC
  final DateTime? _dualPayloadCacheTime; // When dual payload was last generated
  final List<String> receivedCardUuids; // UUIDs of cards received from others (for history/sharing tracking)

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
    this.customLinks = const [],
    this.profileImagePath,
    CardAesthetics? cardAesthetics,
    required this.lastUpdated,
    this.isActive = false,
    String? cachedNfcPayload,
    String? cachedVCard,
    String? cachedCardUrl,
    DateTime? dualPayloadCacheTime,
    this.receivedCardUuids = const [],
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
    List<CustomLink>? customLinks,
    String? profileImagePath,
    CardAesthetics? cardAesthetics,
    DateTime? lastUpdated,
    bool? isActive,
    String? cachedNfcPayload,
    String? cachedVCard,
    String? cachedCardUrl,
    DateTime? dualPayloadCacheTime,
    List<String>? receivedCardUuids,
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
      customLinks: customLinks ?? this.customLinks,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      cardAesthetics: cardAesthetics ?? this.cardAesthetics,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
      cachedNfcPayload: cachedNfcPayload ?? _cachedNfcPayload,
      cachedVCard: cachedVCard ?? _cachedVCard,
      cachedCardUrl: cachedCardUrl ?? _cachedCardUrl,
      dualPayloadCacheTime: dualPayloadCacheTime ?? _dualPayloadCacheTime,
      receivedCardUuids: receivedCardUuids ?? this.receivedCardUuids,
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
      'customLinks': customLinks.map((link) => link.toJson()).toList(),
      'profileImagePath': profileImagePath,
      'cardAesthetics': cardAesthetics.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
      'cachedNfcPayload': _cachedNfcPayload,
      'cachedVCard': _cachedVCard,
      'cachedCardUrl': _cachedCardUrl,
      'dualPayloadCacheTime': _dualPayloadCacheTime?.toIso8601String(),
      'receivedCardUuids': receivedCardUuids,
    };
  }

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final type = ProfileType.values.firstWhere((e) => e.name == json['type']);

    // Parse custom links with backward compatibility
    List<CustomLink> customLinks = [];
    if (json['customLinks'] != null) {
      customLinks = (json['customLinks'] as List)
          .map((linkJson) => CustomLink.fromJson(linkJson))
          .toList();
    }

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
      customLinks: customLinks,
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
      receivedCardUuids: (json['receivedCardUuids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
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
      'a': 'al',  // Shortened app identifier (Atlas Linq)
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
  String _generateOptimizedVCard({ShareContext? shareContext}) {
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

    // Build NOTE field with embedded metadata
    // flutter_contacts properly parses NOTE field, so we embed X-AL metadata here
    final noteLines = <String>[];

    // Add primary note text
    if (website != null && website!.isNotEmpty) {
      noteLines.add('View full digital card: ${_generateCardUrl()}');
    }
    noteLines.add('Shared via Atlas Linq');

    // Embed X-AL metadata in NOTE field (~40 bytes overhead)
    // This ensures flutter_contacts can actually read the metadata
    if (shareContext != null) {
      noteLines.add('X-AL-M:${shareContext.methodCode}');  // Method code (N/Q/W/T)
      noteLines.add('X-AL-T:${shareContext.unixTimestamp}');  // Unix timestamp
      noteLines.add('X-AL-P:${type.code}');  // Profile type (1/2/3)
    }

    // Write URL (user's website OR Atlas Linq URL)
    if (website != null && website!.isNotEmpty) {
      buffer.write('URL:$website\n');
    } else {
      buffer.write('URL:${_generateCardUrl()}\n');
    }

    // Write combined NOTE field with embedded metadata
    buffer.write('NOTE:${noteLines.join('\\n')}\n');

    buffer.write('END:VCARD');
    return buffer.toString();
  }

  /// Generate custom URL for full digital profile using UUID + type format
  /// URL pattern: https://atlaslinq.com/share/[uuid]_[type]
  ///
  /// Benefits:
  /// - Globally unique (no collisions for same names)
  /// - Backend-ready (UUID_type = Firebase document ID)
  /// - Enables proper contact-to-profile linking
  /// - Profile type embedded in URL for easy identification
  /// - Ready for web profile viewer and analytics
  ///
  /// URL is clickable in saved contact → opens full card with all info, analytics
  String _generateCardUrl() {
    return 'https://atlaslinq.com/share/${id}_${type.name}';
  }

  /// Check if dual payload cache is stale (>5 minutes old or missing)
  bool get needsDualPayloadCacheUpdate {
    if (_cachedVCard == null || _cachedCardUrl == null) return true;
    if (_dualPayloadCacheTime == null) return true;

    final age = DateTime.now().difference(_dualPayloadCacheTime!);
    return age.inMinutes > 5;
  }

  /// Regenerate dual-payload cache (vCard + URL)
  ProfileData regenerateDualPayloadCache({ShareContext? shareContext}) {
    final vCard = _generateOptimizedVCard(shareContext: shareContext);
    final url = _generateCardUrl();
    final now = DateTime.now();

    developer.log(
      '🔄 Regenerating dual-payload cache\n'
      '   • vCard: ${vCard.length} bytes\n'
      '   • URL: ${url.length} bytes\n'
      '   • Total: ${vCard.length + url.length} bytes\n'
      '   • Has metadata: ${shareContext != null}',
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

  /// Get dual payload with real-time sharing context (generates fresh metadata)
  /// Use this when actually sharing to embed current timestamp & method
  Map<String, String> getDualPayloadWithContext(ShareContext shareContext) {
    final vCard = _generateOptimizedVCard(shareContext: shareContext);
    final url = _cachedCardUrl ?? _generateCardUrl();

    developer.log(
      '📤 Generating payload with context\n'
      '   • Method: ${shareContext.method.label}\n'
      '   • Timestamp: ${shareContext.timestamp}\n'
      '   • vCard size: ${vCard.length} bytes',
      name: 'ProfileData.DualPayload'
    );

    return {
      'vcard': vCard,
      'url': url,
    };
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

/// Minimal context for tracking how a profile was shared
/// Optimized for vCard embedding with minimal byte overhead (~40 bytes)
class ShareContext {
  final ShareMethod method;
  final DateTime timestamp;

  const ShareContext({
    required this.method,
    required this.timestamp,
  });

  /// Encode method to single character for vCard
  /// N=NFC, Q=QR, W=Web, T=Tag
  String get methodCode {
    switch (method) {
      case ShareMethod.nfc:   return 'N';
      case ShareMethod.qr:    return 'Q';
      case ShareMethod.web:   return 'W';
      case ShareMethod.tag:   return 'T';
    }
  }

  /// Decode method from single character
  static ShareMethod methodFromCode(String code) {
    switch (code.toUpperCase()) {
      case 'N': return ShareMethod.nfc;
      case 'Q': return ShareMethod.qr;
      case 'W': return ShareMethod.web;
      case 'T': return ShareMethod.tag;
      case 'L': return ShareMethod.web; // Legacy: 'L' was link, now web
      default:  return ShareMethod.nfc; // fallback
    }
  }

  /// Unix timestamp for compact storage
  int get unixTimestamp => timestamp.millisecondsSinceEpoch ~/ 1000;

  /// Create DateTime from unix timestamp
  static DateTime timestampFromUnix(int unix) {
    return DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  }
}