import 'dart:math';
import 'dart:developer' as developer;

// Re-export ProfileData and related models from profile_models.dart
export '../core/models/profile_models.dart';
// Re-export history models (ShareMethod, etc.)
export 'history_models.dart';

/// Core contact information that can be shared via NFC
class ContactData {
  final String name;
  final String? title;
  final String? company;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String> socialMedia;

  const ContactData({
    required this.name,
    this.title,
    this.company,
    this.phone,
    this.email,
    this.website,
    this.socialMedia = const {},
  });

  /// Convert to JSON for NFC sharing
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (title != null) 'title': title,
      if (company != null) 'company': company,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (website != null) 'website': website,
      if (socialMedia.isNotEmpty) 'social': socialMedia,
    }..removeWhere((key, value) => value == null);
  }

  /// Create from JSON (received via NFC)
  factory ContactData.fromJson(Map<String, dynamic> json) {
    return ContactData(
      name: json['name'] ?? '',
      title: json['title'],
      company: json['company'],
      phone: json['phone'],
      email: json['email'],
      website: json['website'],
      socialMedia: Map<String, String>.from(json['social'] ?? {}),
    );
  }

  /// Create from ProfileData - will be available after models are re-exported
  factory ContactData.fromProfile(dynamic profile) {
    return ContactData(
      name: profile.name ?? '',
      title: profile.title,
      company: profile.company,
      phone: profile.phone,
      email: profile.email,
      website: profile.website,
      socialMedia: profile.socialMedia ?? <String, String>{},
    );
  }

  /// DEPRECATED: Use ProfileData.dualPayload instead for optimized NFC writes
  ///
  /// This method generates vCard on-demand which causes lag during NFC sharing.
  /// The new approach pre-caches vCard in ProfileData for instant (0ms) access.
  ///
  /// Migration: Instead of contact.toVCard(), use profile.dualPayload['vcard']
  ///
  /// This method is kept for backwards compatibility and fallback scenarios only.
  @deprecated
  String toVCard() {
    developer.log(
      '⚠️ DEPRECATED: ContactData.toVCard() called - use ProfileData.dualPayload instead\n'
      '   This causes on-demand generation lag. Migrate to cached approach.',
      name: 'ContactData.toVCard'
    );

    final buffer = StringBuffer();

    // vCard header
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');

    // Full name (required)
    buffer.writeln('FN:$name');

    // Structured name (FamilyName;GivenName;Additional;Prefix;Suffix)
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      buffer.writeln('N:${nameParts.last};${nameParts.first};;;');
    } else {
      buffer.writeln('N:$name;;;;');
    }

    // Title/Position
    if (title != null && title!.isNotEmpty) {
      buffer.writeln('TITLE:$title');
    }

    // Organization/Company
    if (company != null && company!.isNotEmpty) {
      buffer.writeln('ORG:$company');
    }

    // Phone (Mobile preferred)
    if (phone != null && phone!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL:$phone');
    }

    // Email (Work preferred)
    if (email != null && email!.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=WORK:$email');
    }

    // Website
    if (website != null && website!.isNotEmpty) {
      buffer.writeln('URL:$website');
    }

    // Social media links as URLs
    socialMedia.forEach((platform, handle) {
      final url = _getSocialUrl(platform, handle);
      if (url != null) {
        buffer.writeln('URL:$url');
      }
    });

    // vCard footer
    buffer.writeln('END:VCARD');

    return buffer.toString();
  }

  /// Convert social media handle to full URL
  String? _getSocialUrl(String platform, String handle) {
    // Remove @ symbol if present
    final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;

    switch (platform.toLowerCase()) {
      case 'linkedin':
        return 'https://linkedin.com/in/$cleanHandle';
      case 'twitter':
      case 'x':
        return 'https://twitter.com/$cleanHandle';
      case 'instagram':
        return 'https://instagram.com/$cleanHandle';
      case 'facebook':
        return 'https://facebook.com/$cleanHandle';
      case 'github':
        return 'https://github.com/$cleanHandle';
      default:
        // If it's already a URL, return it
        if (handle.startsWith('http://') || handle.startsWith('https://')) {
          return handle;
        }
        return null;
    }
  }

  /// Generate shareable URL for full digital card
  /// Using YouTube demo link as requested
  String generateCardUrl(String userId) {
    const url = 'https://www.youtube.com/watch?v=xvFZjo5PgG0&list=RDxvFZjo5PgG0&start_radio=1';
    developer.log(
      '🌐 Generated card URL for $name\n'
      '   • User ID: $userId\n'
      '   • URL: $url',
      name: 'ContactData.generateCardUrl'
    );
    return url;
  }

  @override
  String toString() {
    return 'ContactData(name: $name, title: $title, company: $company)';
  }
}

/// Represents a received contact card
class ReceivedContact {
  final String id;
  final ContactData contact;
  final DateTime receivedAt;
  final String? notes;

  const ReceivedContact({
    required this.id,
    required this.contact,
    required this.receivedAt,
    this.notes,
  });

  /// Create copy with updated fields
  ReceivedContact copyWith({
    String? id,
    ContactData? contact,
    DateTime? receivedAt,
    String? notes,
  }) {
    return ReceivedContact(
      id: id ?? this.id,
      contact: contact ?? this.contact,
      receivedAt: receivedAt ?? this.receivedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact': contact.toJson(),
      'received_at': receivedAt.toIso8601String(),
      'notes': notes,
    };
  }

  /// Create from JSON
  factory ReceivedContact.fromJson(Map<String, dynamic> json) {
    return ReceivedContact(
      id: json['id'],
      contact: ContactData.fromJson(json['contact']),
      receivedAt: DateTime.parse(json['received_at']),
      notes: json['notes'],
    );
  }

  /// Generate unique ID for new received contact
  static String generateId() {
    return 'contact_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  @override
  String toString() {
    return 'ReceivedContact(name: ${contact.name}, receivedAt: $receivedAt)';
  }
}

/// Simple share payload for NFC transmission
class SharePayload {
  final String app = "tap_card";
  final String version = "1.0";
  final ContactData data;
  final int timestamp;
  final String? cardUrl;

  SharePayload({
    required this.data,
    int? timestamp,
    this.cardUrl,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to JSON for NFC
  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'version': version,
      'data': data.toJson(),
      'timestamp': timestamp,
      if (cardUrl != null) 'url': cardUrl,
    };
  }

  /// Create dual-payload structure for NFC writing
  /// Returns Map with vCard and URL for native Android to write as 2 NDEF records
  Map<String, dynamic> toDualPayload(String userId) {
    final url = cardUrl ?? data.generateCardUrl(userId);
    return {
      'vcard': data.toVCard(),
      'url': url,
    };
  }

  /// Create from JSON
  factory SharePayload.fromJson(Map<String, dynamic> json) {
    return SharePayload(
      data: ContactData.fromJson(json['data']),
      timestamp: json['timestamp'],
      cardUrl: json['url'],
    );
  }

  /// Validate payload
  bool get isValid {
    return app == 'tap_card' && data.name.isNotEmpty;
  }

  @override
  String toString() {
    return 'SharePayload(app: $app, contact: ${data.name})';
  }
}

// Legacy support for removed models - to be cleaned up
class ShareToken {
  final String token;
  static ShareToken generateLocal(String userId) {
    return ShareToken._('temp_${DateTime.now().millisecondsSinceEpoch}');
  }
  ShareToken._(this.token);
}