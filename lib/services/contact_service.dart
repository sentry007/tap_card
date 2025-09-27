import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// TODO: Uncomment when packages are added to pubspec.yaml
// import 'package:permission_handler/permission_handler.dart';
// import 'package:contacts_service/contacts_service.dart';

import '../models/unified_models.dart';

/// Result of contact save operation
class ContactSaveResult {
  final bool success;
  final String message;
  final String? error;

  ContactSaveResult.success(this.message) : success = true, error = null;
  ContactSaveResult.error(this.error) : success = false, message = '';
}

/// Service for managing device contacts integration
class ContactService {

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

  /// Check if device contacts permission is granted
  static Future<bool> hasContactsPermission() async {
    // TODO: Implement actual permission check when contacts_service is added
    // final permission = await Permission.contacts.status;
    // return permission == PermissionStatus.granted;

    // For now, return true (simulated)
    return true;
  }

  /// Request contacts permission
  static Future<bool> requestContactsPermission() async {
    // TODO: Implement actual permission request when contacts_service is added
    // final permission = await Permission.contacts.request();
    // return permission == PermissionStatus.granted;

    // For now, return true (simulated)
    print('📱 Contacts permission requested (simulated)');
    return true;
  }
}