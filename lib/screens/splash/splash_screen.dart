import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../core/providers/app_state.dart';
import '../../core/constants/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    // Simple fade-in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
  }


  void _onPhoneSignIn() async {
    HapticFeedback.lightImpact();
    // TODO: Implement phone sign in when backend is ready
    _navigateToAppSkipOnboarding();
  }

  void _onGoogleSignIn() async {
    HapticFeedback.lightImpact();
    // TODO: Implement Google sign in when backend is ready
    _navigateToAppSkipOnboarding();
  }

  void _onAppleSignIn() async {
    HapticFeedback.lightImpact();
    // TODO: Implement Apple sign in when backend is ready
    _navigateToAppSkipOnboarding();
  }

  void _onGuestContinue() async {
    HapticFeedback.lightImpact();
    // Guest users always see onboarding
    _navigateToOnboarding();
  }

  /// Navigate to app for authenticated users (skip onboarding after first login)
  void _navigateToAppSkipOnboarding() {
    if (mounted) {
      final appState = context.read<AppState>();
      // Skip onboarding for authenticated users
      appState.skipToMainApp();
      context.go(AppRoutes.home);
    }
  }

  /// Navigate to onboarding for guest users (show every time)
  void _navigateToOnboarding() {
    if (mounted) {
      final appState = context.read<AppState>();
      // Complete splash but don't mark onboarding as complete
      appState.completeSplashForGuest();
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
                child: FadeTransition(
                  key: const Key('splash_fade'),
                  opacity: _fadeAnimation,
                  child: _buildMainCard(cardSize),
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
              child: _buildCardContent(cardSize),
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
            CupertinoIcons.antenna_radiowaves_left_right,
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
                icon: CupertinoIcons.phone,
                text: 'Continue with Phone',
                onTap: _onPhoneSignIn,
                cardSize: cardSize,
                isSolid: true,
              ),
              SizedBox(height: (cardSize * 0.02).clamp(4.0, 8.0)),
              _buildSignInButton(
                key: 'google',
                icon: FontAwesomeIcons.google,
                text: 'Continue with Google',
                onTap: _onGoogleSignIn,
                cardSize: cardSize,
                isSolid: true,
              ),
              SizedBox(height: (cardSize * 0.02).clamp(4.0, 8.0)),
              _buildSignInButton(
                key: 'apple',
                icon: FontAwesomeIcons.apple,
                text: 'Continue with Apple',
                onTap: _onAppleSignIn,
                cardSize: cardSize,
                isSolid: true,
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
    bool isSolid = false,
  }) {
    final height = (cardSize * 0.12).clamp(32.0, 48.0);
    final fontSize = (cardSize * 0.035).clamp(11.0, 14.0);
    final iconSize = (cardSize * 0.05).clamp(16.0, 20.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Container(
        key: Key('splash_signin_${key}_container'),
        decoration: BoxDecoration(
          color: isSolid ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSolid ? Colors.white : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSolid ? 0.15 : 0.05),
              blurRadius: isSolid ? 12 : 8,
              offset: Offset(0, isSolid ? 4 : 2),
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
                    color: isSolid ? AppColors.primaryBackground : AppColors.textPrimary,
                    size: iconSize,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    key: Key('splash_signin_${key}_text'),
                    style: AppTextStyles.body.copyWith(
                      color: isSolid ? AppColors.primaryBackground : AppColors.textPrimary,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
      child: ClipRRect(
        key: const Key('splash_guest_clip'),
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          key: const Key('splash_guest_backdrop'),
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: const Key('splash_guest_container'),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Material(
              key: const Key('splash_guest_material'),
              color: Colors.transparent,
              child: InkWell(
                key: const Key('splash_guest_inkwell'),
                onTap: _onGuestContinue,
                borderRadius: BorderRadius.circular(12),
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
        ),
      ),
    );
  }
}