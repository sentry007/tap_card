import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Function(Map<String, dynamic>)? _onCardReceived;

  void initialize() {
    // Initialize local notifications
    // This would typically use flutter_local_notifications
    // For now, we'll use in-app notifications
  }

  void setCardReceivedCallback(Function(Map<String, dynamic>) callback) {
    _onCardReceived = callback;
  }

  Future<void> showCardReceivedNotification(Map<String, dynamic> cardData) async {
    final name = cardData['name'] as String? ?? 'Unknown Contact';

    // Trigger haptic feedback
    HapticFeedback.heavyImpact();

    // Call the callback if set
    _onCardReceived?.call(cardData);

    // This would show a system notification in a real implementation
    debugPrint('Card received from: $name');
  }

  void showInAppNotification(
    BuildContext context,
    Map<String, dynamic> cardData,
  ) {
    final name = cardData['name'] as String? ?? 'Unknown Contact';
    final company = cardData['company'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CardReceivedModal(
        cardData: cardData,
        name: name,
        company: company,
      ),
    );
  }
}

class _CardReceivedModal extends StatelessWidget {
  final Map<String, dynamic> cardData;
  final String name;
  final String? company;

  const _CardReceivedModal({
    required this.cardData,
    required this.name,
    this.company,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Contact Received!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Contact info
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (company != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    company!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Open',
                        CupertinoIcons.arrow_up_right_square,
                        () {
                          Navigator.pop(context);
                          _openContactDetails(context, cardData);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'Add to Contacts',
                        CupertinoIcons.person_add,
                        () {
                          Navigator.pop(context);
                          _addToContacts(context, cardData);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dismiss button
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    'Dismiss',
                    CupertinoIcons.xmark,
                    () => Navigator.pop(context),
                    outlined: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: outlined
              ? Colors.transparent
              : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(outlined ? 0.3 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openContactDetails(BuildContext context, Map<String, dynamic> cardData) {
    // Navigate to contact detail view
    // This would be implemented based on your navigation setup
    debugPrint('Opening contact details for: ${cardData['name']}');
  }

  void _addToContacts(BuildContext context, Map<String, dynamic> cardData) {
    // Add to device contacts
    // This would integrate with the contacts plugin
    debugPrint('Adding to contacts: ${cardData['name']}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${cardData['name']} added to contacts'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}