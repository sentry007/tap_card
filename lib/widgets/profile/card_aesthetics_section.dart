import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/models/profile_models.dart';
import '../../theme/theme.dart';

/// Background mode enum for background picker dialog
enum BackgroundMode { solid, gradient }

/// Widget that builds the card template selector and aesthetics controls.
///
/// This widget manages card template selection with preset color combinations,
/// recent combinations history, border color picker, background color/gradient picker,
/// and background image selection.
///
/// Features:
/// - Horizontal scrollable chips for templates and pickers
/// - 4 preset color combinations (Professional, Creative, Minimal, Modern)
/// - Up to 3 recent color combinations
/// - Border color picker with color grid
/// - Background picker (solid color or gradient)
/// - Background image picker button
/// - Glassmorphic UI with blur effects
class CardAestheticsSection extends StatelessWidget {
  final CardAesthetics cardAesthetics;
  final List<Map<String, dynamic>> recentCombinations;
  final File? backgroundImage;
  final Function(CardAesthetics) onAestheticsChanged;
  final Function(Map<String, dynamic>) onAddRecentCombination;
  final VoidCallback onBackgroundImageTap;

  // Preset color combinations
  static final List<Map<String, dynamic>> presetCombinations = [
    {
      'name': 'Professional',
      'primary': AppColors.primaryAction,
      'secondary': AppColors.secondaryAction,
    },
    {
      'name': 'Creative',
      'primary': AppColors.highlight,
      'secondary': AppColors.primaryAction,
    },
    {
      'name': 'Minimal',
      'primary': AppColors.textPrimary,
      'secondary': AppColors.textSecondary,
    },
    {
      'name': 'Modern',
      'primary': const Color(0xFF6C63FF),
      'secondary': const Color(0xFF00BCD4),
    },
  ];

  const CardAestheticsSection({
    super.key,
    required this.cardAesthetics,
    required this.recentCombinations,
    required this.backgroundImage,
    required this.onAestheticsChanged,
    required this.onAddRecentCombination,
    required this.onBackgroundImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Card Template',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presetCombinations.length + recentCombinations.length + 3, // presets + recent + border + background + add bg
            itemBuilder: (context, index) {
              // Display order: 4 preset styles → up to 3 recent styles → custom pickers
              if (index < presetCombinations.length) {
                return _buildPresetCombination(context, index);
              } else if (index < presetCombinations.length + recentCombinations.length) {
                final recentIndex = index - presetCombinations.length;
                return _buildRecentCombination(context, recentIndex);
              } else if (index == presetCombinations.length + recentCombinations.length) {
                return _buildBorderColorPicker(context);
              } else if (index == presetCombinations.length + recentCombinations.length + 1) {
                return _buildBackgroundPicker(context);
              } else {
                return _buildAddBackgroundButton(context);
              }
            },
          ),
        ),
      ],
    );
  }

  /// Build preset color combination chip
  Widget _buildPresetCombination(BuildContext context, int index) {
    final preset = presetCombinations[index];
    final primaryColor = preset['primary'] as Color;
    final secondaryColor = preset['secondary'] as Color;
    final name = preset['name'] as String;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final updatedAesthetics = CardAesthetics(
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              borderColor: cardAesthetics.borderColor,
              backgroundColor: cardAesthetics.backgroundColor,
              blurLevel: cardAesthetics.blurLevel,
              backgroundImagePath: cardAesthetics.backgroundImagePath,
            );
            onAestheticsChanged(updatedAesthetics);

            // Add to recent combinations
            onAddRecentCombination({
              'primary': primaryColor,
              'secondary': secondaryColor,
              'background': null,
              'border': cardAesthetics.borderColor,
            });

            HapticFeedback.lightImpact();
          },
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
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

  /// Build recent color combination chip
  Widget _buildRecentCombination(BuildContext context, int index) {
    final combination = recentCombinations[index];
    final bgColor = combination['background'];
    final borderColor = combination['border']!;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final updatedAesthetics = CardAesthetics(
              primaryColor: cardAesthetics.primaryColor,
              secondaryColor: cardAesthetics.secondaryColor,
              borderColor: borderColor,
              backgroundColor: bgColor,
              blurLevel: cardAesthetics.blurLevel,
              backgroundImagePath: cardAesthetics.backgroundImagePath,
            );
            onAestheticsChanged(updatedAesthetics);
            HapticFeedback.lightImpact();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: bgColor != null
                ? LinearGradient(
                    colors: [bgColor, bgColor.withOpacity(0.8)],
                  )
                : LinearGradient(
                    colors: [
                      combination['primary'] ?? cardAesthetics.primaryColor,
                      combination['secondary'] ?? cardAesthetics.secondaryColor,
                    ],
                  ),
              borderRadius: BorderRadius.circular(12),
              border: borderColor != Colors.transparent
                ? Border.all(
                    color: borderColor,
                    width: 2,
                  )
                : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: bgColor ?? combination['primary'] ?? cardAesthetics.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                    border: borderColor != Colors.transparent
                      ? Border.all(
                          color: borderColor,
                          width: 2,
                        )
                      : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recent\n#${index + 1}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: (bgColor ?? combination['primary'] ?? cardAesthetics.primaryColor).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build border color picker button
  Widget _buildBorderColorPicker(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBorderColorPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cardAesthetics.borderColor.withOpacity(0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: cardAesthetics.borderColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.paintbrush,
                    color: cardAesthetics.borderColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Border\nColor',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cardAesthetics.borderColor,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build background color/gradient picker button
  Widget _buildBackgroundPicker(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUnifiedBackgroundPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: cardAesthetics.backgroundColor != null
                ? LinearGradient(colors: [cardAesthetics.backgroundColor!, cardAesthetics.backgroundColor!.withOpacity(0.8)])
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cardAesthetics.primaryColor, cardAesthetics.secondaryColor],
                  ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: cardAesthetics.backgroundColor != null
                      ? LinearGradient(colors: [cardAesthetics.backgroundColor!, cardAesthetics.backgroundColor!.withOpacity(0.8)])
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cardAesthetics.primaryColor, cardAesthetics.secondaryColor],
                        ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.paintbrush_fill,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Background',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build "Add Background Image" button
  Widget _buildAddBackgroundButton(BuildContext context) {
    final hasBackground = backgroundImage != null;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBackgroundImageTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasBackground
                    ? AppColors.primaryAction.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
                width: hasBackground ? 2 : 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAction.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    backgroundImage == null ? CupertinoIcons.photo_on_rectangle : CupertinoIcons.pencil,
                    color: AppColors.primaryAction,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Background\nImage',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryAction,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show border color picker dialog
  void _showBorderColorPicker(BuildContext context) {
    Color selectedColor = cardAesthetics.borderColor;

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
                    // Use HSV color picker for border
                    StatefulBuilder(
                      builder: (context, setState) {
                        return _buildBorderColorContent(context, selectedColor, (color) {
                          setState(() {
                            selectedColor = color;
                          });
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  final updatedAesthetics = cardAesthetics.copyWith(
                                    borderColor: selectedColor,
                                  );
                                  onAestheticsChanged(updatedAesthetics);
                                  Navigator.pop(context);
                                  HapticFeedback.lightImpact();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Apply',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
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

  /// Build border color picker content with flutter_colorpicker
  Widget _buildBorderColorContent(BuildContext context, Color selected, Function(Color) onColorSelected) {
    Color pickerColor = selected;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Box
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: pickerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pickerColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ColorPicker widget from flutter_colorpicker
            ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                setState(() {
                  pickerColor = color;
                });
                onColorSelected(color);
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
          ],
        );
      },
    );
  }

  /// Show unified background picker dialog (solid color or gradient)
  void _showUnifiedBackgroundPicker(BuildContext context) {
    BackgroundMode mode = cardAesthetics.backgroundColor != null
      ? BackgroundMode.solid
      : BackgroundMode.gradient;

    Color solidColor = cardAesthetics.backgroundColor ?? cardAesthetics.primaryColor;
    Color gradientStart = cardAesthetics.primaryColor;
    Color gradientEnd = cardAesthetics.secondaryColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 400),
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
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Background',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Toggle Switch
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      mode = BackgroundMode.solid;
                                    });
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: mode == BackgroundMode.solid
                                        ? AppColors.primaryGradient
                                        : null,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Solid',
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: mode == BackgroundMode.solid
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                          color: mode == BackgroundMode.solid
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      mode = BackgroundMode.gradient;
                                    });
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: mode == BackgroundMode.gradient
                                        ? AppColors.primaryGradient
                                        : null,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Gradient',
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: mode == BackgroundMode.gradient
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                          color: mode == BackgroundMode.gradient
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dynamic Content
                      if (mode == BackgroundMode.solid)
                        _buildSolidColorContent(
                          context,
                          solidColor,
                          (color) {
                            setDialogState(() {
                              solidColor = color;
                            });
                          },
                        )
                      else
                        _buildGradientColorContent(
                          context,
                          gradientStart,
                          gradientEnd,
                          (start, end) {
                            setDialogState(() {
                              gradientStart = start;
                              gradientEnd = end;
                            });
                          },
                        ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cancel',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (mode == BackgroundMode.solid) {
                                      final updatedAesthetics = cardAesthetics.copyWith(
                                        backgroundColor: solidColor,
                                      );
                                      onAestheticsChanged(updatedAesthetics);
                                    } else {
                                      final updatedAesthetics = CardAesthetics(
                                        primaryColor: gradientStart,
                                        secondaryColor: gradientEnd,
                                        borderColor: cardAesthetics.borderColor,
                                        backgroundColor: null, // Clear solid background
                                        blurLevel: cardAesthetics.blurLevel,
                                        backgroundImagePath: cardAesthetics.backgroundImagePath,
                                      );
                                      onAestheticsChanged(updatedAesthetics);
                                    }
                                    Navigator.pop(context);
                                    HapticFeedback.lightImpact();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Apply',
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
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
      ),
    );
  }

  /// Build solid color picker content with flutter_colorpicker
  Widget _buildSolidColorContent(BuildContext context, Color selected, Function(Color) onColorSelected) {
    Color pickerColor = selected;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Box
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: pickerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pickerColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ColorPicker widget from flutter_colorpicker
            ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                setState(() {
                  pickerColor = color;
                });
                onColorSelected(color);
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
          ],
        );
      },
    );
  }

  /// Build gradient color picker content with tabbed interface for two colors
  Widget _buildGradientColorContent(
    BuildContext context,
    Color startColor,
    Color endColor,
    Function(Color, Color) onColorsSelected,
  ) {
    Color currentStartColor = startColor;
    Color currentEndColor = endColor;
    int selectedTab = 0; // 0 = Start Color, 1 = End Color

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient Preview
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [currentStartColor, currentEndColor],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tab Selector - Color Tiles
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedTab = 0),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: currentStartColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedTab == 0
                              ? AppColors.primaryAction
                              : Colors.white.withOpacity(0.3),
                          width: selectedTab == 0 ? 3 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedTab = 1),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: currentEndColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedTab == 1
                              ? AppColors.primaryAction
                              : Colors.white.withOpacity(0.3),
                          width: selectedTab == 1 ? 3 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Color Picker (switches based on selected tab)
            ColorPicker(
              pickerColor: selectedTab == 0 ? currentStartColor : currentEndColor,
              onColorChanged: (color) {
                setState(() {
                  if (selectedTab == 0) {
                    currentStartColor = color;
                  } else {
                    currentEndColor = color;
                  }
                });
                onColorsSelected(currentStartColor, currentEndColor);
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
          ],
        );
      },
    );
  }
}
