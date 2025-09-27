import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class GlassmorphicDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String content;
  final List<DialogAction> actions;
  final bool isDangerous;

  const GlassmorphicDialog({
    Key? key,
    this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.isDangerous = false,
  }) : super(key: key);

  static Future<T?> show<T>({
    required BuildContext context,
    Widget? icon,
    required String title,
    required String content,
    required List<DialogAction> actions,
    bool isDangerous = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => GlassmorphicDialog(
        icon: icon,
        title: title,
        content: content,
        actions: actions,
        isDangerous: isDangerous,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(height: 16),
                  ],
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDangerous ? AppColors.error : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  if (actions.length == 1)
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(actions.first),
                    )
                  else if (actions.length == 2)
                    Row(
                      children: [
                        Expanded(child: _buildActionButton(actions[0])),
                        const SizedBox(width: 12),
                        Expanded(child: _buildActionButton(actions[1])),
                      ],
                    )
                  else
                    Column(
                      children: actions
                          .map((action) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: _buildActionButton(action),
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(DialogAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: action.isPrimary
                ? (action.isDestructive ? AppColors.error : AppColors.primaryAction)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: action.isPrimary
                  ? (action.isDestructive ? AppColors.error : AppColors.primaryAction)
                  : Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            action.text,
            style: AppTextStyles.body.copyWith(
              color: action.isPrimary
                  ? Colors.white
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class DialogAction {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const DialogAction({
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  factory DialogAction.primary({
    required String text,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return DialogAction(
      text: text,
      onPressed: onPressed,
      isPrimary: true,
      isDestructive: isDestructive,
    );
  }

  factory DialogAction.secondary({
    required String text,
    required VoidCallback onPressed,
  }) {
    return DialogAction(
      text: text,
      onPressed: onPressed,
      isPrimary: false,
    );
  }
}