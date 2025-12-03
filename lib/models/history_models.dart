/// History Data Models
///
/// Comprehensive models for tracking all sharing activity including:
/// - Sent cards (NFC/QR/Link)
/// - Received cards (with full sender profile)
/// - NFC tag writes
///
/// Features:
/// - Method tracking (NFC, QR, Link, Tag)
/// - Full ProfileData storage for received cards
/// - Soft delete support for sent items
/// - Rich metadata (location, device info)
library;

import '../core/models/profile_models.dart';

/// Method used to share contact information
enum ShareMethod {
  nfc,        // NFC tap to phone
  qr,         // QR code scan
  web,        // Web-based (URL share, downloads)
  tag,        // Written to NFC tag (sticker/card)
  quickShare, // Quick Share (Android) / AirDrop (iOS)
}

/// Type of history entry
enum HistoryEntryType {
  sent,     // You sent your card to someone
  received, // You received someone's card
  tag,      // You wrote to an NFC tag
}

/// Comprehensive history entry model
class HistoryEntry {
  final String id;
  final HistoryEntryType type;
  final ShareMethod method;
  final DateTime timestamp;

  // For sent items (we don't know much about recipient)
  final String? recipientName;
  final String? recipientDevice;
  final String? location;

  // For received items (full profile data from sender)
  final ProfileData? senderProfile;

  // For tag writes
  final String? tagId;
  final String? tagType; // NTAG213/215/216
  final int? tagCapacity; // bytes
  final String? payloadType; // "dual" or "url"
  final String? writtenProfileName; // Name of profile written to tag
  final ProfileType? writtenProfileType; // Type of profile written to tag

  // Common metadata
  final Map<String, dynamic>? metadata;

  // Soft delete (for sent items only)
  final bool isSoftDeleted;

  // Orphaned card tracking (vCard deleted from device but UID retained)
  final bool isOrphanedCard;

  // Profile UID for cross-device sync and UID retention
  final String? profileUid;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.method,
    required this.timestamp,
    this.recipientName,
    this.recipientDevice,
    this.location,
    this.senderProfile,
    this.tagId,
    this.tagType,
    this.tagCapacity,
    this.payloadType,
    this.writtenProfileName,
    this.writtenProfileType,
    this.metadata,
    this.isSoftDeleted = false,
    this.isOrphanedCard = false,
    this.profileUid,
  });

  /// Create a sent entry
  factory HistoryEntry.sent({
    required String id,
    required ShareMethod method,
    required DateTime timestamp,
    String? recipientName,
    String? recipientDevice,
    String? location,
    Map<String, dynamic>? metadata,
  }) {
    return HistoryEntry(
      id: id,
      type: HistoryEntryType.sent,
      method: method,
      timestamp: timestamp,
      recipientName: recipientName,
      recipientDevice: recipientDevice,
      location: location,
      metadata: metadata,
    );
  }

  /// Create a received entry
  factory HistoryEntry.received({
    required String id,
    required ShareMethod method,
    required DateTime timestamp,
    required ProfileData senderProfile,
    String? location,
    Map<String, dynamic>? metadata,
    bool isOrphanedCard = false,
    String? profileUid,
  }) {
    return HistoryEntry(
      id: id,
      type: HistoryEntryType.received,
      method: method,
      timestamp: timestamp,
      senderProfile: senderProfile,
      location: location,
      metadata: metadata,
      isOrphanedCard: isOrphanedCard,
      profileUid: profileUid ?? senderProfile.id,
    );
  }

  /// Create a tag write entry
  factory HistoryEntry.tag({
    required String id,
    required ShareMethod method,
    required DateTime timestamp,
    required String tagId,
    required String tagType,
    required String writtenProfileName,
    required ProfileType writtenProfileType,
    int? tagCapacity,
    String? payloadType,
    String? location,
    Map<String, dynamic>? metadata,
  }) {
    return HistoryEntry(
      id: id,
      type: HistoryEntryType.tag,
      method: method,
      timestamp: timestamp,
      tagId: tagId,
      tagType: tagType,
      tagCapacity: tagCapacity,
      payloadType: payloadType,
      writtenProfileName: writtenProfileName,
      writtenProfileType: writtenProfileType,
      location: location,
      metadata: metadata,
    );
  }

  /// Copy with updated fields
  HistoryEntry copyWith({
    String? id,
    HistoryEntryType? type,
    ShareMethod? method,
    DateTime? timestamp,
    String? recipientName,
    String? recipientDevice,
    String? location,
    ProfileData? senderProfile,
    String? tagId,
    String? tagType,
    int? tagCapacity,
    String? payloadType,
    String? writtenProfileName,
    ProfileType? writtenProfileType,
    Map<String, dynamic>? metadata,
    bool? isSoftDeleted,
    bool? isOrphanedCard,
    String? profileUid,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      method: method ?? this.method,
      timestamp: timestamp ?? this.timestamp,
      recipientName: recipientName ?? this.recipientName,
      recipientDevice: recipientDevice ?? this.recipientDevice,
      location: location ?? this.location,
      senderProfile: senderProfile ?? this.senderProfile,
      tagId: tagId ?? this.tagId,
      tagType: tagType ?? this.tagType,
      tagCapacity: tagCapacity ?? this.tagCapacity,
      payloadType: payloadType ?? this.payloadType,
      writtenProfileName: writtenProfileName ?? this.writtenProfileName,
      writtenProfileType: writtenProfileType ?? this.writtenProfileType,
      metadata: metadata ?? this.metadata,
      isSoftDeleted: isSoftDeleted ?? this.isSoftDeleted,
      isOrphanedCard: isOrphanedCard ?? this.isOrphanedCard,
      profileUid: profileUid ?? this.profileUid,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'method': method.name,
      'timestamp': timestamp.toIso8601String(),
      if (recipientName != null) 'recipientName': recipientName,
      if (recipientDevice != null) 'recipientDevice': recipientDevice,
      if (location != null) 'location': location,
      if (senderProfile != null) 'senderProfile': senderProfile!.toJson(),
      if (tagId != null) 'tagId': tagId,
      if (tagType != null) 'tagType': tagType,
      if (tagCapacity != null) 'tagCapacity': tagCapacity,
      if (payloadType != null) 'payloadType': payloadType,
      if (writtenProfileName != null) 'writtenProfileName': writtenProfileName,
      if (writtenProfileType != null) 'writtenProfileType': writtenProfileType!.name,
      if (metadata != null) 'metadata': metadata,
      'isSoftDeleted': isSoftDeleted,
      'isOrphanedCard': isOrphanedCard,
      if (profileUid != null) 'profileUid': profileUid,
    };
  }

  /// Create from JSON
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'],
      type: HistoryEntryType.values.firstWhere((e) => e.name == json['type']),
      method: ShareMethod.values.firstWhere((e) => e.name == json['method']),
      timestamp: DateTime.parse(json['timestamp']),
      recipientName: json['recipientName'],
      recipientDevice: json['recipientDevice'],
      location: json['location'],
      senderProfile: json['senderProfile'] != null
          ? ProfileData.fromJson(json['senderProfile'])
          : null,
      tagId: json['tagId'],
      tagType: json['tagType'],
      tagCapacity: json['tagCapacity'],
      payloadType: json['payloadType'],
      writtenProfileName: json['writtenProfileName'],
      writtenProfileType: json['writtenProfileType'] != null
          ? ProfileType.values.firstWhere((e) => e.name == json['writtenProfileType'])
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      isSoftDeleted: json['isSoftDeleted'] ?? false,
      isOrphanedCard: json['isOrphanedCard'] ?? false,
      profileUid: json['profileUid'],
    );
  }

  /// Get display name based on type
  String get displayName {
    switch (type) {
      case HistoryEntryType.sent:
        return recipientName ?? 'Unknown';
      case HistoryEntryType.received:
        return senderProfile?.name ?? 'Unknown';
      case HistoryEntryType.tag:
        if (writtenProfileType != null) {
          return '${writtenProfileType!.label} Card';
        }
        return 'Card';
    }
  }

  /// Get subtitle text
  String get subtitle {
    switch (type) {
      case HistoryEntryType.sent:
        return recipientDevice ?? 'Sent';
      case HistoryEntryType.received:
        // Try: company > title > email > phone > type label > 'Received'
        if (senderProfile?.company != null && senderProfile!.company!.isNotEmpty) {
          return senderProfile!.company!;
        }
        if (senderProfile?.title != null && senderProfile!.title!.isNotEmpty) {
          return senderProfile!.title!;
        }
        if (senderProfile?.email != null && senderProfile!.email!.isNotEmpty) {
          return senderProfile!.email!;
        }
        if (senderProfile?.phone != null && senderProfile!.phone!.isNotEmpty) {
          return senderProfile!.phone!;
        }
        // Fallback to profile type label
        return senderProfile?.type.label ?? 'Received';
      case HistoryEntryType.tag:
        // Show tag type and capacity if available
        if (tagType != null && tagCapacity != null) {
          return '$tagType ($tagCapacity bytes)';
        } else if (tagType != null) {
          return tagType!;
        }
        return 'NFC Tag';
    }
  }

  @override
  String toString() {
    return 'HistoryEntry(id: $id, type: $type, method: $method, name: $displayName)';
  }
}

/// Extension methods for ShareMethod
extension ShareMethodExtension on ShareMethod {
  String get label {
    switch (this) {
      case ShareMethod.nfc:
        return 'NFC';
      case ShareMethod.qr:
        return 'QR';
      case ShareMethod.web:
        return 'Web';
      case ShareMethod.tag:
        return 'Tag';
      case ShareMethod.quickShare:
        return 'Quick Share';
    }
  }

  String get description {
    switch (this) {
      case ShareMethod.nfc:
        return 'NFC Tap';
      case ShareMethod.qr:
        return 'QR Code';
      case ShareMethod.web:
        return 'Web/Link';
      case ShareMethod.tag:
        return 'NFC Tag';
      case ShareMethod.quickShare:
        return 'Quick Share / AirDrop';
    }
  }
}

/// Extension methods for HistoryEntryType
extension HistoryEntryTypeExtension on HistoryEntryType {
  String get label {
    switch (this) {
      case HistoryEntryType.sent:
        return 'Sent';
      case HistoryEntryType.received:
        return 'Received';
      case HistoryEntryType.tag:
        return 'Via Tag';
    }
  }

  String get description {
    switch (this) {
      case HistoryEntryType.sent:
        return 'Shared your contact';
      case HistoryEntryType.received:
        return 'Received contact';
      case HistoryEntryType.tag:
        return 'Wrote to NFC tag';
    }
  }
}
