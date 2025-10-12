/// QR Settings Screen
///
/// Configure QR code generation preferences
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../services/qr_settings_service.dart';
import '../../core/constants/app_constants.dart';

class QrSettingsScreen extends StatefulWidget {
  const QrSettingsScreen({Key? key}) : super(key: key);

  @override
  State<QrSettingsScreen> createState() => _QrSettingsScreenState();
}

class _QrSettingsScreenState extends State<QrSettingsScreen> {
  // QR Settings
  QrSize _qrSize = QrSize.medium;
  int _errorCorrectionLevel = QrErrorCorrectLevel.M;
  bool _includeLogo = false;
  int _colorMode = 0; // 0 = black/white, 1 = colored

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await QrSettingsService.initialize();

    final size = await QrSettingsService.getQrSize();
    final errorLevel = await QrSettingsService.getErrorCorrectionLevel();
    final logo = await QrSettingsService.getIncludeLogo();
    final colorMode = await QrSettingsService.getColorMode();

    if (mounted) {
      setState(() {
        _qrSize = size;
        _errorCorrectionLevel = errorLevel;
        _includeLogo = logo;
        _colorMode = colorMode;
      });
    }
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
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildPreviewCard(),
                    SizedBox(height: AppSpacing.lg),
                    _buildQrSizeSettings(),
                    SizedBox(height: AppSpacing.lg),
                    _buildErrorCorrectionSettings(),
                    SizedBox(height: AppSpacing.lg),
                    _buildStyleSettings(),
                    SizedBox(height: AppSpacing.bottomNavHeight + AppSpacing.md),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(CupertinoIcons.back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceDark.withOpacity(0.8),
                  AppColors.surfaceDark.withOpacity(0.5),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.glassBorder.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                left: AppSpacing.md + 40,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              title: Text(
                'QR Code Settings',
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  CupertinoIcons.qrcode,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                'Preview',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowMedium.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _colorMode == 1
                  ? QrImageView(
                      data: 'https://tapcard.app/share/preview',
                      version: QrVersions.auto,
                      size: _qrSize.pixels.toDouble(),
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: _errorCorrectionLevel,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primaryAction,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.primaryAction,
                      ),
                    )
                  : QrImageView(
                      data: 'https://tapcard.app/share/preview',
                      version: QrVersions.auto,
                      size: _qrSize.pixels.toDouble(),
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: _errorCorrectionLevel,
                    ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '${_qrSize.pixels}×${_qrSize.pixels} pixels',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSizeSettings() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.highlight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    CupertinoIcons.fullscreen,
                    color: AppColors.highlight,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR Code Size',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Choose display size for QR codes',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.glassBorder, height: 1),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: QrSize.values.map((size) {
                final isSelected = _qrSize == size;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _qrSize = size);
                      QrSettingsService.setQrSize(size);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: size != QrSize.large ? AppSpacing.sm : 0,
                      ),
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryAction.withOpacity(0.2)
                            : AppColors.glassBorder.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryAction
                              : AppColors.glassBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.qrcode,
                            color: isSelected
                                ? AppColors.primaryAction
                                : AppColors.textSecondary,
                            size: size == QrSize.small
                                ? 20
                                : size == QrSize.medium
                                    ? 24
                                    : 28,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            size.label,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCorrectionSettings() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.highlight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    CupertinoIcons.shield_lefthalf_fill,
                    color: AppColors.highlight,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error Correction',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Higher levels work better if QR is damaged',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.glassBorder, height: 1),
          _buildErrorCorrectionOption('Low', 'Best scanning speed', QrErrorCorrectLevel.L),
          const Divider(color: AppColors.glassBorder, height: 1, indent: 60),
          _buildErrorCorrectionOption('Medium', 'Balanced (recommended)', QrErrorCorrectLevel.M),
          const Divider(color: AppColors.glassBorder, height: 1, indent: 60),
          _buildErrorCorrectionOption('Quartile', 'Better reliability', QrErrorCorrectLevel.Q),
          const Divider(color: AppColors.glassBorder, height: 1, indent: 60),
          _buildErrorCorrectionOption('High', 'Maximum reliability', QrErrorCorrectLevel.H),
        ],
      ),
    );
  }

  Widget _buildErrorCorrectionOption(String label, String description, int level) {
    final isSelected = _errorCorrectionLevel == level;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _errorCorrectionLevel = level);
          QrSettingsService.setErrorCorrectionLevel(level);
        },
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryAction
                        : AppColors.glassBorder,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryAction,
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryAction
                            : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSettings() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.highlight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    CupertinoIcons.paintbrush,
                    color: AppColors.highlight,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color Style',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Customize QR code appearance',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.glassBorder, height: 1),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _colorMode = 0);
                      QrSettingsService.setColorMode(0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _colorMode == 0
                            ? AppColors.primaryAction.withOpacity(0.2)
                            : AppColors.glassBorder.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: _colorMode == 0
                              ? AppColors.primaryAction
                              : AppColors.glassBorder,
                          width: _colorMode == 0 ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.circle_lefthalf_fill,
                            color: _colorMode == 0
                                ? AppColors.primaryAction
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Classic',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: _colorMode == 0
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                              fontWeight: _colorMode == 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _colorMode = 1);
                      QrSettingsService.setColorMode(1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _colorMode == 1
                            ? AppColors.primaryAction.withOpacity(0.2)
                            : AppColors.glassBorder.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: _colorMode == 1
                              ? AppColors.primaryAction
                              : AppColors.glassBorder,
                          width: _colorMode == 1 ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.paintbrush_fill,
                            color: _colorMode == 1
                                ? AppColors.primaryAction
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Colored',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: _colorMode == 1
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                              fontWeight: _colorMode == 1
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
