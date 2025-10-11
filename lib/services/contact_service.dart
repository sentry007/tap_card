import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/unified_models.dart';

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

  // Metadata extracted from vCard X-TC fields
  final ShareMethod? shareMethod;      // How the card was shared (N/Q/L/T)
  final DateTime? shareTimestamp;      // When the card was shared (unix timestamp)
  final ProfileType? profileType;      // Profile type (1/2/3)

  TapCardContact({
    required this.displayName,
    required this.profileId,
    this.isLegacyFormat = false,
    this.shareMethod,
    this.shareTimestamp,
    this.profileType,
  });

  @override
  String toString() => 'TapCardContact($displayName, $profileId, legacy: $isLegacyFormat, method: ${shareMethod?.label}, time: $shareTimestamp)';
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
      print('📇 [Silent Check] Contacts permission status: ${status.name}');
      return status.isGranted;
    } catch (e) {
      print('❌ [Silent Check] Error checking permission: $e');
      return false;
    }
  }

  /// Scan device contacts and find those with TapCard URLs
  /// Returns list of TapCardContact objects with extracted profile IDs
  ///
  /// Uses flutter_contacts package which has proper support for website/URL fields.
  /// Supports both new UUID-based URLs and legacy name-based URLs for backward compatibility.
  ///
  /// New format: https://tapcard.app/share/[uuid]
  /// Legacy format: https://tapcard.app/share/[name]
  static Future<List<TapCardContact>> scanForTapCardContactsWithIds() async {
    try {
      // Check/request permission using flutter_contacts
      print('📇 Requesting contacts permission via flutter_contacts...');
      final permissionGranted = await FlutterContacts.requestPermission();
      print('📇 flutter_contacts.requestPermission() result: ${permissionGranted ? "✅ GRANTED" : "❌ DENIED"}');

      if (!permissionGranted) {
        // Known bug: requestPermission() sometimes returns false even after user grants
        // Fallback: Check permission status using permission_handler
        print('📇 Retrying with permission_handler fallback...');
        await Future.delayed(const Duration(milliseconds: 500)); // Give Android time to propagate

        final status = await Permission.contacts.status;
        print('📇 permission_handler.status result: ${status.name}');

        if (!status.isGranted) {
          print('📇 Cannot scan contacts - permission denied (verified with fallback)');
          return [];
        }

        print('✅ Permission is actually GRANTED (flutter_contacts bug bypassed)');
      }

      print('📇 Scanning contacts for TapCard URLs...');

      // Get all contacts with website data
      final contacts = await FlutterContacts.getContacts(
        withProperties: true, // Include websites, emails, phones, etc.
        withPhoto: false, // Don't load photos for performance
      );

      print('📇 Total contacts on device: ${contacts.length}');

      final tapCardContacts = <TapCardContact>[];

      // Check each contact for TapCard URL pattern
      for (final contact in contacts) {
        String? tapCardUrl;

        // Log contact name and websites for debugging
        final contactName = contact.displayName.isNotEmpty
            ? contact.displayName
            : contact.name.first.isNotEmpty
                ? contact.name.first
                : 'Unknown';

        if (contact.websites.isNotEmpty) {
          print('  📱 Contact: $contactName - Websites: ${contact.websites.map((w) => w.url).join(", ")}');
        }

        // Check websites field (proper URL storage)
        if (contact.websites.isNotEmpty) {
          for (final website in contact.websites) {
            if (website.url.contains('tap-card-site.vercel.app/share/')) {
              tapCardUrl = website.url;
              print('    ✅ FOUND TapCard URL: $tapCardUrl');
              break;
            }
          }
        }

        // Check notes field (fallback, some apps store URLs here)
        if (tapCardUrl == null && contact.notes.isNotEmpty) {
          for (final note in contact.notes) {
            if (note.note.contains('tap-card-site.vercel.app/share/')) {
              // Extract URL from note text
              final urlMatch = RegExp(r'https://tap-card-site\.vercel\.app/share/[^\s]+')
                  .firstMatch(note.note);
              if (urlMatch != null) {
                tapCardUrl = urlMatch.group(0);
                print('    ✅ FOUND TapCard URL in notes: $tapCardUrl');
                break;
              }
            }
          }
        }

        // If we found a TapCard URL, extract the profile ID and metadata
        if (tapCardUrl != null) {
          final displayName = contact.displayName.isNotEmpty
              ? contact.displayName
              : contact.name.first.isNotEmpty
                  ? contact.name.first
                  : 'Unknown';

          // Extract the ID part after "share/"
          final idPart = tapCardUrl.split('tap-card-site.vercel.app/share/').last;
          print('    🔍 Extracted ID: $idPart');

          // Check if it's a UUID format (new) or name format (legacy)
          final isUuidFormat = _isValidUuid(idPart);
          print('    🔍 UUID validation: ${isUuidFormat ? "✅ VALID" : "❌ LEGACY FORMAT"}');

          // Extract metadata from vCard X-TC fields in notes
          ShareMethod? extractedMethod;
          DateTime? extractedTimestamp;
          ProfileType? extractedType;

          for (final note in contact.notes) {
            final noteText = note.note;

            // X-TC-M: Method code (N/Q/L/T)
            if (noteText.contains('X-TC-M:')) {
              final methodCode = noteText
                  .split('X-TC-M:')[1]
                  .split('\n')[0]
                  .trim();
              try {
                extractedMethod = ShareContext.methodFromCode(methodCode);
                print('    📊 Extracted method: ${extractedMethod.label}');
              } catch (e) {
                print('    ⚠️ Failed to parse method code: $methodCode');
              }
            }

            // X-TC-T: Unix timestamp
            if (noteText.contains('X-TC-T:')) {
              final timestampStr = noteText
                  .split('X-TC-T:')[1]
                  .split('\n')[0]
                  .trim();
              final unixTimestamp = int.tryParse(timestampStr);
              if (unixTimestamp != null) {
                extractedTimestamp = ShareContext.timestampFromUnix(unixTimestamp);
                print('    📊 Extracted timestamp: $extractedTimestamp');
              }
            }

            // X-TC-P: Profile type code (1/2/3)
            if (noteText.contains('X-TC-P:')) {
              final typeCode = noteText
                  .split('X-TC-P:')[1]
                  .split('\n')[0]
                  .trim();
              final code = int.tryParse(typeCode);
              if (code != null) {
                extractedType = ProfileType.fromCode(code);
                print('    📊 Extracted profile type: ${extractedType.label}');
              }
            }
          }

          final tapCardContact = TapCardContact(
            displayName: displayName,
            profileId: idPart,
            isLegacyFormat: !isUuidFormat,
            shareMethod: extractedMethod,
            shareTimestamp: extractedTimestamp,
            profileType: extractedType,
          );

          tapCardContacts.add(tapCardContact);
          print('    ✅ Added to TapCard contacts list: $displayName '
                '(${isUuidFormat ? 'UUID' : 'legacy'}: $idPart, '
                'has metadata: ${extractedMethod != null})');
        }
      }

      print('📇 ========================================');
      print('📇 SCAN COMPLETE: Found ${tapCardContacts.length} TapCard contacts');
      if (tapCardContacts.isNotEmpty) {
        print('📇 Contact names: ${tapCardContacts.map((c) => c.displayName).join(", ")}');
      }
      print('📇 ========================================');
      return tapCardContacts;
    } catch (e) {
      print('❌ Error scanning contacts: $e');
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
  /// Relaxed validation: accepts 10-12 characters in last segment for compatibility
  static bool _isValidUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{10,12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(value);
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
      print('📱 Requesting contacts permission (simulated)');

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

      print('📞 Contact saved: ${contact.name}');
      return ContactSaveResult.success('Contact saved successfully');

    } catch (e) {
      print('❌ Error saving essential contact: $e');
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
      print('📱 Requesting contacts permission for full contact (simulated)');

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

      print('📞 Received contact saved: ${receivedContact.contact.name}');
      return ContactSaveResult.success('Full contact saved successfully');

    } catch (e) {
      print('❌ Error saving full contact: $e');
      return ContactSaveResult.error('Failed to save full contact: $e');
    }
  }

  /// Get all saved contacts
  static Future<List<Map<String, dynamic>>> getSavedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedContacts = prefs.getStringList('saved_contacts') ?? [];

      return savedContacts
          .map((contact) => jsonDecode(contact) as Map<String, dynamic>)
          .toList()
        ..sort((a, b) => b['saved_at'].compareTo(a['saved_at'])); // Most recent first

    } catch (e) {
      print('❌ Error getting saved contacts: $e');
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
      print('❌ Error checking contact existence: $e');
      return false;
    }
  }

  /// Get contact save statistics
  static Future<Map<String, dynamic>> getContactStats() async {
    try {
      final savedContacts = await getSavedContacts();
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final totalSaved = savedContacts.length;
      final recentSaves = savedContacts.where((contact) {
        final savedAt = DateTime.parse(contact['saved_at']);
        return savedAt.isAfter(thirtyDaysAgo);
      }).length;

      final sourceBreakdown = <String, int>{};
      for (final contact in savedContacts) {
        final source = contact['source'] ?? 'unknown';
        sourceBreakdown[source] = (sourceBreakdown[source] ?? 0) + 1;
      }

      return {
        'total_saved': totalSaved,
        'recent_saves': recentSaves,
        'source_breakdown': sourceBreakdown,
        'last_saved': savedContacts.isNotEmpty
            ? savedContacts.first['saved_at']
            : null,
      };

    } catch (e) {
      print('❌ Error getting contact stats: $e');
      return {
        'total_saved': 0,
        'recent_saves': 0,
        'source_breakdown': {},
        'last_saved': null,
      };
    }
  }

  /// Delete saved contact
  static Future<bool> deleteSavedContact(String contactId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedContacts = prefs.getStringList('saved_contacts') ?? [];

      final updatedContacts = savedContacts.where((contact) {
        final contactData = jsonDecode(contact) as Map<String, dynamic>;
        return contactData['id'] != contactId;
      }).toList();

      await prefs.setStringList('saved_contacts', updatedContacts);

      print('🗑️ Contact deleted: $contactId');
      return true;

    } catch (e) {
      print('❌ Error deleting contact: $e');
      return false;
    }
  }

  /// Clear all saved contacts
  static Future<void> clearAllSavedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_contacts');
      print('🗑️ All saved contacts cleared');
    } catch (e) {
      print('❌ Error clearing saved contacts: $e');
    }
  }
}