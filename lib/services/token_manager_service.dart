import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/unified_models.dart';

/// Service for managing local tokens and future Firebase integration
class TokenManagerService {
  static final TokenManagerService _instance = TokenManagerService._internal();
  factory TokenManagerService() => _instance;
  TokenManagerService._internal();

  static const String _tokensKey = 'tap_card_tokens';
  static const String _receivedCardsKey = 'tap_card_received_cards';

  /// Store a token locally (simulates server-side storage)
  Future<void> storeToken({
    required ShareToken token,
    required ProfileData profileData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing tokens
      final existingTokens = await _getStoredTokens();

      // Create simplified token data
      final tokenData = {
        'token': token.token,
        'createdAt': DateTime.now().toIso8601String(),
        'profileData': profileData.toJson(),
      };

      // Add new token
      existingTokens[token.token] = tokenData;

      // Clean expired tokens before storing
      _cleanExpiredTokens(existingTokens);

      // Store updated tokens
      await prefs.setString(_tokensKey, jsonEncode(existingTokens));

      print('Token stored locally: ${token.token}');
    } catch (e) {
      print('Error storing token: $e');
    }
  }

  /// Retrieve full profile data by token
  Future<ProfileData?> getProfileByToken(String token) async {
    try {
      final tokenData = await _getTokenData(token);
      if (tokenData == null) {
        print('Token not found: $token');
        return null;
      }

      // Check if token is expired
      final expiresAt = DateTime.parse(tokenData['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) {
        print('Token expired: $token');
        await _removeToken(token);
        return null;
      }

      // Convert back to ProfileData
      final profileJson = tokenData['profileData'] as Map<String, dynamic>;
      return _profileFromJson(profileJson);
    } catch (e) {
      print('Error retrieving profile by token: $e');
      return null;
    }
  }

  /// Store received contact card
  Future<void> storeReceivedCard({
    required SharePayload payload,
    ProfileData? fullProfileData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing received cards
      final existingCards = await _getReceivedCards();

      // Create received card data
      final cardData = {
        'receivedAt': DateTime.now().toIso8601String(),
        'payload': payload.toJson(),
        'fullProfileData': fullProfileData != null ? fullProfileData.toJson() : null,
      };

      // Use timestamp as key since SharePayload doesn't have token
      final key = DateTime.now().millisecondsSinceEpoch.toString();
      existingCards[key] = cardData;

      // Store updated cards
      await prefs.setString(_receivedCardsKey, jsonEncode(existingCards));

      print('Received card stored: $key');
    } catch (e) {
      print('Error storing received card: $e');
    }
  }

  /// Get all received cards
  Future<List<ReceivedContact>> getReceivedCards() async {
    try {
      final cardsData = await _getReceivedCards();
      final cards = <ReceivedContact>[];

      for (final entry in cardsData.entries) {
        try {
          final cardData = entry.value as Map<String, dynamic>;
          final payload = SharePayload.fromJson(cardData['payload']);
          final receivedAt = DateTime.parse(cardData['receivedAt']);

          // Create ReceivedContact from simplified payload
          final receivedContact = ReceivedContact(
            id: entry.key,
            contact: payload.data,
            receivedAt: receivedAt,
          );

          cards.add(receivedContact);
        } catch (e) {
          print('Error parsing received card: $e');
        }
      }

      // Sort by received date (newest first)
      cards.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

      return cards;
    } catch (e) {
      print('Error getting received cards: $e');
      return [];
    }
  }

  /// Clean up expired tokens
  Future<void> cleanupExpiredTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean tokens
      final tokens = await _getStoredTokens();
      _cleanExpiredTokens(tokens);
      await prefs.setString(_tokensKey, jsonEncode(tokens));

      // Clean received cards (keep for 30 days)
      final cards = await _getReceivedCards();
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      cards.removeWhere((key, value) {
        try {
          final receivedAt = DateTime.parse(value['receivedAt']);
          return receivedAt.isBefore(thirtyDaysAgo);
        } catch (e) {
          return true; // Remove invalid entries
        }
      });

      await prefs.setString(_receivedCardsKey, jsonEncode(cards));

      print('Expired tokens and old cards cleaned up');
    } catch (e) {
      print('Error cleaning up expired data: $e');
    }
  }

  /// Get stored tokens from SharedPreferences
  Future<Map<String, dynamic>> _getStoredTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString(_tokensKey);
      if (tokensJson != null) {
        return Map<String, dynamic>.from(jsonDecode(tokensJson));
      }
    } catch (e) {
      print('Error getting stored tokens: $e');
    }
    return {};
  }

  /// Get received cards from SharedPreferences
  Future<Map<String, dynamic>> _getReceivedCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = prefs.getString(_receivedCardsKey);
      if (cardsJson != null) {
        return Map<String, dynamic>.from(jsonDecode(cardsJson));
      }
    } catch (e) {
      print('Error getting received cards: $e');
    }
    return {};
  }

  /// Get token data by token string
  Future<Map<String, dynamic>?> _getTokenData(String token) async {
    final tokens = await _getStoredTokens();
    return tokens[token] as Map<String, dynamic>?;
  }

  /// Remove a specific token
  Future<void> _removeToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokens = await _getStoredTokens();
      tokens.remove(token);
      await prefs.setString(_tokensKey, jsonEncode(tokens));
    } catch (e) {
      print('Error removing token: $e');
    }
  }

  /// Clean expired tokens from map
  void _cleanExpiredTokens(Map<String, dynamic> tokens) {
    final now = DateTime.now();
    tokens.removeWhere((key, value) {
      try {
        final expiresAt = DateTime.parse(value['expiresAt']);
        return now.isAfter(expiresAt);
      } catch (e) {
        return true; // Remove invalid entries
      }
    });
  }

  /// Convert ProfileData to JSON
  Map<String, dynamic> _profileToJson(ProfileData profile) {
    return {
      'id': profile.id,
      'type': profile.type.toString(),
      'name': profile.name,
      'title': profile.title,
      'company': profile.company,
      'email': profile.email,
      'phone': profile.phone,
      'website': profile.website,
      'socialMedia': profile.socialMedia,
      'isActive': profile.isActive,
      'profileImagePath': profile.profileImagePath,
      'templateIndex': profile.templateIndex,
      'lastUpdated': profile.lastUpdated.toIso8601String(),
    };
  }

  /// Convert JSON to ProfileData
  ProfileData _profileFromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'],
      type: ProfileType.values.firstWhere(
        (type) => type.toString() == json['type'],
        orElse: () => ProfileType.professional,
      ),
      name: json['name'] ?? '',
      title: json['title'],
      company: json['company'],
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      socialMedia: Map<String, String>.from(json['socialMedia'] ?? {}),
      isActive: json['isActive'] ?? true,
      profileImagePath: json['profileImagePath'],
      templateIndex: json['templateIndex'] ?? 0,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : DateTime.now(),
    );
  }
}

// Removed redundant ReceivedCard class - using unified models from unified_models.dart