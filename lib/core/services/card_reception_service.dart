/// Card Reception Service
///
/// Centralized service for handling received contact cards from all sources:
/// - NFC tap reception
/// - QR code scanning
/// - Web link sharing
///
/// **Core Responsibilities:**
/// - Fetch full profile from Firestore
/// - Save vCard to device contacts
/// - Update ReceivedCardsRepository
/// - Create history entry
/// - Show success notification
///
/// **Data Flow:**
/// 1. Receive card data (minimal: name, ID, method)
/// 2. Fetch complete ProfileData from Firestore
/// 3. Generate and save vCard to device contacts
/// 4. Store UID in ReceivedCardsRepository
/// 5. Add entry to HistoryService
/// 6. Notify user of success
library;

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/profile_models.dart';
import '../../models/history_models.dart';
import '../../services/firestore_sync_service.dart';
import '../../services/history_service.dart';
import '../../services/contact_service.dart';
import '../repositories/received_cards_repository.dart';

/// Service for handling card reception from all sources
class CardReceptionService {
  static final CardReceptionService _instance = CardReceptionService._internal();
  factory CardReceptionService() => _instance;
  CardReceptionService._internal();

  /// Handle received card from any source (NFC, QR, Web)
  ///
  /// This is the main entry point for all card reception flows.
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  /// - profileId: The unique ID of the received profile
  /// - method: How the card was received (NFC, QR, Web)
  /// - context: Optional BuildContext for showing notifications
  /// - receivedProfile: Optional pre-fetched profile data (fallback if Firestore fails)
  static Future<bool> handleReceivedCard({
    required String profileId,
    required ShareMethod method,
    BuildContext? context,
    ProfileData? receivedProfile,
  }) async {
    final startTime = DateTime.now();

    try {
      developer.log(
        '📥 Starting card reception flow\n'
        '   • Profile ID: $profileId\n'
        '   • Method: ${method.label}\n'
        '   • Has fallback data: ${receivedProfile != null}',
        name: 'CardReception.Start',
      );

      // STEP 1: Fetch complete profile from Firestore (ALWAYS try this first)
      developer.log('   🔍 Step 1: Fetching complete profile from Firestore...', name: 'CardReception');
      ProfileData? profile = await FirestoreSyncService.getProfileById(profileId);

      // STEP 2: Fall back to provided profile data if Firestore fails
      if (profile == null) {
        if (receivedProfile != null) {
          developer.log(
            '   ⚠️ Firestore fetch failed, using fallback profile data\n'
            '   • Name: ${receivedProfile.name}\n'
            '   • Note: socialMedia, customLinks, cardAesthetics may be incomplete',
            name: 'CardReception',
          );
          profile = receivedProfile;
        } else {
          developer.log(
            '   ❌ No Firestore data and no fallback provided - cannot proceed',
            name: 'CardReception',
          );
          return false;
        }
      } else {
        developer.log(
          '   ✅ Firestore fetch successful\n'
          '   • Name: ${profile.name}\n'
          '   • Has image: ${profile.profileImagePath != null}\n'
          '   • Social links: ${profile.socialMedia.length}\n'
          '   • Custom links: ${profile.customLinks.length}\n'
          '   • Has card aesthetics: ${profile.cardAesthetics != CardAesthetics.defaultForType(profile.type)}',
          name: 'CardReception',
        );
      }

      // STEP 3: Check contacts permission
      developer.log('   🔐 Step 2: Checking contacts permission...', name: 'CardReception');
      final hasPermission = await ContactService.hasContactsPermission();
      if (!hasPermission) {
        final permissionStatus = await ContactService.requestContactsPermission();
        if (permissionStatus != PermissionStatus.granted) {
          developer.log('   ❌ Contacts permission denied', name: 'CardReception');
          return false;
        }
      }

      // STEP 4: Save vCard to device contacts
      developer.log('   💾 Step 3: Saving vCard to device contacts...', name: 'CardReception');
      final vCardSaved = await _saveVCardToContacts(profile, method);
      if (!vCardSaved) {
        developer.log('   ⚠️ Failed to save vCard, continuing anyway...', name: 'CardReception');
      }

      // STEP 5: Store UID in ReceivedCardsRepository
      developer.log('   📦 Step 4: Storing UID in ReceivedCardsRepository...', name: 'CardReception');
      final repository = ReceivedCardsRepository();
      await repository.addReceivedCard(
        profileId,
        profile: profile,
        shareMethod: method,
      );

      // STEP 6: Add to history
      developer.log('   📝 Step 5: Adding to history...', name: 'CardReception');
      await HistoryService.addReceivedEntry(
        senderProfile: profile,
        method: method,
        location: null, // Location tracking handled separately
        metadata: {
          'source': 'card_reception_service',
          'firestore_fetched': receivedProfile == null, // true if we got data from Firestore
          'has_complete_data': profile.socialMedia.isNotEmpty || profile.customLinks.isNotEmpty,
        },
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '✅ Card reception completed successfully\n'
        '   • Profile: ${profile.name}\n'
        '   • Method: ${method.label}\n'
        '   • Duration: ${duration}ms\n'
        '   • vCard saved: $vCardSaved',
        name: 'CardReception.Success',
      );

      return true;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      developer.log(
        '❌ Card reception failed\n'
        '   • Profile ID: $profileId\n'
        '   • Method: ${method.label}\n'
        '   • Duration: ${duration}ms\n'
        '   • Error: $e',
        name: 'CardReception.Error',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Save vCard to device contacts
  static Future<bool> _saveVCardToContacts(ProfileData profile, ShareMethod method) async {
    try {
      // Generate vCard with embedded metadata
      final shareContext = ShareContext(
        method: method,
        timestamp: DateTime.now(),
      );

      // Get vCard from ProfileData (uses optimized generation)
      final vCardContent = profile.getDualPayloadWithContext(shareContext)['vcard']!;

      developer.log(
        '   📇 Generated vCard for contact save\n'
        '   • Size: ${vCardContent.length} bytes\n'
        '   • Has metadata: true',
        name: 'CardReception.VCard',
      );

      // Create contact from ProfileData
      final nameParts = profile.name.split(' ');
      final contact = Contact()
        ..name = Name(
          first: nameParts.isNotEmpty ? nameParts.first : '',
          last: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        )
        ..phones = profile.phone != null ? [Phone(profile.phone!)] : []
        ..emails = profile.email != null ? [Email(profile.email!)] : []
        ..organizations = (profile.company != null || profile.title != null)
            ? [Organization(company: profile.company ?? '', title: profile.title ?? '')]
            : []
        ..websites = [
          Website('https://atlaslinq.com/share/${profile.id}_${profile.type.name}'),
          if (profile.website != null) Website(profile.website!),
        ]
        ..notes = [
          Note('$vCardContent\n\nShared via Atlas Linq')
        ];

      // Save to device
      await contact.insert();

      developer.log(
        '   ✅ Contact saved to device\n'
        '   • Name: ${profile.name}',
        name: 'CardReception.VCard',
      );

      return true;
    } catch (e, stackTrace) {
      developer.log(
        '   ❌ Failed to save vCard to contacts: $e',
        name: 'CardReception.VCard',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
