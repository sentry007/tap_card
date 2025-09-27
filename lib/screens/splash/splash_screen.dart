import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/providers/app_state.dart';
import '../../core/constants/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _cardController;
  late AnimationController _pulseController;
  late AnimationController _contentController;

  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _pulseScale;

  bool _isNfcLoading = false;
  bool _isQrLoading = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    // Card entrance animation
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Pulsing animation for NFC FAB
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Content animation
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    ));

    _cardOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _contentOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));

    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _cardController.forward();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _contentController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  void _onNfcTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _isNfcLoading = true);

    // Simulate NFC action
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      final appState = context.read<AppState>();
      appState.completeSplash();

      // For NFC usage from splash, trigger onboarding flow for first-time users
      if (!appState.hasCompletedOnboarding) {
        print('🎯 First NFC usage - showing onboarding');
        context.go(AppRoutes.onboarding);
      } else {
        print('🏠 Experienced user - going to home');
        context.go(AppRoutes.home);
      }
    }
  }

  void _onPhoneSignIn() async {
    HapticFeedback.lightImpact();
    // TODO: Implement phone sign in when backend is ready
    _navigateToApp();
  }

  void _onGoogleSignIn() async {
    HapticFeedback.lightImpact();
    // TODO: Implement Google sign in when backend is ready
    _navigateToApp();
  }

  void _onAppleSignIn() async {
    HapticFeedback.lightImpact();
    // TODO: Implement Apple sign in when backend is ready
    _navigateToApp();
  }

  void _onGuestContinue() async {
    HapticFeedback.lightImpact();
    // Continue as guest
    _navigateToApp();
  }

  void _navigateToApp() {
    if (mounted) {
      final appState = context.read<AppState>();
      // Skip onboarding for direct app access (sign-in methods)
      appState.skipToMainApp();
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    // Compute a responsive square card size that fits on small/short screens
    final availableHeight = screenSize.height - media.padding.vertical - 32;
    final availableWidth = screenSize.width - 32;
    final computed = availableHeight < availableWidth
        ? availableHeight
        : availableWidth;
    final cardSize = computed.clamp(320.0, 450.0);

    return Scaffold(
      key: const Key('splash_scaffold'),
      body: Container(
        key: const Key('splash_main_container'),
        width: double.infinity,
        height: double.infinity,
        color: AppColors.primaryBackground,
        child: Stack(
          key: const Key('splash_main_stack'),
          children: [
            // Background gradient overlay
            Container(
              key: const Key('splash_background_container'),
              width: double.infinity,
              height: double.infinity,
              child: ClipRRect(
                key: const Key('splash_background_clip'),
                child: BackdropFilter(
                  key: const Key('splash_background_backdrop'),
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    key: const Key('splash_background_gradient'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.secondaryAction.withOpacity(0.3),
                          AppColors.primaryAction.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              key: const Key('splash_safe_area'),
              child: Center(
                key: const Key('splash_center'),
                child: AnimatedBuilder(
                  key: const Key('splash_card_animated'),
                  animation: _cardController,
                  builder: (context, child) {
                    return Transform.scale(
                      key: const Key('splash_card_transform'),
                      scale: _cardScale.value,
                      child: Opacity(
                        key: const Key('splash_card_opacity'),
                        opacity: _cardOpacity.value,
                        child: _buildMainCard(cardSize),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(double cardSize) {
    // Make card taller to accommodate content
    final cardHeight = cardSize * 1.3; // 30% taller
    return Container(
      key: const Key('splash_main_card'),
      width: cardSize,
      height: cardHeight,
      child: ClipRRect(
        key: const Key('splash_main_card_clip'),
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          key: const Key('splash_main_card_backdrop'),
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            key: const Key('splash_main_card_container'),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.primaryAction.withOpacity(0.1),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Padding(
              key: const Key('splash_main_card_padding'),
              padding: EdgeInsets.all((cardSize * 0.05).clamp(12.0, 20.0)),
              child: AnimatedBuilder(
                key: const Key('splash_content_animated'),
                animation: _contentController,
                builder: (context, child) {
                  return SlideTransition(
                    key: const Key('splash_content_slide'),
                    position: _contentSlide,
                    child: FadeTransition(
                      key: const Key('splash_content_fade'),
                      opacity: _contentOpacity,
                      child: _buildCardContent(cardSize),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(double cardSize) {
    final titleSize = (cardSize * 0.070).clamp(18.0, 26.0);
    final spacingSmall = (cardSize * 0.025).clamp(4.0, 8.0);
    final spacingMedium = (cardSize * 0.045).clamp(10.0, 16.0);
    return Column(
      key: const Key('splash_content_column'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // App logo/icon
        Container(
          key: const Key('splash_app_icon'),
          width: (cardSize * 0.15).clamp(40.0, 56.0),
          height: (cardSize * 0.15).clamp(40.0, 56.0),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAction.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.nfc,
            color: AppColors.textPrimary,
            size: (cardSize * 0.08).clamp(20.0, 30.0),
          ),
        ),
        SizedBox(key: const Key('splash_icon_spacing'), height: spacingSmall),

        // Main headline
        Text(
          'Welcome to\nTap Card',
          key: const Key('splash_headline_text'),
          style: AppTextStyles.h1.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(key: const Key('splash_headline_spacing'), height: spacingSmall),

        // Subtitle
        Text(
          'Choose how you\'d like to continue',
          key: const Key('splash_subtitle_text'),
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: (cardSize * 0.040).clamp(11.0, 14.0),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(key: const Key('splash_subtitle_spacing'), height: spacingMedium),

        // Sign-in options
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSignInButton(
                key: 'phone',
                icon: Icons.phone,
                text: 'Continue with Phone',
                onTap: _onPhoneSignIn,
                cardSize: cardSize,
              ),
              SizedBox(height: (cardSize * 0.02).clamp(4.0, 8.0)),
              _buildSignInButton(
                key: 'google',
                icon: Icons.g_mobiledata,
                text: 'Continue with Google',
                onTap: _onGoogleSignIn,
                cardSize: cardSize,
              ),
              SizedBox(height: (cardSize * 0.02).clamp(4.0, 8.0)),
              _buildSignInButton(
                key: 'apple',
                icon: Icons.apple,
                text: 'Continue with Apple',
                onTap: _onAppleSignIn,
                cardSize: cardSize,
              ),
              SizedBox(height: (cardSize * 0.025).clamp(6.0, 10.0)),
              _buildGuestButton(cardSize),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton({
    required String key,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required double cardSize,
  }) {
    final height = (cardSize * 0.12).clamp(32.0, 48.0);
    final fontSize = (cardSize * 0.035).clamp(11.0, 14.0);
    final iconSize = (cardSize * 0.05).clamp(16.0, 20.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        key: Key('splash_signin_${key}_clip'),
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          key: Key('splash_signin_${key}_backdrop'),
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: Key('splash_signin_${key}_container'),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              key: Key('splash_signin_${key}_material'),
              color: Colors.transparent,
              child: InkWell(
                key: Key('splash_signin_${key}_inkwell'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    key: Key('splash_signin_${key}_row'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        key: Key('splash_signin_${key}_icon'),
                        color: AppColors.textPrimary,
                        size: iconSize,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        key: Key('splash_signin_${key}_text'),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton(double cardSize) {
    final height = (cardSize * 0.10).clamp(28.0, 40.0);
    final fontSize = (cardSize * 0.032).clamp(10.0, 13.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        key: const Key('splash_guest_material'),
        color: Colors.transparent,
        child: InkWell(
          key: const Key('splash_guest_inkwell'),
          onTap: _onGuestContinue,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            key: const Key('splash_guest_container'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'Continue as Guest',
                key: const Key('splash_guest_text'),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}