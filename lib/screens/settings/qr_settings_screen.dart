/// QR Settings Screen
///
/// Configure QR code generation preferences
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:ui' as ui;

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../services/qr_settings_service.dart';
import '../../core/constants/app_constants.dart';

class QrSettingsScreen extends StatefulWidget {
  final String userName;
  final String? profileImageUrl;

  const QrSettingsScreen({
    super.key,
    required this.userName,
    this.profileImageUrl,
  });

  @override
  State<QrSettingsScreen> createState() => _QrSettingsScreenState();
}

class _QrSettingsScreenState extends State<QrSettingsScreen> {
  // QR Settings
  QrSize _qrSize = QrSize.medium;
  int _errorCorrectionLevel = QrErrorCorrectLevel.M;
  bool _includeLogo = false; // Whether to show logo in QR
  QrLogoType _logoType = QrLogoType.atlasLogo; // Which logo type to use
  int _colorMode = 0; // 0 = black/white, 1 = custom border
  Color _borderColor = AppColors.p2pSecondary; // Default deep purple

  // Auto-extracted initials from userName
  String get _initials => QrSettingsService.extractInitials(widget.userName);

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
    final logoType = await QrSettingsService.getQrLogoType();
    final colorMode = await QrSettingsService.getColorMode();
    final borderColorValue = await QrSettingsService.getBorderColor();

    if (mounted) {
      setState(() {
        _qrSize = size;
        _errorCorrectionLevel = errorLevel;
        _includeLogo = logo;
        _logoType = logoType;
        _colorMode = colorMode;
        _borderColor = borderColorValue != null ? Color(borderColorValue) : AppColors.p2pSecondary;
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
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildPreviewCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildQrSizeSettings(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildErrorCorrectionSettings(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildStyleSettings(),
                    const SizedBox(height: AppSpacing.bottomNavHeight + AppSpacing.md),
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
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
              titlePadding: const EdgeInsets.only(
                left: AppSpacing.md + 40,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Settings',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Customize your QR code appearance',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
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

  Widget _buildPreviewCard() {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
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
              const SizedBox(width: AppSpacing.md),
              Text(
                'Preview',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
              child: _buildQrCodePreview(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
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
                const SizedBox(width: AppSpacing.md),
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
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: QrSize.values.map((size) {
                final isSelected = _qrSize == size;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _qrSize = size);
                    QrSettingsService.setQrSize(size);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    padding: const EdgeInsets.all(AppSpacing.sm),
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
                          size: 24,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          size == QrSize.medium ? size.label : size.label,
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
                        if (size == QrSize.medium) ...[
                          const SizedBox(height: 2),
                          _buildRecommendedBadge(),
                        ],
                      ],
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
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
                const SizedBox(width: AppSpacing.md),
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
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
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
          padding: const EdgeInsets.all(AppSpacing.md),
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryAction,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.caption.copyWith(
                        color: level == QrErrorCorrectLevel.M && !isSelected
                            ? AppColors.p2pSecondary
                            : AppColors.textSecondary,
                        fontWeight: level == QrErrorCorrectLevel.M
                            ? FontWeight.w500
                            : FontWeight.w400,
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
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
                const SizedBox(width: AppSpacing.md),
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
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
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
            padding: const EdgeInsets.all(AppSpacing.md),
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
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                          const SizedBox(height: AppSpacing.xs),
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
                          const SizedBox(height: 2),
                          _buildRecommendedBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _colorMode = 1);
                      QrSettingsService.setColorMode(1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                            CupertinoIcons.color_filter,
                            color: _colorMode == 1
                                ? AppColors.primaryAction
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Custom Border',
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
          if (_colorMode == 1) ...[
            const Divider(color: AppColors.glassBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Border Color',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: _showColorPickerDialog,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: _borderColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: _borderColor,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _borderColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _borderColor.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Tap to change color',
                              style: AppTextStyles.body,
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(color: AppColors.glassBorder, height: 1),
          _buildLogoToggle(),
          if (_includeLogo) ...[
            const Divider(color: AppColors.glassBorder, height: 1),
            _buildLogoTypeSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoToggle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _includeLogo = !_includeLogo);
          QrSettingsService.setIncludeLogo(_includeLogo);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _includeLogo
                      ? AppColors.primaryAction.withOpacity(0.1)
                      : AppColors.glassBorder.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.photo,
                  color: _includeLogo
                      ? AppColors.primaryAction
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show Logo in QR Code',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Display overlay in center of QR code',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _includeLogo,
                activeTrackColor: AppColors.primaryAction,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _includeLogo = value);
                  QrSettingsService.setIncludeLogo(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoTypeSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Logo Type',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildLogoTypeOption(QrLogoType.atlasLogo),
          const Divider(color: AppColors.glassBorder, height: 1, indent: 40),
          _buildLogoTypeOption(QrLogoType.initials),
          const Divider(color: AppColors.glassBorder, height: 1, indent: 40),
          _buildLogoTypeOption(QrLogoType.profileImage),
        ],
      ),
    );
  }

  Widget _buildLogoTypeOption(QrLogoType type) {
    final isSelected = _logoType == type;

    IconData icon;
    switch (type) {
      case QrLogoType.atlasLogo:
        icon = CupertinoIcons.sparkles;
        break;
      case QrLogoType.initials:
        icon = CupertinoIcons.textformat;
        break;
      case QrLogoType.profileImage:
        icon = CupertinoIcons.person_crop_circle;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _logoType = type);
          QrSettingsService.setQrLogoType(type);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryAction,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.primaryAction
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  type.label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.primaryAction
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPickerDialog() {
    Color selectedColor = _borderColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Border Color',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ColorPicker(
                        pickerColor: selectedColor,
                        onColorChanged: (color) {
                          selectedColor = color;
                        },
                        colorPickerWidth: 250,
                        pickerAreaHeightPercent: 0.7,
                        enableAlpha: false,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithHue,
                        labelTypes: const [],
                        pickerAreaBorderRadius: BorderRadius.circular(12),
                        hexInputBar: false,
                        portraitOnly: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _borderColor = selectedColor);
                              QrSettingsService.setBorderColor(selectedColor.value);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAction,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Select',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodePreview() {
    return SizedBox(
      width: _qrSize.pixels.toDouble(),
      height: _qrSize.pixels.toDouble(),
      child: PrettyQrView.data(
        data: 'https://tapcard.app/share/preview',
        errorCorrectLevel: _errorCorrectionLevel,
        decoration: PrettyQrDecoration(
          shape: _colorMode == 1
              ? PrettyQrSmoothSymbol(
                  color: _borderColor,
                )
              : const PrettyQrSmoothSymbol(
                  color: Colors.black,
                ),
          image: _includeLogo ? _buildPreviewLogoImage() : null,
        ),
      ),
    );
  }

  /// Build logo image for preview based on selected type
  PrettyQrDecorationImage? _buildPreviewLogoImage() {
    switch (_logoType) {
      case QrLogoType.atlasLogo:
        return const PrettyQrDecorationImage(
          image: AssetImage('assets/images/atlaslinq_logo_white.png'),
        );

      case QrLogoType.initials:
        if (_initials.isEmpty) {
          // Fallback to Atlas logo if no initials
          return const PrettyQrDecorationImage(
            image: AssetImage('assets/images/atlaslinq_logo_white.png'),
          );
        }
        // Use custom image provider to render initials
        return PrettyQrDecorationImage(
          image: _InitialsImageProvider(_initials),
        );

      case QrLogoType.profileImage:
        if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
          return PrettyQrDecorationImage(
            image: NetworkImage(widget.profileImageUrl!),
          );
        }
        // Fallback to Atlas logo if no profile image
        return const PrettyQrDecorationImage(
          image: AssetImage('assets/images/atlaslinq_logo_white.png'),
        );
    }
  }

  Widget _buildRecommendedBadge() {
    return Text(
      'Recommended',
      style: AppTextStyles.caption.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: AppColors.p2pSecondary,
      ),
    );
  }
}

/// Custom ImageProvider for rendering initials as a circular image
class _InitialsImageProvider extends ImageProvider<_InitialsImageProvider> {
  final String initials;

  const _InitialsImageProvider(this.initials);

  @override
  Future<_InitialsImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_InitialsImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_InitialsImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync(key));
  }

  Future<ImageInfo> _loadAsync(_InitialsImageProvider key) async {
    const size = 200.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw simple initials text (no circular background)
    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          color: Colors.black,
          fontSize: size * 0.6,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    return ImageInfo(image: img);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _InitialsImageProvider && other.initials == initials;
  }

  @override
  int get hashCode => initials.hashCode;
}
