import 'dart:convert';
import 'dart:developer' as developer;
import '../core/models/profile_models.dart';
import '../core/constants/security_constants.dart';

/// Input Validation Service
///
/// Validates all user inputs and external data before processing
/// Prevents XSS, injection attacks, and data corruption
///
/// Phase 1: Warning mode - logs issues but doesn't block
/// Phase 2: Enforcement mode - blocks invalid data
class ValidationService {
  // Feature flag - set to true to enforce (block invalid data)
  // Currently false = warning mode (log only)
  static bool enforceValidation = false;

  // ====================
  // Email Validation
  // ====================

  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return true; // Optional field

    // RFC 5322 simplified regex
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return email.length <= SecurityConstants.maxEmailLength &&
        regex.hasMatch(email);
  }

  // ====================
  // Phone Validation
  // ====================

  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return true; // Optional field

    // Remove common formatting characters
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');

    // Must start with + or digit, and be 10-15 digits
    final regex = RegExp(r'^\+?[\d]{10,15}$');

    return cleaned.length <= SecurityConstants.maxPhoneLength &&
        regex.hasMatch(cleaned);
  }

  // ====================
  // URL Validation
  // ====================

  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return true; // Optional field

    if (url.length > SecurityConstants.maxUrlLength) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  // ====================
  // Name Validation
  // ====================

  static bool isValidName(String? name) {
    if (name == null || name.isEmpty) return false; // Required field

    if (name.length > SecurityConstants.maxNameLength) return false;

    // Allow letters, numbers, spaces, hyphens, apostrophes, periods
    // Prevents XSS: no <, >, &, ", ', `, =, etc.
    final regex = RegExp(r'^[a-zA-Z0-9\s\-\x27\.]+$');

    return regex.hasMatch(name);
  }

  // ====================
  // String Sanitization
  // ====================

  static String sanitizeString(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[<>&"\x27`=]'), '') // Remove dangerous chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  // ====================
  // Profile Validation
  // ====================

  static ValidationResult validateProfile(ProfileData profile) {
    final errors = <String>[];
    final warnings = <String>[];

    // Name (required)
    if (profile.name.isEmpty) {
      errors.add('Name is required');
    } else if (!isValidName(profile.name)) {
      errors.add('Name contains invalid characters or is too long');
      warnings.add(
          'Name should only contain letters, numbers, spaces, hyphens, apostrophes, and periods');
    }

    // Email (optional but must be valid if provided)
    if (profile.email != null && profile.email!.isNotEmpty) {
      if (!isValidEmail(profile.email)) {
        errors.add('Email format is invalid');
        warnings.add(
            'Email must be a valid email address (e.g., user@example.com)');
      }
    }

    // Phone (optional but must be valid if provided)
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      if (!isValidPhone(profile.phone)) {
        errors.add('Phone format is invalid');
        warnings
            .add('Phone must be 10-15 digits, optionally starting with +');
      }
    }

    // Website (optional but must be valid if provided)
    if (profile.website != null && profile.website!.isNotEmpty) {
      if (!isValidUrl(profile.website)) {
        errors.add('Website URL is invalid');
        warnings.add('Website must be a valid HTTP or HTTPS URL');
      }
    }

    // Company (optional, but validate if present)
    if (profile.company != null && profile.company!.isNotEmpty) {
      if (profile.company!.length > SecurityConstants.maxNameLength) {
        errors.add('Company name is too long');
      }
    }

    // Title (optional, but validate if present)
    if (profile.title != null && profile.title!.isNotEmpty) {
      if (profile.title!.length > SecurityConstants.maxNameLength) {
        errors.add('Title is too long');
      }
    }

    // Social media links validation
    profile.socialMedia.forEach((platform, url) {
      if (!isValidUrl(url)) {
        errors.add('Invalid URL for $platform');
      }
    });

    // Custom links validation
    for (final link in profile.customLinks) {
      if (!link.isValid) {
        errors.add('Custom link "${link.title}" is incomplete');
      }
      if (!isValidUrl(link.url)) {
        errors.add('Invalid URL for custom link "${link.title}"');
      }
    }

    // Log validation results
    if (errors.isNotEmpty) {
      developer.log(
        '⚠️ Profile validation failed:\n'
        '   Profile: ${profile.name}\n'
        '   Errors: ${errors.join(", ")}\n'
        '   Warnings: ${warnings.join(", ")}',
        name: 'ValidationService',
      );
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  // ====================
  // NFC Data Validation
  // ====================

  static ValidationResult validateNfcData(Map<String, dynamic> data) {
    final errors = <String>[];

    // Check required app identifier
    if (!data.containsKey('app') && !data.containsKey('a')) {
      errors.add('Missing app identifier');
    } else {
      final appId = data['app'] ?? data['a'];
      if (appId != 'tap_card' && appId != 'tc') {
        errors.add('Invalid app identifier: $appId');
      }
    }

    // Check for contact data
    final contactData = data['data'] ?? data['d'];
    if (contactData == null) {
      errors.add('Missing contact data');
    } else if (contactData is! Map) {
      errors.add('Contact data must be an object');
    } else {
      // Validate contact has name
      final name = contactData['name'] ?? contactData['n'];
      if (name == null || name.toString().isEmpty) {
        errors.add('Contact must have a name');
      }
    }

    // Size check (prevent DoS attacks)
    try {
      final jsonString = jsonEncode(data);
      if (jsonString.length > SecurityConstants.maxNfcPayloadSize) {
        errors.add(
            'NFC payload too large (${jsonString.length} > ${SecurityConstants.maxNfcPayloadSize} bytes)');
      }
    } catch (e) {
      errors.add('Failed to serialize NFC data: $e');
    }

    if (errors.isNotEmpty) {
      developer.log(
        '⚠️ NFC data validation failed:\n'
        '   Errors: ${errors.join(", ")}',
        name: 'ValidationService',
      );
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: [],
    );
  }

  // ====================
  // Image File Validation
  // ====================

  static ValidationResult validateImageFile(String path, int sizeBytes) {
    final errors = <String>[];

    // Check file extension
    final extension = path.split('.').last.toLowerCase();
    if (!SecurityConstants.allowedImageExtensions.contains(extension)) {
      errors.add(
          'Invalid image format. Allowed: ${SecurityConstants.allowedImageExtensions.join(", ")}');
    }

    // Check file size
    if (sizeBytes > SecurityConstants.maxImageSizeBytes) {
      final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);
      final maxMB =
          (SecurityConstants.maxImageSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      errors.add('Image too large ($sizeMB MB > $maxMB MB max)');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: [],
    );
  }
}

/// Validation result object
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    this.warnings = const [],
  });

  /// Get user-friendly error message
  String get userMessage {
    if (isValid) return '';
    return errors.join('\n');
  }

  /// Check if has warnings (not errors)
  bool get hasWarnings => warnings.isNotEmpty;
}
