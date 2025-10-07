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

import '../models/history_models.dart';
import '../core/models/profile_models.dart';

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
    required String tagId,
    required String tagType,
    required ShareMethod method,
    int? tagCapacity,
    String? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final entry = HistoryEntry.tag(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: method,
        timestamp: DateTime.now(),
        tagId: tagId,
        tagType: tagType,
        tagCapacity: tagCapacity,
        location: location,
        metadata: metadata,
      );

      _cache.insert(0, entry);
      await _saveToStorage();
      _notifyListeners();

      developer.log('🏷️ Added tag entry: $tagId ($tagType)', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to add tag entry: $e', name: 'History.Service', error: e);
    }
  }

  /// Get all history entries (excluding soft-deleted)
  static Future<List<HistoryEntry>> getAllHistory() async {
    if (!_isInitialized) await initialize();
    return _cache.where((entry) => !entry.isSoftDeleted).toList();
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

  /// Permanently delete an entry
  static Future<void> deleteEntry(String id) async {
    try {
      _cache.removeWhere((entry) => entry.id == id);
      await _saveToStorage();
      _notifyListeners();

      developer.log('🗑️ Deleted entry: $id', name: 'History.Service');
    } catch (e) {
      developer.log('❌ Failed to delete entry: $e', name: 'History.Service', error: e);
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

  /// Generate rich mock data for first run
  static Future<void> _generateMockData() async {
    final now = DateTime.now();

    _cache = [
      // Recent NFC share - 5 minutes ago
      HistoryEntry.sent(
        id: '1',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(minutes: 5)),
        recipientName: 'Sarah Chen',
        recipientDevice: 'Galaxy S23 Ultra',
        location: 'Starbucks Downtown',
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
          lastUpdated: now,
        ),
        location: 'Tech Conference - Hall B',
      ),

      // Sent via QR - 3 hours ago
      HistoryEntry.sent(
        id: '3',
        method: ShareMethod.qr,
        timestamp: now.subtract(const Duration(hours: 3)),
        recipientName: 'Mike Rodriguez',
        location: 'Coffee & Co.',
      ),

      // Tag write - yesterday
      HistoryEntry.tag(
        id: '4',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 1)),
        tagId: 'NTAG_004D2A1B',
        tagType: 'NTAG215',
        tagCapacity: 504,
        location: 'Home Office',
      ),

      // Received via QR - 2 days ago
      HistoryEntry.received(
        id: '5',
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
          lastUpdated: now,
        ),
        location: 'Art Gallery',
      ),

      // Sent via NFC - 2 days ago
      HistoryEntry.sent(
        id: '6',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(days: 2)),
        recipientName: 'David Kim',
        recipientDevice: 'iPhone 14 Pro',
        location: 'Startup Meetup',
      ),

      // Received via NFC - 3 days ago
      HistoryEntry.received(
        id: '7',
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
          lastUpdated: now,
        ),
        location: 'Design Workshop',
      ),

      // Sent via QR - 4 days ago
      HistoryEntry.sent(
        id: '8',
        method: ShareMethod.qr,
        timestamp: now.subtract(const Duration(days: 4)),
        recipientName: 'James Wilson',
        location: 'University Campus',
      ),

      // Tag write - 5 days ago
      HistoryEntry.tag(
        id: '9',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 5)),
        tagId: 'NTAG_00A1B2C3',
        tagType: 'NTAG213',
        tagCapacity: 144,
        location: 'Conference Room',
      ),

      // Received via NFC - 5 days ago
      HistoryEntry.received(
        id: '10',
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
          lastUpdated: now,
        ),
        location: 'Medical Conference',
      ),

      // Sent via NFC - 1 week ago
      HistoryEntry.sent(
        id: '11',
        method: ShareMethod.nfc,
        timestamp: now.subtract(const Duration(days: 7)),
        recipientName: 'Alex Thompson',
        recipientDevice: 'Pixel 7 Pro',
        location: 'Networking Event',
      ),

      // Received via QR - 1 week ago
      HistoryEntry.received(
        id: '12',
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
          lastUpdated: now,
        ),
      ),

      // Tag write - 10 days ago
      HistoryEntry.tag(
        id: '13',
        method: ShareMethod.tag,
        timestamp: now.subtract(const Duration(days: 10)),
        tagId: 'NTAG_00FFFFFF',
        tagType: 'NTAG216',
        tagCapacity: 888,
        location: 'Office Desk',
      ),

      // Sent via QR - 2 weeks ago
      HistoryEntry.sent(
        id: '14',
        method: ShareMethod.qr,
        timestamp: now.subtract(const Duration(days: 14)),
        recipientName: 'Sophia Lee',
        location: 'Book Club',
      ),

      // Received via NFC - 2 weeks ago
      HistoryEntry.received(
        id: '15',
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
          lastUpdated: now,
        ),
        location: 'Tech Summit',
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
