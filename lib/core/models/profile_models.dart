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
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
  final String? _cachedOptimizedVCard; // Optimized vCard for NFC (no photo)
  final String? _cachedRichVCard; // Rich vCard with photo for Quick Share/QR
  final String? _cachedCardUrl; // Pre-computed URL
  final DateTime? _payloadCacheTime; // When payloads were last generated
  // NOTE: receivedCardUuids removed - ReceivedCardsRepository is now the single source of truth

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
    String? cachedOptimizedVCard,
    String? cachedRichVCard,
    String? cachedCardUrl,
    DateTime? payloadCacheTime,
  }) : cardAesthetics = cardAesthetics ?? CardAesthetics.defaultForType(type),
       _cachedOptimizedVCard = cachedOptimizedVCard,
       _cachedRichVCard = cachedRichVCard,
       _cachedCardUrl = cachedCardUrl,
       _payloadCacheTime = payloadCacheTime;

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
    String? cachedOptimizedVCard,
    String? cachedRichVCard,
    String? cachedCardUrl,
    DateTime? payloadCacheTime,
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
      cachedOptimizedVCard: cachedOptimizedVCard ?? _cachedOptimizedVCard,
      cachedRichVCard: cachedRichVCard ?? _cachedRichVCard,
      cachedCardUrl: cachedCardUrl ?? _cachedCardUrl,
      payloadCacheTime: payloadCacheTime ?? _payloadCacheTime,
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
      'cachedOptimizedVCard': _cachedOptimizedVCard,
      'cachedRichVCard': _cachedRichVCard,
      'cachedCardUrl': _cachedCardUrl,
      'payloadCacheTime': _payloadCacheTime?.toIso8601String(),
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
      // Support both old and new field names for backward compatibility
      cachedOptimizedVCard: json['cachedOptimizedVCard'] ?? json['cachedVCard'],
      cachedRichVCard: json['cachedRichVCard'],
      cachedCardUrl: json['cachedCardUrl'],
      payloadCacheTime: json['payloadCacheTime'] != null
        ? DateTime.parse(json['payloadCacheTime'])
        : (json['dualPayloadCacheTime'] != null
            ? DateTime.parse(json['dualPayloadCacheTime'])
            : null),
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
    // Generate initial payload cache
    return profile.regeneratePayloadCache();
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

  // ============================================================================
  // PAYLOAD GENERATION (Consolidated vCard + URL)
  // ============================================================================

  /// Cache TTL - payloads are refreshed after 5 minutes
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Check if payload cache is stale (>5 minutes old or missing)
  bool get needsPayloadCacheUpdate {
    if (_cachedOptimizedVCard == null || _cachedCardUrl == null) return true;
    if (_payloadCacheTime == null) return true;

    final age = DateTime.now().difference(_payloadCacheTime!);
    return age > _cacheTtl;
  }

  /// Get the card URL (cached or generated fresh)
  String get cardUrl => _cachedCardUrl ?? _generateCardUrl();

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

    // ALWAYS write AtlasLinq URL as primary URL field
    // This ensures receivers can always access the full digital card
    buffer.write('URL:${_generateCardUrl()}\n');

    // If user has custom website, add it as secondary URL
    if (website != null && website!.isNotEmpty) {
      buffer.write('URL;TYPE=WORK:$website\n');
    }

    // Build NOTE field with embedded metadata
    // flutter_contacts properly parses NOTE field, so we embed X-AL metadata here
    final noteLines = <String>[];

    // Add primary note text (no longer includes AtlasLinq URL since it's in URL field)
    noteLines.add('Shared via Atlas Linq');

    // Embed X-AL metadata in NOTE field (~40 bytes overhead)
    // This ensures flutter_contacts can actually read the metadata
    if (shareContext != null) {
      noteLines.add('X-AL-M:${shareContext.methodCode}');  // Method code (N/Q/W/T)
      noteLines.add('X-AL-T:${shareContext.unixTimestamp}');  // Unix timestamp
      noteLines.add('X-AL-P:${type.code}');  // Profile type (1/2/3)
    }

    // Write combined NOTE field with embedded metadata
    buffer.write('NOTE:${noteLines.join('\\n')}\n');

    buffer.write('END:VCARD');
    return buffer.toString();
  }

  /// Generate rich vCard for AirDrop sharing (includes profile photo)
  ///
  /// Unlike the optimized NFC vCard, this version includes:
  /// - Full title (no truncation)
  /// - Profile photo as Base64 JPEG (compressed ~200x200)
  /// - All contact fields
  ///
  /// AirDrop has no file size limit, so we can include the photo.
  /// iOS requires Base64 encoding with 75-char line folding.
  Future<String> _generateRichVCard({ShareContext? shareContext}) async {
    final buffer = StringBuffer();
    buffer.write('BEGIN:VCARD\n');
    buffer.write('VERSION:3.0\n');
    buffer.write('FN:$name\n');

    // Structured name parsing
    final nameParts = name.split(' ').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (nameParts.length >= 2) {
      buffer.write('N:${nameParts.last};${nameParts.first};;;\n');
    } else {
      buffer.write('N:$name;;;;\n');
    }

    // Title (full length - no truncation for AirDrop)
    if (title != null && title!.isNotEmpty) {
      buffer.write('TITLE:$title\n');
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

    // Atlas Linq URL as primary URL
    buffer.write('URL:${_generateCardUrl()}\n');

    // Custom website as secondary URL
    if (website != null && website!.isNotEmpty) {
      buffer.write('URL;TYPE=WORK:$website\n');
    }

    // Profile photo (if available)
    if (profileImagePath != null && profileImagePath!.isNotEmpty) {
      final photoBase64 = await _encodeProfilePhotoForVCard();
      if (photoBase64 != null) {
        buffer.write(photoBase64);
      }
    }

    // NOTE field with metadata
    final noteLines = <String>[];
    noteLines.add('Shared via Atlas Linq');
    if (shareContext != null) {
      noteLines.add('X-AL-M:${shareContext.methodCode}');
      noteLines.add('X-AL-T:${shareContext.unixTimestamp}');
      noteLines.add('X-AL-P:${type.code}');
    }
    buffer.write('NOTE:${noteLines.join('\\n')}\n');

    buffer.write('END:VCARD');
    return buffer.toString();
  }

  /// Encode profile photo as Base64 for vCard with proper line folding
  ///
  /// iOS vCard 3.0 requirements:
  /// - Format: PHOTO;TYPE=JPEG;ENCODING=b:[base64]
  /// - Lines must be folded at 75 characters
  /// - Continuation lines start with a space
  ///
  /// Supports both local file paths and HTTP/HTTPS URLs (Firebase Storage)
  Future<String?> _encodeProfilePhotoForVCard() async {
    try {
      Uint8List bytes;

      // Handle both local paths and URLs
      if (profileImagePath!.startsWith('http://') ||
          profileImagePath!.startsWith('https://')) {
        // Download from URL (Firebase Storage, etc.)
        developer.log('📥 Downloading profile image from URL: $profileImagePath',
            name: 'ProfileData.Photo');
        final response = await http.get(Uri.parse(profileImagePath!));
        if (response.statusCode != 200) {
          developer.log('Failed to download image: HTTP ${response.statusCode}',
              name: 'ProfileData.Photo');
          return null;
        }
        bytes = response.bodyBytes;
        developer.log('✅ Downloaded ${bytes.length} bytes from URL',
            name: 'ProfileData.Photo');
      } else {
        // Read from local file
        final file = File(profileImagePath!);
        if (!await file.exists()) {
          developer.log('Profile image not found: $profileImagePath',
              name: 'ProfileData.Photo');
          return null;
        }
        bytes = await file.readAsBytes();
      }

      // Decode image
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        developer.log('Failed to decode profile image', name: 'ProfileData.Photo');
        return null;
      }

      // Resize to ~200x200 for reasonable vCard size
      // Maintain aspect ratio
      const maxDimension = 200;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width > image.height) {
          image = img.copyResize(image, width: maxDimension);
        } else {
          image = img.copyResize(image, height: maxDimension);
        }
      }

      // Encode as JPEG with quality 80
      final jpegBytes = img.encodeJpg(image, quality: 80);
      final base64String = base64Encode(jpegBytes);

      // Build vCard PHOTO field with 75-char line folding
      final buffer = StringBuffer();
      buffer.write('PHOTO;TYPE=JPEG;ENCODING=b:');

      // Fold lines at 75 characters (continuation lines start with space)
      String remaining = base64String;
      bool firstLine = true;
      while (remaining.isNotEmpty) {
        if (firstLine) {
          // First line: header already written, add first chunk
          final chunk = remaining.length > 47 ? remaining.substring(0, 47) : remaining;
          buffer.write('$chunk\n');
          remaining = remaining.length > 47 ? remaining.substring(47) : '';
          firstLine = false;
        } else {
          // Continuation lines: start with space, then 74 chars of data
          final chunk = remaining.length > 74 ? remaining.substring(0, 74) : remaining;
          buffer.write(' $chunk\n');
          remaining = remaining.length > 74 ? remaining.substring(74) : '';
        }
      }

      developer.log(
        '📷 Photo encoded for vCard\n'
        '   • Original: ${bytes.length} bytes\n'
        '   • Resized: ${image.width}x${image.height}\n'
        '   • JPEG: ${jpegBytes.length} bytes\n'
        '   • Base64: ${base64String.length} chars',
        name: 'ProfileData.Photo'
      );

      return buffer.toString();
    } catch (e) {
      developer.log('Failed to encode profile photo: $e', name: 'ProfileData.Photo', error: e);
      return null;
    }
  }

  /// Get rich vCard for AirDrop sharing (async, with photo)
  ///
  /// Use this for iOS AirDrop sharing where file size is not a constraint.
  /// Returns a full vCard with embedded profile photo.
  Future<String> getRichVCardForAirDrop(ShareContext shareContext) async {
    final vCard = await _generateRichVCard(shareContext: shareContext);

    developer.log(
      '📤 Rich vCard generated for AirDrop\n'
      '   • Method: ${shareContext.method.label}\n'
      '   • Size: ${vCard.length} bytes\n'
      '   • Has photo: ${profileImagePath != null}',
      name: 'ProfileData.RichVCard'
    );

    return vCard;
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

  /// Regenerate all payload caches (optimized vCard + URL)
  /// Call this when profile data changes or cache expires
  ProfileData regeneratePayloadCache({ShareContext? shareContext}) {
    final vCard = _generateOptimizedVCard(shareContext: shareContext);
    final url = _generateCardUrl();
    final now = DateTime.now();

    developer.log(
      '🔄 Regenerating payload cache\n'
      '   • Optimized vCard: ${vCard.length} bytes\n'
      '   • URL: ${url.length} bytes\n'
      '   • Total: ${vCard.length + url.length} bytes\n'
      '   • Has metadata: ${shareContext != null}',
      name: 'ProfileData.Cache'
    );

    return copyWith(
      cachedOptimizedVCard: vCard,
      cachedCardUrl: url,
      payloadCacheTime: now,
      lastUpdated: now,
    );
  }

  /// Pre-cache all payloads including rich vCard (async)
  /// Call this on profile load for instant sharing
  Future<ProfileData> preCacheAllPayloads({ShareContext? shareContext}) async {
    final optimizedVCard = _generateOptimizedVCard(shareContext: shareContext);
    final richVCard = await _generateRichVCard(shareContext: shareContext);
    final url = _generateCardUrl();
    final now = DateTime.now();

    developer.log(
      '🚀 Pre-caching all payloads\n'
      '   • Optimized vCard: ${optimizedVCard.length} bytes\n'
      '   • Rich vCard: ${richVCard.length} bytes\n'
      '   • URL: ${url.length} bytes',
      name: 'ProfileData.Cache'
    );

    return copyWith(
      cachedOptimizedVCard: optimizedVCard,
      cachedRichVCard: richVCard,
      cachedCardUrl: url,
      payloadCacheTime: now,
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
    if (_cachedOptimizedVCard != null && _cachedCardUrl != null && !needsPayloadCacheUpdate) {
      developer.log(
        '✅ Using cached dual-payload (instant!)\n'
        '   • vCard: ${_cachedOptimizedVCard!.length} bytes\n'
        '   • URL: ${_cachedCardUrl!.length} bytes',
        name: 'ProfileData.DualPayload'
      );
      return {
        'vcard': _cachedOptimizedVCard!,
        'url': _cachedCardUrl!,
      };
    }

    // Cache is stale/missing - regenerate
    developer.log(
      '⚠️ Dual-payload cache expired, regenerating...',
      name: 'ProfileData.DualPayload'
    );
    final freshProfile = regeneratePayloadCache();
    return {
      'vcard': freshProfile._cachedOptimizedVCard!,
      'url': freshProfile._cachedCardUrl!,
    };
  }

  /// Get cached rich vCard if available, otherwise null
  /// Use getRichVCardForAirDrop() for async generation with photo
  String? get cachedRichVCard => _cachedRichVCard;
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
  /// N=NFC, Q=QR, W=Web, T=Tag, S=QuickShare
  String get methodCode {
    switch (method) {
      case ShareMethod.nfc:        return 'N';
      case ShareMethod.qr:         return 'Q';
      case ShareMethod.web:        return 'W';
      case ShareMethod.tag:        return 'T';
      case ShareMethod.quickShare: return 'S';
    }
  }

  /// Decode method from single character
  static ShareMethod methodFromCode(String code) {
    switch (code.toUpperCase()) {
      case 'N': return ShareMethod.nfc;
      case 'Q': return ShareMethod.qr;
      case 'W': return ShareMethod.web;
      case 'T': return ShareMethod.tag;
      case 'S': return ShareMethod.quickShare;
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