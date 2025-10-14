/// QR Settings Screen
///
/// Configure QR code generation preferences
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:ui';

import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../services/qr_settings_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/profile_service.dart';

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
  int _colorMode = 0; // 0 = black/white, 1 = custom border
  Color _borderColor = AppColors.p2pSecondary; // Default deep purple
  bool _showInitials = false;
  String _initials = '';

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
    final borderColorValue = await QrSettingsService.getBorderColor();
    final showInitials = await QrSettingsService.getShowInitials();
    final initials = await QrSettingsService.getInitials();

    // Get user's name from ProfileService to extract initials
    final profileService = ProfileService();
    final activeProfile = profileService.activeProfile;
    String extractedInitials = '';
    if (activeProfile != null && activeProfile.name.isNotEmpty) {
      extractedInitials = QrSettingsService.extractInitials(activeProfile.name);
      // Save initials if not already set
      if (initials == null || initials.isEmpty) {
        await QrSettingsService.setInitials(extractedInitials);
      }
    }

    if (mounted) {
      setState(() {
        _qrSize = size;
        _errorCorrectionLevel = errorLevel;
        _includeLogo = logo;
        _colorMode = colorMode;
        _borderColor = borderColorValue != null ? Color(borderColorValue) : AppColors.p2pSecondary;
        _showInitials = showInitials;
        _initials = initials ?? extractedInitials;
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
                    // TODO: Implement initials feature
                    // Requires text-to-image rendering using custom painter
                    // For now, initials are saved but not displayed in QR codes
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
                  SizedBox(height: 1),
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
              child: _buildQrCodePreview(),
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
                    padding: EdgeInsets.all(AppSpacing.sm),
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
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          size == QrSize.medium ? '${size.label}' : size.label,
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
                          SizedBox(height: 2),
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
                          SizedBox(height: 2),
                          _buildRecommendedBadge(),
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
                            CupertinoIcons.color_filter,
                            color: _colorMode == 1
                                ? AppColors.primaryAction
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                          SizedBox(height: AppSpacing.xs),
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
              padding: EdgeInsets.all(AppSpacing.md),
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
                  SizedBox(height: AppSpacing.sm),
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
                          SizedBox(width: 12),
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
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap to change color',
                              style: AppTextStyles.body,
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showColorPickerDialog() {
    Color selectedColor = _borderColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
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
                              padding: EdgeInsets.symmetric(vertical: 12),
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
    if (_colorMode == 1) {
      // Custom border color mode (2-tone: color on eye shapes, black on data)
      return QrImageView(
        data: 'https://tapcard.app/share/preview',
        version: QrVersions.auto,
        size: _qrSize.pixels.toDouble(),
        backgroundColor: Colors.white,
        errorCorrectionLevel: _errorCorrectionLevel,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: _borderColor,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );
    } else {
      // Classic black and white
      return QrImageView(
        data: 'https://tapcard.app/share/preview',
        version: QrVersions.auto,
        size: _qrSize.pixels.toDouble(),
        backgroundColor: Colors.white,
        errorCorrectionLevel: _errorCorrectionLevel,
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
