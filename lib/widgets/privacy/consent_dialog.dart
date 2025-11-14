/// GDPR Consent Dialog
///
/// Shows consent dialog on first app launch
/// Allows users to control their privacy preferences
library;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../core/services/privacy_service.dart';

/// GDPR Consent Dialog
class ConsentDialog extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback? onReject;

  const ConsentDialog({
    super.key,
    required this.onAccept,
    this.onReject,
  });

  /// Show consent dialog if needed
  static Future<void> showIfNeeded(BuildContext context) async {
    final privacyService = PrivacyService();
    final hasConsent = await privacyService.hasConsent();

    if (!hasConsent && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConsentDialog(
          onAccept: () {
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _analyticsConsent = true;
  bool _dataProcessingConsent = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, size: 28),
          SizedBox(width: 12),
          Text('Privacy & Data'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We care about your privacy. Please review and accept our data practices:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _dataProcessingConsent,
              onChanged: (value) {
                setState(() {
                  _dataProcessingConsent = value ?? false;
                });
              },
              title: const Text(
                'Data Processing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Required to use the app. Your data is stored securely and never sold to third parties.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _analyticsConsent,
              onChanged: (value) {
                setState(() {
                  _analyticsConsent = value ?? false;
                });
              },
              title: const Text(
                'Analytics (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Help us improve by collecting anonymous usage data.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // Open privacy policy
                        _showPrivacyPolicy(context);
                      },
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // Open terms of service
                        _showTerms(context);
                      },
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onReject != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onReject?.call();
            },
            child: const Text('Decline'),
          ),
        ElevatedButton(
          onPressed: _dataProcessingConsent
              ? () async {
                  // Save consent
                  await PrivacyService().saveConsent(
                    analyticsConsent: _analyticsConsent,
                    dataProcessingConsent: _dataProcessingConsent,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  widget.onAccept();
                }
              : null,
          child: const Text('Accept'),
        ),
      ],
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This privacy policy explains what personal data we collect and how we use it.\n\n'
            '1. Data Collection: We collect profile information you provide and usage analytics (if consented).\n\n'
            '2. Data Usage: Your data is used solely to provide and improve our services.\n\n'
            '3. Data Sharing: We never sell your data to third parties.\n\n'
            '4. Data Security: All data is encrypted and stored securely.\n\n'
            '5. Your Rights: You can export or delete your data at any time.\n\n'
            '6. Contact: For privacy concerns, contact support@tapcard.app',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using TapCard, you agree to the following terms:\n\n'
            '1. Service Use: Use the service responsibly and legally.\n\n'
            '2. Content: You own your content. We store it securely.\n\n'
            '3. Prohibited Use: No spam, abuse, or illegal activity.\n\n'
            '4. Service Changes: We may update features with notice.\n\n'
            '5. Termination: You can delete your account anytime.\n\n'
            '6. Limitation of Liability: Service provided "as is".\n\n'
            '7. Governing Law: Subject to applicable laws.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Privacy Settings Screen
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _privacyService = PrivacyService();
  bool _analyticsEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _privacyService.isAnalyticsEnabled();
    setState(() {
      _analyticsEnabled = enabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Manage your privacy and data preferences',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Analytics'),
                  subtitle: const Text(
                    'Help us improve by sharing anonymous usage data',
                  ),
                  value: _analyticsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      await _privacyService.enableAnalytics();
                    } else {
                      await _privacyService.disableAnalytics();
                    }
                    setState(() {
                      _analyticsEnabled = value;
                    });
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export My Data'),
                  subtitle: const Text('Download all your data'),
                  onTap: () => _exportData(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Permanently delete all your data'),
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'Your data will be downloaded as a JSON file. This may take a moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final jsonData = await _privacyService.exportUserDataAsJson();

        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading

          // Show success with data
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Data Exported'),
              content: SingleChildScrollView(
                child: SelectableText(jsonData),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete all your data and cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        await _privacyService.deleteUserData();

        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading

          // Navigate to welcome screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deletion failed: $e')),
          );
        }
      }
    }
  }
}
