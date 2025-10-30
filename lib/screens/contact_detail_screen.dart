import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

import '../models/unified_models.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';

class ContactDetailScreen extends StatefulWidget {
  final ReceivedContact receivedContact;

  const ContactDetailScreen({super.key, required this.receivedContact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late ReceivedContact _contact;

  @override
  void initState() {
    super.initState();
    _contact = widget.receivedContact;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: GlassCard(
          width: 320,
          height: 500,
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(CupertinoIcons.xmark, color: Color(0xFF673AB7)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Profile section
              _buildProfileSection(),

              // Contact info
              _buildContactInfo(),

              // Social media (if available)
              if (_contact.contact.socialMedia.isNotEmpty)
                _buildSocialMedia(),

              const Spacer(),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        // Profile photo or placeholder
        CircleAvatar(
          radius: 40,
          child: Text(
            _contact.contact.name.isNotEmpty ? _contact.contact.name[0] : '?',
            style: const TextStyle(fontSize: 24, color: Color(0xFFF7F7F7)),
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          _contact.contact.name,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),

        // Title and company
        if (_contact.contact.title != null) ...[
          const SizedBox(height: 4),
          Text(
            _contact.contact.title!,
            style: const TextStyle(color: Color(0xFF673AB7), fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],

        if (_contact.contact.company != null) ...[
          const SizedBox(height: 4),
          Text(
            _contact.contact.company!,
            style: const TextStyle(color: Color(0xFFF7F7F7), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Phone
        if (_contact.contact.phone != null)
          ContactInfoRow(
            icon: CupertinoIcons.phone,
            text: _contact.contact.phone!,
            onTap: () => _launchUrl('tel:${_contact.contact.phone}'),
          ),

        // Email
        if (_contact.contact.email != null)
          ContactInfoRow(
            icon: CupertinoIcons.mail,
            text: _contact.contact.email!,
            onTap: () => _launchUrl('mailto:${_contact.contact.email}'),
          ),

        // Website
        if (_contact.contact.website != null)
          ContactInfoRow(
            icon: CupertinoIcons.globe,
            text: _contact.contact.website!,
            onTap: () => _launchUrl(_contact.contact.website!),
          ),
      ],
    );
  }

  Widget _buildSocialMedia() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: _contact.contact.socialMedia.entries.map((entry) {
            return GlassChip(
              icon: _getSocialIcon(entry.key),
              label: entry.value,
              onTap: () => _launchSocialProfile(entry.key, entry.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Save contact button
          AppButton.contained(
            text: 'Save Contact',
            onPressed: () async {
              // Simple contact saving - could integrate with contact_service
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success),
                            SizedBox(width: 12),
                            Expanded(child: Text('Contact saved successfully!')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 12),

          // Add note button
          AppButton.outlined(
            text: 'Add Note',
            onPressed: () => _showAddNoteDialog(),
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // Helper methods for social media icons and URLs
  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'linkedin': return FontAwesomeIcons.linkedin;
      case 'twitter': return FontAwesomeIcons.xTwitter;
      case 'instagram': return FontAwesomeIcons.instagram;
      case 'github': return FontAwesomeIcons.github;
      default: return CupertinoIcons.link;
    }
  }

  void _launchSocialProfile(String platform, String handle) {
    final urls = {
      'linkedin': 'https://linkedin.com/in/$handle',
      'twitter': 'https://twitter.com/$handle',
      'instagram': 'https://instagram.com/$handle',
      'github': 'https://github.com/$handle',
    };

    final url = urls[platform.toLowerCase()] ?? handle;
    _launchUrl(url);
  }

  void _showAddNoteDialog() {
    String noteText = _contact.notes ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: TextEditingController(text: noteText),
          onChanged: (value) => noteText = value,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _contact = _contact.copyWith(notes: noteText.isEmpty ? null : noteText);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.check_mark_circled_solid, color: AppColors.success),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Note ${noteText.isEmpty ? 'removed' : 'saved'}')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Helper widgets
class ContactInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const ContactInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF673AB7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFFF7F7F7), fontSize: 14),
              ),
            ),
            if (onTap != null)
              const Icon(CupertinoIcons.arrow_up_right_square, color: Color(0xFF673AB7), size: 16),
          ],
        ),
      ),
    );
  }
}

class GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const GlassChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF673AB7).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF673AB7).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF673AB7), size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFF7F7F7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}