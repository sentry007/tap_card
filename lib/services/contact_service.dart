import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/unified_models.dart';
import '../utils/logger.dart';
import 'history_service.dart';

/// Result of contact save operation
class ContactSaveResult {
  final bool success;
  final String message;
  final String? error;

  ContactSaveResult.success(this.message) : success = true, error = null;
  ContactSaveResult.error(this.error) : success = false, message = '';
}

/// TapCard contact found in device contacts
class TapCardContact {
  final String displayName;
  final String profileId; // UUID extracted from TapCard URL
  final bool isLegacyFormat; // True if old name-based URL format

  // Metadata extracted from vCard X-AL fields
  final ShareMethod? shareMethod;      // How the card was shared (N/Q/L/T)
  final DateTime? shareTimestamp;      // When the card was shared (unix timestamp)
  final ProfileType? profileType;      // Profile type (1/2/3)

  // vCard data fields (extracted from device contact)
  // These serve as fallback when Firestore fetch fails
  final String? phone;
  final String? email;
  final String? company;
  final String? title;
  final String? website; // User's personal website (not Atlas Linq URL)

  TapCardContact({
    required this.displayName,
    required this.profileId,
    this.isLegacyFormat = false,
    this.shareMethod,
    this.shareTimestamp,
    this.profileType,
    this.phone,
    this.email,
    this.company,
    this.title,
    this.website,
  });

  @override
  String toString() => 'TapCardContact($displayName, $profileId, legacy: $isLegacyFormat, method: ${shareMethod?.label}, phone: ${phone != null ? "✓" : "✗"}, email: ${email != null ? "✓" : "✗"})';
}

/// Service for managing device contacts integration
class ContactService {

  /// Request contacts permission
  static Future<PermissionStatus> requestContactsPermission() async {
    final permission = await Permission.contacts.request();
    return permission;
  }

  /// Check if contacts permission is granted (silent check, no dialog)
  static Future<bool> hasContactsPermission() async {
    try {
      final status = await Permission.contacts.status;
      Logger.debug('[Silent Check] Contacts permission status: ${status.name}', name: 'ContactService');
      return status.isGranted;
    } catch (e) {
      Logger.error('[Silent Check] Error checking permission: $e', name: 'ContactService', error: e);
      return false;
    }
  }

  /// Scan device contacts and find those with Atlas Linq URLs
  /// Returns list of TapCardContact objects with extracted profile IDs
  ///
  /// Uses flutter_contacts package which has proper support for website/URL fields.
  /// Supports both new UUID-based URLs and legacy name-based URLs for backward compatibility.
  ///
  /// New format: https://atlaslinq.com/share/[uuid]
  /// Legacy format: https://atlaslinq.com/share/[name]
  static Future<List<TapCardContact>> scanForTapCardContactsWithIds() async {
    try {
      // Check/request permission using flutter_contacts
      Logger.info('Requesting contacts permission via flutter_contacts...', name: 'ContactService');
      final permissionGranted = await FlutterContacts.requestPermission();
      Logger.info('flutter_contacts.requestPermission() result: ${permissionGranted ? "GRANTED" : "DENIED"}', name: 'ContactService');

      if (!permissionGranted) {
        // Known bug: requestPermission() sometimes returns false even after user grants
        // Fallback: Check permission status using permission_handler
        Logger.info('Retrying with permission_handler fallback...', name: 'ContactService');
        await Future.delayed(const Duration(milliseconds: 500)); // Give Android time to propagate

        final status = await Permission.contacts.status;
        Logger.info('permission_handler.status result: ${status.name}', name: 'ContactService');

        if (!status.isGranted) {
          Logger.warning('Cannot scan contacts - permission denied (verified with fallback)', name: 'ContactService');
          return [];
        }

        Logger.info('Permission is actually GRANTED (flutter_contacts bug bypassed)', name: 'ContactService');
      }

      Logger.info('Scanning contacts for Atlas Linq URLs...', name: 'ContactService');

      // Get all contacts with website data
      final contacts = await FlutterContacts.getContacts(
        withProperties: true, // Include websites, emails, phones, etc.
        withPhoto: false, // Don't load photos for performance
      );

      Logger.info('Total contacts on device: ${contacts.length}', name: 'ContactService');

      final tapCardContacts = <TapCardContact>[];

      // Check each contact for Atlas Linq URL pattern
      for (final contact in contacts) {
        String? tapCardUrl;

        // Log contact name and websites for debugging
        final contactName = contact.displayName.isNotEmpty
            ? contact.displayName
            : contact.name.first.isNotEmpty
                ? contact.name.first
                : 'Unknown';

        if (contact.websites.isNotEmpty) {
          Logger.debug('Contact: $contactName - Websites: ${contact.websites.map((w) => w.url).join(", ")}', name: 'ContactService');
        }

        // Check websites field (proper URL storage)
        if (contact.websites.isNotEmpty) {
          for (final website in contact.websites) {
            if (website.url.contains('atlaslinq.com/share/')) {
              tapCardUrl = website.url;
              Logger.info('FOUND Atlas Linq URL: $tapCardUrl', name: 'ContactService');
              break;
            }
          }
        }

        // Check notes field (fallback, some apps store URLs here)
        if (tapCardUrl == null && contact.notes.isNotEmpty) {
          for (final note in contact.notes) {
            if (note.note.contains('atlaslinq.com/share/')) {
              // Extract URL from note text
              final urlMatch = RegExp(r'https://atlaslinq\.com/share/[^\s]+')
                  .firstMatch(note.note);
              if (urlMatch != null) {
                tapCardUrl = urlMatch.group(0);
                Logger.info('FOUND Atlas Linq URL in notes: $tapCardUrl', name: 'ContactService');
                break;
              }
            }
          }
        }

        // If we found a Atlas Linq URL, extract the profile ID and metadata
        if (tapCardUrl != null) {
          final displayName = contact.displayName.isNotEmpty
              ? contact.displayName
              : contact.name.first.isNotEmpty
                  ? contact.name.first
                  : 'Unknown';

          // Extract the ID part after "share/"
          final idPart = tapCardUrl.split('atlaslinq.com/share/').last;
          Logger.debug('Extracted ID: $idPart', name: 'ContactService');

          // Check if it's a UUID format (new) or name format (legacy)
          final isUuidFormat = _isValidUuid(idPart);
          Logger.debug('UUID validation: ${isUuidFormat ? "VALID" : "LEGACY FORMAT"}', name: 'ContactService');

          // Extract metadata from vCard X-AL fields in notes
          ShareMethod? extractedMethod;
          DateTime? extractedTimestamp;
          ProfileType? extractedType;

          for (final note in contact.notes) {
            final noteText = note.note;

            // X-AL-M: Method code (N/Q/L/T)
            if (noteText.contains('X-AL-M:')) {
              final methodCode = noteText
                  .split('X-AL-M:')[1]
                  .split(RegExp(r'\\n|\n'))[0]
                  .trim();
              try {
                extractedMethod = ShareContext.methodFromCode(methodCode);
                Logger.debug('Extracted method: ${extractedMethod.label}', name: 'ContactService');
              } catch (e) {
                Logger.warning('Failed to parse method code: $methodCode', name: 'ContactService');
              }
            }

            // X-AL-T: Unix timestamp
            if (noteText.contains('X-AL-T:')) {
              final timestampStr = noteText
                  .split('X-AL-T:')[1]
                  .split(RegExp(r'\\n|\n'))[0]
                  .trim();
              final unixTimestamp = int.tryParse(timestampStr);
              if (unixTimestamp != null) {
                extractedTimestamp = ShareContext.timestampFromUnix(unixTimestamp);
                Logger.debug('Extracted timestamp: $extractedTimestamp', name: 'ContactService');
              }
            }

            // X-AL-P: Profile type code (1/2/3)
            if (noteText.contains('X-AL-P:')) {
              final typeCode = noteText
                  .split('X-AL-P:')[1]
                  .split(RegExp(r'\\n|\n'))[0]
                  .trim();
              final code = int.tryParse(typeCode);
              if (code != null) {
                extractedType = ProfileType.fromCode(code);
                Logger.debug('Extracted profile type: ${extractedType.label}', name: 'ContactService');
              }
            }
          }

          // Extract vCard data fields for fallback when Firestore is unavailable
          String? vCardPhone;
          String? vCardEmail;
          String? vCardCompany;
          String? vCardTitle;
          String? vCardWebsite;

          // Extract phone (prefer first mobile, then first number)
          if (contact.phones.isNotEmpty) {
            vCardPhone = contact.phones.first.number;
            Logger.debug('Extracted phone: $vCardPhone', name: 'ContactService');
          }

          // Extract email (prefer first work email, then first email)
          if (contact.emails.isNotEmpty) {
            vCardEmail = contact.emails.first.address;
            Logger.debug('Extracted email: $vCardEmail', name: 'ContactService');
          }

          // Extract company and title from organizations
          if (contact.organizations.isNotEmpty) {
            final org = contact.organizations.first;
            vCardCompany = org.company;
            vCardTitle = org.title;
            if (vCardCompany != null) {
              if (vCardCompany.isNotEmpty) {
                Logger.debug('Extracted company: $vCardCompany', name: 'ContactService');
              }
            }
            if (vCardTitle != null) {
              if (vCardTitle.isNotEmpty) {
                Logger.debug('Extracted title: $vCardTitle', name: 'ContactService');
              }
            }
          }

          // Extract personal website (exclude Atlas Linq URLs)
          for (final website in contact.websites) {
            if (!website.url.contains('atlaslinq.com') &&
                website.url.isNotEmpty) {
              vCardWebsite = website.url;
              Logger.debug('Extracted website: $vCardWebsite', name: 'ContactService');
              break;
            }
          }

          final tapCardContact = TapCardContact(
            displayName: displayName,
            profileId: idPart,
            isLegacyFormat: !isUuidFormat,
            shareMethod: extractedMethod,
            shareTimestamp: extractedTimestamp,
            profileType: extractedType,
            phone: vCardPhone,
            email: vCardEmail,
            company: vCardCompany,
            title: vCardTitle,
            website: vCardWebsite,
          );

          tapCardContacts.add(tapCardContact);
          Logger.info(
            'Added to Atlas Linq contacts list: $displayName '
            '(${isUuidFormat ? 'UUID' : 'legacy'}: $idPart, '
            'has metadata: ${extractedMethod != null}, '
            'has vCard data: phone=${vCardPhone != null}, email=${vCardEmail != null})',
            name: 'ContactService',
          );
        }
      }

      Logger.info('SCAN COMPLETE: Found ${tapCardContacts.length} Atlas Linq contacts', name: 'ContactService');
      if (tapCardContacts.isNotEmpty) {
        Logger.info('Contact names: ${tapCardContacts.map((c) => c.displayName).join(", ")}', name: 'ContactService');
      }
      return tapCardContacts;
    } catch (e) {
      Logger.error('Error scanning contacts: $e', name: 'ContactService', error: e);
      return [];
    }
  }

  /// Legacy method for backward compatibility - returns just display names
  /// Use scanForTapCardContactsWithIds() for new code that needs profile IDs
  static Future<List<String>> scanForTapCardContacts() async {
    final contacts = await scanForTapCardContactsWithIds();
    return contacts.map((c) => c.displayName).toList();
  }

  /// Validate if a string is a valid UUID format
  /// Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (8-4-4-4-10to12)
  /// Accepts UUID with or without type suffix (_personal, _professional, _custom)
  /// Relaxed validation: accepts 10-12 characters in last segment for compatibility
  static bool _isValidUuid(String value) {
    // Strip type suffix if present (_personal, _professional, _custom)
    // This handles the new format: uuid_type (e.g., ce61e357-d346-4311-8299-a79682ed09ab_personal)
    final cleanValue = value.replaceFirst(RegExp(r'_(personal|professional|custom)$'), '');

    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{10,12}$',
      caseSensitive: false,
    );

    final isValid = uuidRegex.hasMatch(cleanValue);
    Logger.debug('UUID validation: $value → cleaned: $cleanValue → isValid: $isValid', name: 'ContactService');
    return isValid;
  }

  /// Save contact data to device contacts
  static Future<ContactSaveResult> saveContact(ContactData contact) async {
    try {
      // TODO: Uncomment when permission_handler is added
      // Request contacts permission
      // final permission = await Permission.contacts.request();
      //
      // if (permission.isDenied) {
      //   return ContactSaveResult.error('Contacts permission denied');
      // }
      //
      // // Create contact with essential data
      // final contact = Contact(
      //   givenName: essential.name,
      //   jobTitle: essential.title,
      //   company: essential.company,
      //   phones: essential.phone != null ? [Phone(essential.phone!)] : [],
      //   emails: essential.email != null ? [Email(essential.email!)] : [],
      // );
      //
      // // Save to device
      // await ContactsService.addContact(contact);
      //
      // return ContactSaveResult.success('Contact saved successfully');

      // For now, simulate saving with improved structure
      Logger.info('Requesting contacts permission (simulated)', name: 'ContactService');

      final contactRecord = {
        'id': 'contact_${DateTime.now().millisecondsSinceEpoch}',
        'given_name': contact.name,
        'job_title': contact.title,
        'company': contact.company,
        'phones': contact.phone != null ? [contact.phone!] : [],
        'emails': contact.email != null ? [contact.email!] : [],
        'saved_at': DateTime.now().toIso8601String(),
        'source': 'nfc_card',
      };

      final prefs = await SharedPreferences.getInstance();
      final savedContacts = prefs.getStringList('saved_contacts') ?? [];
      savedContacts.add(jsonEncode(contactRecord));
      await prefs.setStringList('saved_contacts', savedContacts);

      Logger.info('Contact saved: ${contact.name}', name: 'ContactService');
      return ContactSaveResult.success('Contact saved successfully');

    } catch (e) {
      Logger.error('Error saving essential contact: $e', name: 'ContactService', error: e);
      return ContactSaveResult.error('Failed to save contact: $e');
    }
  }

  /// Save received contact data (simplified)
  static Future<ContactSaveResult> saveReceivedContact(
    ReceivedContact receivedContact,
  ) async {
    try {
      // TODO: Uncomment when permission_handler and contacts_service are added
      // final permission = await Permission.contacts.request();
      // if (permission.isDenied) {
      //   return ContactSaveResult.error('Contacts permission denied');
      // }
      //
      // // Create contact with full data
      // final contact = Contact(
      //   givenName: essential.name,
      //   jobTitle: essential.title,
      //   company: essential.company,
      //   phones: essential.phone != null ? [Phone(essential.phone!)] : [],
      //   emails: essential.email != null ? [Email(essential.email!)] : [],
      //   urls: enhanced.website != null ? [Url(enhanced.website!)] : [],
      //   note: enhanced.bio,
      // );
      //
      // await ContactsService.addContact(contact);
      // return ContactSaveResult.success('Full contact saved successfully');

      // For now, simulate saving with full data structure
      Logger.info('Requesting contacts permission for full contact (simulated)', name: 'ContactService');

      final contactRecord = {
        'id': 'contact_${DateTime.now().millisecondsSinceEpoch}',
        'given_name': receivedContact.contact.name,
        'job_title': receivedContact.contact.title,
        'company': receivedContact.contact.company,
        'phones': receivedContact.contact.phone != null ? [receivedContact.contact.phone!] : [],
        'emails': receivedContact.contact.email != null ? [receivedContact.contact.email!] : [],
        'urls': receivedContact.contact.website != null ? [receivedContact.contact.website!] : [],
        'social_handles': receivedContact.contact.socialMedia,
        'notes': receivedContact.notes,
        'saved_at': DateTime.now().toIso8601String(),
        'source': 'nfc_card_received',
      };

      final prefs = await SharedPreferences.getInstance();
      final savedContacts = prefs.getStringList('saved_contacts') ?? [];
      savedContacts.add(jsonEncode(contactRecord));
      await prefs.setStringList('saved_contacts', savedContacts);

      Logger.info('Received contact saved: ${receivedContact.contact.name}', name: 'ContactService');
      return ContactSaveResult.success('Full contact saved successfully');

    } catch (e) {
      Logger.error('Error saving full contact: $e', name: 'ContactService', error: e);
      return ContactSaveResult.error('Failed to save full contact: $e');
    }
  }

  /// Get all saved contacts (delegates to HistoryService)
  /// Returns received contacts from history as Map format for backward compatibility
  static Future<List<Map<String, dynamic>>> getSavedContacts() async {
    try {
      // Get all received entries from HistoryService
      final receivedEntries = await HistoryService.getHistory(
        type: HistoryEntryType.received,
        limit: 100,
      );

      // Convert HistoryEntry to Map format for backward compatibility
      return receivedEntries.map((entry) {
        final profile = entry.senderProfile;
        return {
          'id': entry.id,
          'given_name': profile?.name ?? 'Unknown',
          'job_title': profile?.title,
          'company': profile?.company,
          'phones': profile?.phone != null ? [profile!.phone!] : [],
          'emails': profile?.email != null ? [profile!.email!] : [],
          'urls': profile?.website != null ? [profile!.website!] : [],
          'social_handles': profile?.socialMedia ?? {},
          'notes': null,
          'saved_at': entry.timestamp.toIso8601String(),
          'source': 'history_service',
        };
      }).toList();

    } catch (e) {
      Logger.error('Error getting saved contacts: $e', name: 'ContactService', error: e);
      return [];
    }
  }

  /// Check if contact already exists (by name and phone/email)
  static Future<bool> contactExists(ContactData contact) async {
    try {
      final savedContacts = await getSavedContacts();

      return savedContacts.any((saved) {
        return saved['name'] == contact.name &&
               (saved['phone'] == contact.phone ||
                saved['email'] == contact.email);
      });

    } catch (e) {
      Logger.error('Error checking contact existence: $e', name: 'ContactService', error: e);
      return false;
    }
  }

  /// Get contact save statistics (delegates to HistoryService)
  static Future<Map<String, dynamic>> getContactStats() async {
    try {
      final receivedCount = await HistoryService.getReceivedCount();
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final recentEntries = await HistoryService.getHistory(
        type: HistoryEntryType.received,
        since: thirtyDaysAgo,
        limit: 100,
      );

      return {
        'total_saved': receivedCount,
        'recent_saves': recentEntries.length,
        'source_breakdown': {'history_service': receivedCount},
        'last_saved': recentEntries.isNotEmpty
            ? recentEntries.first.timestamp.toIso8601String()
            : null,
      };

    } catch (e) {
      Logger.error('Error getting contact stats: $e', name: 'ContactService', error: e);
      return {
        'total_saved': 0,
        'recent_saves': 0,
        'source_breakdown': {},
        'last_saved': null,
      };
    }
  }

  /// Delete saved contact (delegates to HistoryService)
  static Future<bool> deleteSavedContact(String contactId) async {
    try {
      return await HistoryService.deleteEntry(contactId);
    } catch (e) {
      Logger.error('Error deleting contact: $e', name: 'ContactService', error: e);
      return false;
    }
  }

  /// Clear all saved contacts (delegates to HistoryService)
  static Future<void> clearAllSavedContacts() async {
    try {
      // Clear only received entries from history
      final allHistory = await HistoryService.getAllHistory();
      for (final entry in allHistory) {
        if (entry.type == HistoryEntryType.received) {
          await HistoryService.deleteEntry(entry.id);
        }
      }
      Logger.info('All saved contacts cleared', name: 'ContactService');
    } catch (e) {
      Logger.error('Error clearing saved contacts: $e', name: 'ContactService', error: e);
    }
  }
}