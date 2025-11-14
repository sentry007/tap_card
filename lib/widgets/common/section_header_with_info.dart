import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_info_button.dart';

/// Section header with optional info button
///
/// Displays a section title with an optional glassmorphic info button
/// that shows a tooltip/dialog with explanatory text when tapped.
///
/// Usage:
/// ```dart
/// SectionHeaderWithInfo(
///   title: 'Recent Connections',
///   infoText: 'People who have shared their digital cards with you.',
/// )
/// ```
class SectionHeaderWithInfo extends StatelessWidget {
  final String title;
  final String? infoText;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const SectionHeaderWithInfo({
    super.key,
    required this.title,
    this.infoText,
    this.style,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? AppTextStyles.h3.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: textStyle,
          ),
          if (infoText != null) ...[
            const SizedBox(width: 8),
            AppInfoButton(
              title: 'Information',
              description: infoText!,
            ),
          ],
        ],
      ),
    );
  }
}
