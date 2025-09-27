import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/providers/app_state.dart';
import '../../core/constants/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.nfc_rounded,
      title: 'NFC Sharing',
      subtitle: 'Share contacts, photos, and files instantly with just a tap',
      description: 'Hold your phone near another NFC-enabled device to share content seamlessly.',
    ),
    OnboardingPage(
      icon: Icons.qr_code_rounded,
      title: 'QR Code Support',
      subtitle: 'Generate and scan QR codes for quick sharing',
      description: 'Create QR codes for your content or scan others to receive information instantly.',
    ),
    OnboardingPage(
      icon: Icons.history_rounded,
      title: 'Activity History',
      subtitle: 'Track all your sharing activities',
      description: 'Keep track of what you\'ve shared and received with detailed history logs.',
    ),
    OnboardingPage(
      icon: Icons.security_rounded,
      title: 'Secure & Private',
      subtitle: 'Your data stays safe with you',
      description: 'All sharing is direct between devices. No cloud storage, maximum privacy.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() {
    final appState = context.read<AppState>();
    appState.completeOnboarding();
    context.go(AppRoutes.home);
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.surfaceGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentPage > 0)
            GlassCard(
              padding: const EdgeInsets.all(8),
              margin: EdgeInsets.zero,
              borderRadius: 12,
              onTap: _previousPage,
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _skipOnboarding,
            child: Text(
              'Skip',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          // Icon
          GlassCard(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(24),
            borderRadius: 30,
            child: Icon(
              page.icon,
              size: 72,
              color: AppColors.primaryAction,
            ),
          ),
          const SizedBox(height: 40),
          // Title
          Text(
            page.title,
            style: AppTextStyles.h1.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.primaryAction,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            page.description,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Page Indicators
          Row(
            key: const Key('onboarding_page_indicators_row'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) {
              return AnimatedContainer(
                key: Key('onboarding_page_indicator_$index'),
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primaryAction
                      : AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          // Action Button
          SizedBox(
            width: double.infinity,
            child: AppButton.contained(
              text: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
              size: AppButtonSize.large,
              icon: Icon(
                _currentPage == _pages.length - 1
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
                size: 24,
              ),
              onPressed: _nextPage,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}