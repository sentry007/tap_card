import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../models/unified_models.dart';
import '../services/nfc_service.dart';
import '../services/history_service.dart';
import '../services/nfc_settings_service.dart';
import '../core/constants/routes.dart';
import '../core/providers/app_state.dart';
import '../widgets/widgets.dart';
import '../theme/theme.dart';

/// Screen for processing incoming NFC data and showing the received contact
class NFCReceiveScreen extends StatefulWidget {
  final String? nfcData;

  const NFCReceiveScreen({
    super.key,
    this.nfcData,
  });

  @override
  State<NFCReceiveScreen> createState() => _NFCReceiveScreenState();
}

class _NFCReceiveScreenState extends State<NFCReceiveScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  ReceivedContact? _receivedContact;
  bool _isProcessing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _processNFCData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _processNFCData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000)); // Simulate processing

      if (widget.nfcData == null || widget.nfcData!.isEmpty) {
        throw Exception('No NFC data received');
      }

      // Use simplified NFC service to process the data
      final processedData = NFCService.processReceivedData(widget.nfcData!);

      if (processedData == null) {
        throw Exception('Failed to process NFC data');
      }

      // Extract contact data
      final contactData = processedData['data'] as Map<String, dynamic>;
      final contact = ContactData.fromJson(contactData);

      // Create received contact with simplified structure
      final receivedContact = ReceivedContact(
        id: ReceivedContact.generateId(),
        contact: contact,
        receivedAt: DateTime.now(),
      );

      setState(() {
        _receivedContact = receivedContact;
        _isProcessing = false;
      });

      // Add to history
      await _addReceivedContactToHistory(contact);

      // Mark that user has received a card (this is correct usage)
      if (mounted) {
        final appState = context.read<AppState>();
        appState.markSharedOrReceived();
      }

      // Auto-navigate to contact detail after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _navigateToContactDetail();
        }
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  /// Get current location if tracking is enabled
  Future<String?> _getCurrentLocation() async {
    try {
      // Check if location tracking is enabled in settings
      final isEnabled = await NfcSettingsService.getLocationTrackingEnabled();
      if (!isEnabled) {
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('Location permission denied', name: 'Receive.Location');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permission denied forever', name: 'Receive.Location');
        return null;
      }

      // Get location with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      // Attempt reverse geocoding to get human-readable location
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Format: "City, State" or "City, Country"
          final locationParts = [
            place.locality,          // City
            place.administrativeArea // State/Province
          ].where((e) => e != null && e.isNotEmpty).toList();

          if (locationParts.isNotEmpty) {
            final location = locationParts.join(', ');
            developer.log('📍 Location: $location', name: 'Receive.Location');
            return location;
          }
        }

        developer.log('⚠️ Reverse geocoding returned no placemarks', name: 'Receive.Location');
      } catch (geocodeError) {
        developer.log('⚠️ Reverse geocoding failed, using coordinates',
          name: 'Receive.Location', error: geocodeError);
      }

      // Fallback to coordinates if reverse geocoding fails
      final location = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      developer.log('📍 Location (coordinates): $location', name: 'Receive.Location');
      return location;
    } catch (e) {
      developer.log('Failed to get location: $e', name: 'Receive.Location', error: e);
      return null;
    }
  }

  /// Add received contact to history
  Future<void> _addReceivedContactToHistory(ContactData contact) async {
    try {
      final location = await _getCurrentLocation();

      // Convert ContactData to ProfileData for history
      final senderProfile = ProfileData(
        id: ReceivedContact.generateId(),
        type: ProfileType.custom,
        name: contact.name,
        title: contact.title,
        company: contact.company,
        phone: contact.phone,
        email: contact.email,
        website: contact.website,
        socialMedia: contact.socialMedia,
        lastUpdated: DateTime.now(),
      );

      await HistoryService.addReceivedEntry(
        senderProfile: senderProfile,
        method: ShareMethod.nfc,
        location: location,
      );

      final locationStr = location != null ? ' at $location' : '';
      developer.log(
        '✅ NFC receive added to history: ${contact.name}$locationStr',
        name: 'Receive.History'
      );
    } catch (e) {
      developer.log(
        '❌ Error adding NFC receive to history: $e',
        name: 'Receive.History',
        error: e
      );
    }
  }

  void _navigateToContactDetail() {
    if (_receivedContact != null) {
      context.go(
        AppRoutes.contactDetail,
        extra: _receivedContact,
      );
    }
  }

  void _navigateToHome() {
    context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  const Spacer(flex: 2),

                  // Main content
                  Expanded(
                    flex: 6,
                    child: _buildContent(),
                  ),

                  // Actions
                  const Spacer(flex: 1),
                  _buildActions(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isProcessing) {
      return _buildProcessingState();
    } else if (_errorMessage != null) {
      return _buildErrorState();
    } else if (_receivedContact != null) {
      return _buildSuccessState();
    } else {
      return _buildErrorState();
    }
  }

  Widget _buildProcessingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCard(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // NFC icon with animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(seconds: 2),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryAction.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.antenna_radiowaves_left_right,
                          size: 40,
                          color: AppColors.primaryAction,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Processing NFC Data',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Reading contact information...',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                const CircularProgressIndicator(
                  color: AppColors.primaryAction,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCard(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 40,
                    color: AppColors.success,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Contact Received!',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Successfully received contact for:',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Contact preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMedium.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryAction.withOpacity(0.2),
                        child: Text(
                          _receivedContact!.contact.name.isNotEmpty
                              ? _receivedContact!.contact.name[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.primaryAction,
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _receivedContact!.contact.name,
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (_receivedContact!.contact.title != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _receivedContact!.contact.title!,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Opening contact details...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCard(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Error icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Unable to Process NFC Data',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  _errorMessage ?? 'An unknown error occurred',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (_isProcessing) {
      return const SizedBox(); // No actions while processing
    }

    if (_receivedContact != null) {
      return Row(
        children: [
          Expanded(
            child: AppButton.outlined(
              onPressed: _navigateToHome,
              text: 'Go to Home',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AppButton.contained(
              onPressed: _navigateToContactDetail,
              text: 'View Contact',
            ),
          ),
        ],
      );
    } else {
      // Error state
      return AppButton.contained(
        onPressed: _navigateToHome,
        text: 'Go to Home',
      );
    }
  }
}