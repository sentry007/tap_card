import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

import '../../theme/theme.dart';

/// Reusable glassmorphic text field widget for profile forms
///
/// Features:
/// - Glassmorphic background with blur effect
/// - Dynamic focus states with accent color
/// - Optional clear button
/// - Prefix text support (e.g., for phone numbers)
/// - Smooth animations
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final String label;
  final IconData icon;
  final String? prefix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Color? accentColor;
  final bool showClearButton;
  final VoidCallback? onChanged;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.nextFocusNode,
    required this.label,
    required this.icon,
    this.prefix,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.accentColor,
    this.showClearButton = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? AppColors.primaryAction;

    return ValueListenableBuilder<bool>(
      valueListenable: _FocusNotifier(focusNode),
      builder: (context, hasFocus, child) {
        final hasContent = controller.text.isNotEmpty;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFocus
                      ? effectiveAccentColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                textInputAction: textInputAction ?? TextInputAction.next,
                validator: validator,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: AppTextStyles.body.copyWith(
                    color: hasFocus ? effectiveAccentColor : AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    icon,
                    color: hasFocus ? effectiveAccentColor : AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: showClearButton && hasContent
                      ? IconButton(
                          icon: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            controller.clear();
                            focusNode.unfocus();
                            onChanged?.call();
                          },
                        )
                      : null,
                  prefixText: prefix,
                  prefixStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  errorBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onFieldSubmitted: (value) {
                  if (nextFocusNode != null) {
                    nextFocusNode!.requestFocus();
                  } else {
                    focusNode.unfocus();
                  }
                },
                onChanged: (value) => onChanged?.call(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Focus notifier for reactive UI updates
class _FocusNotifier extends ValueNotifier<bool> {
  final FocusNode _focusNode;

  _FocusNotifier(this._focusNode) : super(_focusNode.hasFocus) {
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    value = _focusNode.hasFocus;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }
}

/// Validator functions for common form fields
class FormValidators {
  /// Validate name field (required)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  /// Validate email field (optional but must be valid if provided)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Invalid email address';
    }

    return null;
  }

  /// Validate phone number (optional but must be valid if provided)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    // Remove common phone formatting characters
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it's a valid phone number (at least 10 digits)
    if (cleanPhone.length < 10) {
      return 'Invalid phone number';
    }

    return null;
  }

  /// Validate URL (optional but must be valid if provided)
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );

    if (!urlRegex.hasMatch(value.trim())) {
      return 'Invalid URL';
    }

    return null;
  }
}
