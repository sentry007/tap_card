/// Method Chip Widget
///
/// Displays a colored chip showing the sharing method (NFC/QR/Link/Tag)
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/theme.dart';
import '../../models/history_models.dart';

class MethodChip extends StatelessWidget {
  final ShareMethod method;
  final double fontSize;
  final double iconSize;

  const MethodChip({
    Key? key,
    required this.method,
    this.fontSize = 10,
    this.iconSize = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getMethodConfig(method);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: config['color'].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'],
            size: iconSize,
            color: config['color'],
          ),
          const SizedBox(width: 3),
          Text(
            config['label'],
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: config['color'],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getMethodConfig(ShareMethod method) {
    switch (method) {
      case ShareMethod.nfc:
        return {
          'icon': CupertinoIcons.antenna_radiowaves_left_right,
          'label': 'NFC',
          'color': AppColors.primaryAction,
        };
      case ShareMethod.qr:
        return {
          'icon': CupertinoIcons.qrcode,
          'label': 'QR',
          'color': AppColors.secondaryAction,
        };
      case ShareMethod.link:
        return {
          'icon': CupertinoIcons.link,
          'label': 'Link',
          'color': AppColors.highlight,
        };
      case ShareMethod.tag:
        return {
          'icon': CupertinoIcons.tag,
          'label': 'Tag',
          'color': AppColors.success,
        };
    }
  }
}
