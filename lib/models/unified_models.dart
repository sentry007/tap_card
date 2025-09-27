import 'dart:math';

// Re-export ProfileData and related models from profile_models.dart
export '../core/models/profile_models.dart';

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

  SharePayload({
    required this.data,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to JSON for NFC
  Map<String, dynamic> toJson() {
    return {
      'app': app,
      'version': version,
      'data': data.toJson(),
      'timestamp': timestamp,
    };
  }

  /// Create from JSON
  factory SharePayload.fromJson(Map<String, dynamic> json) {
    return SharePayload(
      data: ContactData.fromJson(json['data']),
      timestamp: json['timestamp'],
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