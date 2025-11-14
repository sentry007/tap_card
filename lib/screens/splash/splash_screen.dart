import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'dart:developer' as developer;

import '../../theme/theme.dart';
import '../../core/providers/app_state.dart';
import '../../core/constants/routes.dart';
import '../../core/services/auth_service.dart';
import '../../utils/logger.dart';
import '../../widgets/auth/google_sign_in_helper.dart';
import '../../widgets/auth/phone_auth_modal.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

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

    Logger.info('Phone Sign-In button tapped', name: 'SPLASH');

    if (!mounted) {
      Logger.warning('Widget not mounted - aborting', name: 'SPLASH');
      return;
    }

    try {
      Logger.info('Showing phone auth modal...', name: 'SPLASH');

      // Show custom phone auth modal
      final userCredential = await showPhoneAuthModal(context);

      Logger.debug('Phone auth modal returned: ${userCredential != null ? "UserCredential" : "null"}', name: 'SPLASH');

      if (userCredential != null) {
        Logger.info('Phone sign-in successful\n  Phone: ${userCredential.user?.phoneNumber}\n  UID: ${userCredential.user?.uid}\n  AppState auth listener will handle profile coordination\n  Router will handle navigation', name: 'SPLASH');

        // AppState will automatically call ensureProfilesExist() via auth listener
        // Navigation will be handled by router listening to auth state
      } else {
        Logger.info('Phone sign-in cancelled by user', name: 'SPLASH');
      }
    } catch (e, stackTrace) {
      Logger.error('Phone sign-in error: $e\n  Type: ${e.runtimeType}', name: 'SPLASH', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone sign-in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onGoogleSignIn() async {
    HapticFeedback.lightImpact();

    Logger.info('Google Sign-In button tapped', name: 'SPLASH');

    if (_isLoading) {
      Logger.warning('Already loading - ignoring tap', name: 'SPLASH');
      return;
    }

    setState(() => _isLoading = true);
    Logger.debug('Set loading state to true', name: 'SPLASH');

    try {
      Logger.info('Calling GoogleSignInHelper.signInWithGoogle()...', name: 'SPLASH');

      // Use custom Google Sign-In helper (no extra screens!)
      final userCredential = await GoogleSignInHelper.signInWithGoogle();

      Logger.debug('GoogleSignInHelper returned: ${userCredential != null ? "UserCredential" : "null"}', name: 'SPLASH');

      if (userCredential != null) {
        Logger.info('Google sign-in successful\n  Email: ${userCredential.user?.email}\n  UID: ${userCredential.user?.uid}\n  Display Name: ${userCredential.user?.displayName}\n  AppState auth listener will handle profile coordination\n  Router will handle navigation', name: 'SPLASH');

        // AppState will automatically call ensureProfilesExist() via auth listener
        // Navigation will be handled by router listening to auth state
      } else {
        Logger.info('Google sign-in returned null (user cancelled)', name: 'SPLASH');
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      Logger.error('Firebase Auth Exception: ${e.code}\n  Message: ${e.message}', name: 'SPLASH', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Unexpected error during Google sign-in: $e\n  Type: ${e.runtimeType}', name: 'SPLASH', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Logger.debug('Set loading state to false', name: 'SPLASH');
      } else {
        Logger.warning('Widget unmounted - cannot update loading state', name: 'SPLASH');
      }
    }
  }

  void _onAppleSignIn() async {
    HapticFeedback.lightImpact();

    // Apple Sign-In is disabled for now - show "Coming Soon" message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apple Sign-In coming soon!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onGuestContinue() async {
    HapticFeedback.lightImpact();

    Logger.info('Guest Continue button tapped', name: 'SPLASH');

    if (_isLoading) {
      Logger.warning('Already loading - ignoring tap', name: 'SPLASH');
      return;
    }

    setState(() => _isLoading = true);
    Logger.debug('Set loading state to true', name: 'SPLASH');

    try {
      final authService = AuthService();
      Logger.info('Calling authService.signInAnonymously()...', name: 'SPLASH');

      final user = await authService.signInAnonymously();

      if (user != null) {
        Logger.info('Guest sign-in successful\n  UID: ${user.uid}\n  Is Anonymous: ${user.isAnonymous}\n  AppState auth listener will handle profile coordination\n  Router will handle navigation', name: 'SPLASH');

        // AppState will automatically call ensureProfilesExist() via auth listener
        // Navigation will be handled by router listening to auth state
      } else {
        Logger.error('signInAnonymously returned null', name: 'SPLASH');
        throw Exception('Failed to sign in anonymously');
      }
    } catch (e, stackTrace) {
      Logger.error('Guest sign-in error: $e\n  Type: ${e.runtimeType}', name: 'SPLASH', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest sign-in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Logger.debug('Set loading state to false', name: 'SPLASH');
      } else {
        Logger.warning('Widget unmounted - cannot update loading state', name: 'SPLASH');
      }
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
            SizedBox(
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
                          AppColors.secondaryAction.withValues(alpha: 0.3),
                          AppColors.primaryAction.withValues(alpha: 0.3),
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

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    return SizedBox(
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
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.primaryAction.withValues(alpha: 0.1),
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
        SizedBox(
          key: const Key('splash_app_icon'),
          width: (cardSize * 0.25).clamp(80.0, 100.0),
          height: (cardSize * 0.25).clamp(80.0, 100.0),
          child: Image.asset(
            'assets/images/atlaslinq_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(key: const Key('splash_icon_spacing'), height: spacingSmall),

        // Main headline
        Text(
          'Welcome to\nAtlasLinq',
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
                isDisabled: false,
              ),
              SizedBox(height: (cardSize * 0.02).clamp(4.0, 8.0)),
              _buildSignInButton(
                key: 'google',
                icon: FontAwesomeIcons.google,
                text: 'Continue with Google',
                onTap: _onGoogleSignIn,
                cardSize: cardSize,
                isSolid: true,
                isDisabled: false,
              ),
              SizedBox(height: (cardSize * 0.02).clamp(4.0, 8.0)),
              _buildSignInButton(
                key: 'apple',
                icon: FontAwesomeIcons.apple,
                text: 'Continue with Apple',
                onTap: _onAppleSignIn,
                cardSize: cardSize,
                isSolid: true,
                isDisabled: true, // Apple is disabled for now
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
    bool isDisabled = false,
  }) {
    final height = (cardSize * 0.12).clamp(32.0, 48.0);
    final fontSize = (cardSize * 0.035).clamp(11.0, 14.0);
    final iconSize = (cardSize * 0.05).clamp(16.0, 20.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          key: Key('splash_signin_${key}_container'),
          decoration: BoxDecoration(
            color: isSolid ? Colors.white : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSolid ? Colors.white : Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSolid ? 0.15 : 0.05),
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
              onTap: isDisabled ? null : onTap,
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
                    if (isDisabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBackground.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Soon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize * 0.7,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
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
      child: ClipRRect(
        key: const Key('splash_guest_clip'),
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          key: const Key('splash_guest_backdrop'),
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            key: const Key('splash_guest_container'),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
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
