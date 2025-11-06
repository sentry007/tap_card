/// History Service
///
/// Manages all sharing history with persistence and real-time updates.
///
/// Features:
/// - CRUD operations for history entries
/// - Real-time stream updates for UI sync
/// - SharedPreferences persistence
/// - Soft delete support for sent items
/// - Rich mock data generation
/// - Filtering by type, method, date range
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/history_models.dart';
import '../core/models/profile_models.dart';
import 'contact_service.dart';
import 'firestore_sync_service.dart';

/// Singleton service for managing sharing history
class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  static const String _historyKey = 'tap_card_history';
  static const String _initKey = 'tap_card_history_initialized';

  // Stream controller for real-time updates
  static final StreamController<List<HistoryEntry>> _historyController =
      StreamController<List<HistoryEntry>>.broadcast();

  // In-memory cache
  static List<HistoryEntry> _cache = [];
  static bool _isInitialized = false;

  /// Initialize history service and load data
  static Future<void> initialize() async {
    if (_isInitialized) return;

    developer.log('🔧 Initializing HistoryService...', name: 'History.Service');

    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstRun = !(prefs.getBool(_initKey) ?? false);

      if (isFirstRun) {
        // First run - generate mock data
        developer.log('📝 First run detected - generating mock history data', name: 'History.Service');
        await _generateMockData();
        await prefs.setBool(_initKey, true);
      } else {
        // Load existing history
        await _loadFromStorage();
      }

      _isInitialized = true;
      developer.log('✅ HistoryService initialized with ${_cache.length} entries', name: 'History.Service');

      // Immediately notify listeners with current data
      _notifyListeners();
    } catch (e) {
      developer.log('❌ Failed to initialize HistoryService: $e', name: 'History.Service', error: e);
    }
  }

  /// Get real-time stream of history entries
  static Stream<List<HistoryEntry>> historyStream() async* {
    // Emit current cache immediately
    final activeEntries = _cache.where((entry) => !entry.isSoftDeleted).toList();
    yield activeEntries;

    // Then emit updates from the stream
    await for (final entries in _historyController.stream) {
      yield entries;
    }
  }

  /// Add a sent entry to history
  static Future<void> addSentEntry({
    required String recipientName,
    required ShareMethod method,
    String? recipientDevice,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final entry = HistoryEntry.sent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: method,
        timestamp: DateTime.now(),
        recipientName: recipientName,
        recipientDevice: recipientDevice,
        location: location,
        metadata: metadata,
      );

      _cache.insert(0, entry); // Add to beginning (most recent first)
      await _saveToStorage();
      _notifyListeners();

      developer.log('📤 Added sent entry: $recipientName via ${method.label}', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to add sent entry: $e', name: 'History.Service', error: e);
    }
  }

  /// Add a received entry to history
  static Future<void> addReceivedEntry({
    required ProfileData senderProfile,
    required ShareMethod method,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final entry = HistoryEntry.received(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: method,
        timestamp: DateTime.now(),
        senderProfile: senderProfile,
        location: location,
        metadata: metadata,
      );

      _cache.insert(0, entry);
      await _saveToStorage();
      _notifyListeners();

      developer.log('📥 Added received entry: ${senderProfile.name} via ${method.label}', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to add received entry: $e', name: 'History.Service', error: e);
    }
  }

  /// Add a tag write entry to history
  static Future<void> addTagEntry({
    required String profileName,
    required ProfileType profileType,
    required String tagId,
    required String tagType,
    required ShareMethod method,
    int? tagCapacity,
    String? payloadType,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final entry = HistoryEntry.tag(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: method,
        timestamp: DateTime.now(),
        writtenProfileName: profileName,
        writtenProfileType: profileType,
        tagId: tagId,
        tagType: tagType,
        tagCapacity: tagCapacity,
        payloadType: payloadType,
        location: location,
        metadata: metadata,
      );

      _cache.insert(0, entry);
      await _saveToStorage();
      _notifyListeners();

      final payloadInfo = payloadType != null ? ' [${payloadType == "dual" ? "Full" : "Mini"}]' : '';
      developer.log('🏷️ Added tag entry: $profileName (${profileType.label}) → $tagId ($tagType)$payloadInfo', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to add tag entry: $e', name: 'History.Service', error: e);
    }
  }

  /// Create received entry from contact scan with Firestore fetch
  ///
  /// This method fetches the full profile data from Firestore when an Atlas Linq
  /// contact is found in device contacts. Falls back to minimal placeholder
  /// if Firestore fetch fails.
  ///
  /// Used to dynamically show contacts with Atlas Linq URLs in history
  static Future<HistoryEntry> createReceivedEntryFromContact({
    required TapCardContact contact,
  }) async {
    final profileId = contact.profileId;
    final displayName = contact.displayName;
    final isLegacyFormat = contact.isLegacyFormat;

    developer.log(
      '🔍 Creating received entry from contact\n'
      '   • Profile ID: $profileId\n'
      '   • Display Name: $displayName\n'
      '   • Legacy Format: $isLegacyFormat\n'
      '   • Has Metadata: ${contact.shareMethod != null}\n'
      '   • Method: ${contact.shareMethod?.label ?? "unknown"}\n'
      '   • Timestamp: ${contact.shareTimestamp ?? "unknown"}\n'
      '   • Profile Type: ${contact.profileType?.label ?? "unknown"}',
      name: 'History.ContactToEntry',
    );

    ProfileData? firestoreProfile;

    // ALWAYS attempt Firestore fetch regardless of ID format
    // The web client successfully fetches profiles with any ID format,
    // including UUID (a1b2c3d4-...) and type_timestamp (personal_1760168253751)
    developer.log(
      '🔍 Attempting Firestore fetch\n'
      '   • Profile ID: $profileId\n'
      '   • Display Name: $displayName\n'
      '   • Marked as Legacy: $isLegacyFormat (will fetch anyway)\n'
      '   • Expected Firestore path: profiles/$profileId\n'
      '   • Profile type from metadata: ${contact.profileType?.label ?? "NULL"}\n'
      '   • Has vCard phone: ${contact.phone != null}\n'
      '   • Has vCard email: ${contact.email != null}\n'
      '   • Has vCard company: ${contact.company != null}',
      name: 'History.ContactToEntry',
    );

    try {
      firestoreProfile = await _fetchProfileFromFirestore(profileId);

      if (firestoreProfile != null) {
        developer.log(
          '✅ Firestore fetch SUCCESS\n'
          '   • Profile ID: $profileId\n'
          '   • Name: ${firestoreProfile.name}\n'
          '   • Type: ${firestoreProfile.type.label}\n'
          '   • Email: ${firestoreProfile.email ?? "null"}\n'
          '   • Phone: ${firestoreProfile.phone ?? "null"}\n'
          '   • Company: ${firestoreProfile.company ?? "null"}\n'
          '   • Title: ${firestoreProfile.title ?? "null"}\n'
          '   • Image URL: ${firestoreProfile.profileImagePath ?? "null"}\n'
          '   • Social Links: ${firestoreProfile.socialMedia.length}\n'
          '   • Has Aesthetics: ${firestoreProfile.cardAesthetics != null}',
          name: 'History.ContactToEntry',
        );
      } else {
        developer.log(
          '⚠️ Firestore fetch returned NULL\n'
          '   • Profile ID: $profileId\n'
          '   • This means: Document does not exist in Firestore\n'
          '   • Verify: Open https://console.firebase.google.com and check profiles/$profileId',
          name: 'History.ContactToEntry',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Firestore fetch EXCEPTION\n'
        '   • Profile ID: $profileId\n'
        '   • Error Type: ${e.runtimeType}\n'
        '   • Error: $e',
        name: 'History.ContactToEntry',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // Use Firestore profile if available, otherwise create profile from vCard data
    final profile = firestoreProfile ?? ProfileData(
      id: profileId,
      type: contact.profileType ?? ProfileType.personal, // Use extracted type or default to personal
      name: displayName,
      // Smart subtitle fallback: prefer title > company > email prefix
      // This ensures we always show SOMETHING useful instead of empty subtitle
      title: contact.title ??
             (contact.company != null && contact.company!.isNotEmpty
               ? contact.company
               : (contact.email != null && contact.email!.isNotEmpty
                 ? contact.email!.split('@').first
                 : null)),
      company: contact.company, // ✅ Use vCard data
      phone: contact.phone, // ✅ Use vCard data
      email: contact.email, // ✅ Use vCard data
      website: contact.website ?? 'https://atlaslinq.com/share/$profileId',
      socialMedia: {}, // Empty is OK - rarely stored in vCard
      profileImagePath: null, // Would require Firestore
      cardAesthetics: CardAesthetics.defaultForType(
        contact.profileType ?? ProfileType.personal,
      ), // ✅ Use proper defaults based on profile type
      lastUpdated: DateTime.now(),
    );

    developer.log(
      '✅ Received entry created\n'
      '   • Profile ID: $profileId\n'
      '   • Data Source: ${firestoreProfile != null ? "Firestore" : "vCard (fallback)"}\n'
      '   • Name: ${profile.name}\n'
      '   • Phone: ${profile.phone ?? "null"}\n'
      '   • Email: ${profile.email ?? "null"}\n'
      '   • Company: ${profile.company ?? "null"}\n'
      '   • Title: ${profile.title ?? "null"}\n'
      '   • Website: ${profile.website ?? "null"}\n'
      '   • Profile Type: ${profile.type.label}\n'
      '   • Has Aesthetics: ${profile.cardAesthetics != null}\n'
      '   • Using Metadata: ${contact.shareMethod != null}',
      name: 'History.ContactToEntry',
    );

    // Log card aesthetics details to verify correct gradient application
    developer.log(
      '🎨 Card Aesthetics Details\n'
      '   • Profile Type: ${profile.type.label}\n'
      '   • Primary Color: #${profile.cardAesthetics.primaryColor.value.toRadixString(16).padLeft(8, '0')}\n'
      '   • Secondary Color: #${profile.cardAesthetics.secondaryColor.value.toRadixString(16).padLeft(8, '0')}\n'
      '   • Border Color: #${profile.cardAesthetics.borderColor.value.toRadixString(16).padLeft(8, '0')}\n'
      '   • Background Color: ${profile.cardAesthetics.backgroundColor != null ? "#${profile.cardAesthetics.backgroundColor!.value.toRadixString(16).padLeft(8, '0')}" : "null (using gradient)"}\n'
      '   • Has Background Image: ${profile.cardAesthetics.hasBackgroundImage}\n'
      '   • Blur Level: ${profile.cardAesthetics.blurLevel}',
      name: 'History.ContactToEntry',
    );

    return HistoryEntry.received(
      id: 'contact_$profileId', // Special ID prefix for scanned contacts
      method: contact.shareMethod ?? ShareMethod.nfc, // Use extracted method or default to NFC
      timestamp: contact.shareTimestamp ?? DateTime.now().subtract(const Duration(days: 1)), // Use extracted timestamp or default
      senderProfile: profile,
      location: null,
      metadata: {
        'source': 'device_contacts',
        'is_legacy_format': isLegacyFormat,
        'scanned': true,
        'firestore_fetched': firestoreProfile != null,
        'vcard_fallback_used': firestoreProfile == null, // Track if we used vCard fallback
        'has_vcard_data': contact.phone != null || contact.email != null || contact.company != null,
        'has_metadata': contact.shareMethod != null, // Track if we extracted metadata
        'metadata_method': contact.shareMethod?.label,
        'metadata_timestamp': contact.shareTimestamp?.toIso8601String(),
        'metadata_profile_type': contact.profileType?.label,
      },
    );
  }

  /// Helper method to fetch profile from Firestore
  /// Separated for testability
  static Future<ProfileData?> _fetchProfileFromFirestore(String profileId) async {
    try {
      return await FirestoreSyncService.getProfileById(profileId);
    } catch (e) {
      developer.log(
        '❌ Firestore fetch error: $e',
        name: 'History.ContactToEntry',
        error: e,
      );
      return null;
    }
  }

  /// Get all history entries (excluding soft-deleted)
  static Future<List<HistoryEntry>> getAllHistory() async {
    if (!_isInitialized) await initialize();
    return _cache.where((entry) => !entry.isSoftDeleted).toList();
  }

  /// Get count of received entries (for stats)
  static Future<int> getReceivedCount() async {
    if (!_isInitialized) await initialize();
    return _cache.where((entry) =>
      !entry.isSoftDeleted &&
      entry.type == HistoryEntryType.received
    ).length;
  }

  /// Get filtered history entries
  static Future<List<HistoryEntry>> getHistory({
    HistoryEntryType? type,
    ShareMethod? method,
    DateTime? since,
    int limit = 50,
    bool includeSoftDeleted = false,
  }) async {
    if (!_isInitialized) await initialize();

    var filtered = _cache.where((entry) {
      if (!includeSoftDeleted && entry.isSoftDeleted) return false;
      if (type != null && entry.type != type) return false;
      if (method != null && entry.method != method) return false;
      if (since != null && entry.timestamp.isBefore(since)) return false;
      return true;
    }).toList();

    return filtered.take(limit).toList();
  }

  /// Soft delete an entry (for sent items)
  static Future<void> softDeleteEntry(String id) async {
    try {
      final index = _cache.indexWhere((entry) => entry.id == id);
      if (index == -1) return;

      _cache[index] = _cache[index].copyWith(isSoftDeleted: true);
      await _saveToStorage();
      _notifyListeners();

      developer.log('🗑️ Soft deleted entry: $id', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to soft delete entry: $e', name: 'History.Service', error: e);
    }
  }

  /// Restore a soft-deleted entry
  static Future<void> restoreEntry(String id) async {
    try {
      final index = _cache.indexWhere((entry) => entry.id == id);
      if (index == -1) return;

      _cache[index] = _cache[index].copyWith(isSoftDeleted: false);
      await _saveToStorage();
      _notifyListeners();

      developer.log('♻️ Restored entry: $id', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to restore entry: $e', name: 'History.Service', error: e);
    }
  }

  /// Permanently delete an entry (routes to appropriate delete method)
  static Future<bool> deleteEntry(String id) async {
    try {
      final entry = _cache.firstWhere(
        (e) => e.id == id,
        orElse: () => throw Exception('Entry not found: $id')
      );

      if (entry.type == HistoryEntryType.received) {
        // For received entries, delete from device contacts AND history
        return await deleteReceivedEntry(id, deleteFromDevice: true);
      } else {
        // For sent/tag entries, delete from history only
        return await _deleteFromHistoryOnly(id);
      }
    } catch (e) {
      developer.log('❌ Failed to delete entry: $e', name: 'History.Service', error: e);
      return false;
    }
  }

  /// Delete a received entry and optionally remove contact from device
  static Future<bool> deleteReceivedEntry(String id, {bool deleteFromDevice = true}) async {
    try {
      final entry = _cache.firstWhere(
        (e) => e.id == id,
        orElse: () => throw Exception('Entry not found: $id')
      );

      if (entry.type == HistoryEntryType.received &&
          entry.senderProfile != null &&
          deleteFromDevice) {

        // Get permission to access contacts
        final hasPermission = await ContactService.hasContactsPermission();
        if (!hasPermission) {
          developer.log('⚠️ Cannot delete contact - permission denied', name: 'History.DeleteReceived');
          // Still delete from history
          return await _deleteFromHistoryOnly(id);
        }

        // Find contact by TapCard URL
        final profileId = entry.senderProfile!.id;
        final contacts = await FlutterContacts.getContacts(withProperties: true);

        Contact? contactToDelete;
        for (final contact in contacts) {
          for (final website in contact.websites) {
            if (website.url.contains('/share/$profileId')) {
              contactToDelete = contact;
              break;
            }
          }
          if (contactToDelete != null) break;
        }

        // Delete from device contacts
        if (contactToDelete != null) {
          await FlutterContacts.deleteContact(contactToDelete);
          developer.log('🗑️ Deleted contact from device: ${contactToDelete.displayName}', name: 'History.DeleteReceived');
        } else {
          developer.log('⚠️ Contact not found in device contacts (may have been already deleted)', name: 'History.DeleteReceived');
        }
      }

      // Delete from history
      return await _deleteFromHistoryOnly(id);
    } catch (e) {
      developer.log('❌ Failed to delete received entry: $e', name: 'History.DeleteReceived', error: e);
      return false;
    }
  }

  /// Internal method to delete from history only
  static Future<bool> _deleteFromHistoryOnly(String id) async {
    try {
      _cache.removeWhere((entry) => entry.id == id);
      await _saveToStorage();
      _notifyListeners();
      developer.log('🗑️ Deleted from history: $id', name: 'History.Service');
      return true;
    } catch (e) {
      developer.log('❌ Failed to delete from history: $e', name: 'History.Service', error: e);
      return false;
    }
  }

  /// Clear all history
  static Future<void> clearAllHistory() async {
    try {
      _cache.clear();
      await _saveToStorage();
      _notifyListeners();

      developer.log('🧹 Cleared all history', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to clear history: $e', name: 'History.Service', error: e);
    }
  }

  /// Save history to persistent storage
  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cache.map((entry) => entry.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (e) {
      developer.log('❌ Failed to save history to storage: $e', name: 'History.Service', error: e);
    }
  }

  /// Load history from persistent storage
  static Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyKey);

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _cache = jsonList
            .map((json) => HistoryEntry.fromJson(json as Map<String, dynamic>))
            .toList();
        developer.log('📂 Loaded ${_cache.length} entries from storage', name: 'History.Service');
      } else {
        _cache = [];
        developer.log('📂 No existing history found', name: 'History.Service');
      }

      _notifyListeners();
    } catch (e) {
      developer.log('❌ Failed to load history from storage: $e', name: 'History.Service', error: e);
      _cache = [];
    }
  }

  /// Notify all stream listeners
  static void _notifyListeners() {
    final activeEntries = _cache.where((entry) => !entry.isSoftDeleted).toList();
    _historyController.add(activeEntries);
  }

  /// Generate rich mock data for first run (only tags and received)
  static Future<void> _generateMockData() async {
    final now = DateTime.now();

    _cache = [
      // Tag write - 30 minutes ago
      HistoryEntry.tag(
        id: '1',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(minutes: 30)),
        writtenProfileName: 'Alex Johnson',
        writtenProfileType: ProfileType.professional,
        tagId: 'NTAG_00B4C7F2',
        tagType: 'NTAG215',
        tagCapacity: 504,
        location: 'Home Office',
      ),

      // Received via NFC - 1 hour ago
      HistoryEntry.received(
        id: '2',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(hours: 1)),
        senderProfile: ProfileData(
          id: 'mock_john',
          type: ProfileType.professional,
          name: 'John Williams',
          title: 'Senior Product Manager',
          company: 'Tech Innovations Inc.',
          phone: '+1 (555) 123-4567',
          email: 'john.williams@techinnovations.com',
          website: 'https://johndoe.com',
          socialMedia: {
            'linkedin': 'john-williams',
            'twitter': '@johnwilliams',
          },
          customLinks: [
            const CustomLink(
              title: 'Book a Meeting',
              url: 'https://calendly.com/johnwilliams',
            ),
            const CustomLink(
              title: 'My Portfolio',
              url: 'https://johnwilliams-pm.com',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Tech Conference - Hall B',
        metadata: {
          'source': 'nfc_scan',
          'has_metadata': true,
          'metadata_method': 'NFC',
          'metadata_timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
          'metadata_profile_type': 'Professional',
        },
      ),

      // Tag write - yesterday
      HistoryEntry.tag(
        id: '3',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 1)),
        writtenProfileName: 'Sarah Chen',
        writtenProfileType: ProfileType.personal,
        tagId: 'NTAG_004D2A1B',
        tagType: 'NTAG213',
        tagCapacity: 144,
        location: 'Conference Room A',
      ),

      // Received via QR - 2 days ago
      HistoryEntry.received(
        id: '4',
        method: ShareMethod.qr,
        timestamp: now.subtract(const Duration(days: 2)),
        senderProfile: ProfileData(
          id: 'mock_emily',
          type: ProfileType.personal,
          name: 'Emily Johnson',
          phone: '+1 (555) 987-6543',
          email: 'emily.j@email.com',
          socialMedia: {
            'instagram': 'emily.johnson',
            'twitter': '@emilyj',
          },
          customLinks: [
            const CustomLink(
              title: 'My Art Portfolio',
              url: 'https://behance.net/emilyj',
            ),
            const CustomLink(
              title: 'Support My Work',
              url: 'https://ko-fi.com/emilyj',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Art Gallery',
        metadata: {
          'source': 'qr_scan',
          'has_metadata': true,
          'metadata_method': 'QR Code',
          'metadata_timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
          'metadata_profile_type': 'Personal',
        },
      ),

      // Received via NFC - 3 days ago
      HistoryEntry.received(
        id: '5',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(days: 3)),
        senderProfile: ProfileData(
          id: 'mock_anna',
          type: ProfileType.professional,
          name: 'Anna Martinez',
          title: 'Creative Director',
          company: 'Design Studio Pro',
          phone: '+1 (555) 456-7890',
          email: 'anna.m@designstudio.com',
          website: 'https://annamartinez.design',
          socialMedia: {
            'behance': 'annamartinez',
            'linkedin': 'anna-martinez',
          },
          customLinks: [
            const CustomLink(
              title: 'View My Work',
              url: 'https://dribbble.com/annamartinez',
            ),
            const CustomLink(
              title: 'Book a Consultation',
              url: 'https://calendly.com/annamartinez',
            ),
            const CustomLink(
              title: 'Design Resources',
              url: 'https://annamartinez.design/resources',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Design Workshop',
        metadata: {
          'source': 'nfc_scan',
          'has_metadata': true,
          'metadata_method': 'NFC',
          'metadata_timestamp': now.subtract(const Duration(days: 3)).toIso8601String(),
          'metadata_profile_type': 'Professional',
        },
      ),

      // Tag write - 4 days ago
      HistoryEntry.tag(
        id: '6',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 4)),
        writtenProfileName: 'Michael Roberts',
        writtenProfileType: ProfileType.custom,
        tagId: 'NTAG_00A1B2C3',
        tagType: 'NTAG215',
        tagCapacity: 504,
        location: 'Marketing Event',
      ),

      // Received via NFC - 5 days ago
      HistoryEntry.received(
        id: '7',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(days: 5)),
        senderProfile: ProfileData(
          id: 'mock_lisa',
          type: ProfileType.professional,
          name: 'Dr. Lisa Brown',
          title: 'Chief Medical Officer',
          company: 'HealthCare Plus',
          phone: '+1 (555) 234-5678',
          email: 'l.brown@healthcareplus.com',
          socialMedia: {
            'linkedin': 'dr-lisa-brown',
          },
          customLinks: [
            const CustomLink(
              title: 'Schedule Appointment',
              url: 'https://healthcareplus.com/drbrown',
            ),
            const CustomLink(
              title: 'Patient Portal',
              url: 'https://portal.healthcareplus.com',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Medical Conference',
        metadata: {
          'source': 'nfc_scan',
          'has_metadata': true,
          'metadata_method': 'NFC',
          'metadata_timestamp': now.subtract(const Duration(days: 5)).toIso8601String(),
          'metadata_profile_type': 'Professional',
        },
      ),

      // Tag write - 6 days ago
      HistoryEntry.tag(
        id: '8',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 6)),
        writtenProfileName: 'Emily Taylor',
        writtenProfileType: ProfileType.professional,
        tagId: 'NTAG_008F3E21',
        tagType: 'NTAG216',
        tagCapacity: 888,
        location: 'Business Card Holder',
      ),

      // Received via QR - 1 week ago
      HistoryEntry.received(
        id: '9',
        method: ShareMethod.qr,
        timestamp: now.subtract(const Duration(days: 8)),
        senderProfile: ProfileData(
          id: 'mock_carlos',
          type: ProfileType.custom,
          name: 'Carlos Garcia',
          phone: '+1 (555) 345-6789',
          email: 'carlos.g@email.com',
          website: 'https://carlosgarcia.dev',
          socialMedia: {
            'github': 'carlosgarcia',
            'twitter': '@carlosg',
          },
          customLinks: [
            const CustomLink(
              title: 'My Newsletter',
              url: 'https://carlosgarcia.substack.com',
            ),
            const CustomLink(
              title: 'Open Source Projects',
              url: 'https://github.com/carlosgarcia?tab=repositories',
            ),
            const CustomLink(
              title: 'Tech Blog',
              url: 'https://carlosgarcia.dev/blog',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Developer Meetup',
        metadata: {
          'source': 'qr_scan',
          'has_metadata': true,
          'metadata_method': 'QR Code',
          'metadata_timestamp': now.subtract(const Duration(days: 8)).toIso8601String(),
          'metadata_profile_type': 'Custom',
        },
      ),

      // Tag write - 10 days ago
      HistoryEntry.tag(
        id: '10',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 10)),
        writtenProfileName: 'David Park',
        writtenProfileType: ProfileType.personal,
        tagId: 'NTAG_00FFFFFF',
        tagType: 'NTAG213',
        tagCapacity: 144,
        location: 'Office Desk',
      ),

      // Received via NFC - 2 weeks ago
      HistoryEntry.received(
        id: '11',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(days: 15)),
        senderProfile: ProfileData(
          id: 'mock_ryan',
          type: ProfileType.professional,
          name: 'Ryan Cooper',
          title: 'Software Architect',
          company: 'CloudTech Solutions',
          phone: '+1 (555) 567-8901',
          email: 'ryan.cooper@cloudtech.com',
          website: 'https://ryancooper.io',
          socialMedia: {
            'github': 'ryancooper',
            'linkedin': 'ryan-cooper',
          },
          customLinks: [
            const CustomLink(
              title: 'Company Website',
              url: 'https://cloudtech.com',
            ),
            const CustomLink(
              title: 'Download Resume',
              url: 'https://ryancooper.io/resume.pdf',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Tech Summit',
        metadata: {
          'source': 'nfc_scan',
          'has_metadata': true,
          'metadata_method': 'NFC',
          'metadata_timestamp': now.subtract(const Duration(days: 15)).toIso8601String(),
          'metadata_profile_type': 'Professional',
        },
      ),

      // Tag write - 3 weeks ago
      HistoryEntry.tag(
        id: '12',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 21)),
        writtenProfileName: 'Jennifer Martinez',
        writtenProfileType: ProfileType.custom,
        tagId: 'NTAG_00D7E9A4',
        tagType: 'NTAG216',
        tagCapacity: 888,
        location: 'Networking Mixer',
      ),

      // Received via Web - 9 days ago
      HistoryEntry.received(
        id: '13',
        method: ShareMethod.web,
        timestamp: now.subtract(const Duration(days: 9)),
        senderProfile: ProfileData(
          id: 'mock_web_user',
          type: ProfileType.professional,
          name: 'Jennifer Wilson',
          title: 'Marketing Director',
          company: 'Digital Ventures LLC',
          phone: '+1 (555) 777-8888',
          email: 'j.wilson@digitalventures.com',
          website: 'https://jenniferw.com',
          socialMedia: {
            'linkedin': 'jennifer-wilson-marketing',
            'twitter': '@jwilson_mktg',
          },
          customLinks: [
            const CustomLink(
              title: 'Marketing Case Studies',
              url: 'https://jenniferw.com/case-studies',
            ),
            const CustomLink(
              title: 'Free Resources',
              url: 'https://jenniferw.com/resources',
            ),
          ],
          lastUpdated: now,
        ),
        location: 'Website Download',
        metadata: {
          'source': 'web_download',
          'has_metadata': true,
          'metadata_method': 'Web',
          'metadata_timestamp': now.subtract(const Duration(days: 9)).toIso8601String(),
          'metadata_profile_type': 'Professional',
        },
      ),
    ];

    await _saveToStorage();
    _notifyListeners();

    developer.log('✨ Generated ${_cache.length} mock history entries', name: 'History.Service');
  }

  /// Dispose resources
  static void dispose() {
    _historyController.close();
  }
}
