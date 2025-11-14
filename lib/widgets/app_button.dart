import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final Widget? icon;
  final bool enabled;
  final bool loading;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.contained,
    this.size = AppButtonSize.medium,
    this.icon,
    this.enabled = true,
    this.loading = false,
    this.width,
    this.margin,
  });

  const AppButton.contained({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.enabled = true,
    this.loading = false,
    this.width,
    this.margin,
  }) : type = AppButtonType.contained;

  const AppButton.outlined({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.enabled = true,
    this.loading = false,
    this.width,
    this.margin,
  }) : type = AppButtonType.outlined;

  const AppButton.text({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.enabled = true,
    this.loading = false,
    this.width,
    this.margin,
  }) : type = AppButtonType.text;

  const AppButton.glass({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.enabled = true,
    this.loading = false,
    this.width,
    this.margin,
  }) : type = AppButtonType.glass;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled && !widget.loading) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonConfig = _getButtonConfig();
    final isEnabled = widget.enabled && !widget.loading;

    Widget buttonContent = Row(
      key: const Key('app_button_content_row'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            key: const Key('app_button_loading_container'),
            width: buttonConfig.iconSize,
            height: buttonConfig.iconSize,
            child: CircularProgressIndicator(
              key: const Key('app_button_loading_indicator'),
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                buttonConfig.textColor.withValues(alpha: 0.8),
              ),
            ),
          )
        else ...[
          Text(
            widget.text,
            key: const Key('app_button_text'),
            style: buttonConfig.textStyle.copyWith(
              color: isEnabled
                  ? buttonConfig.textColor
                  : buttonConfig.textColor.withValues(alpha: 0.5),
            ),
          ),
          if (widget.icon != null) ...[
            SizedBox(key: const Key('app_button_icon_spacing'), width: buttonConfig.spacing),
            SizedBox(
              key: const Key('app_button_icon_container'),
              width: buttonConfig.iconSize,
              height: buttonConfig.iconSize,
              child: widget.icon,
            ),
          ],
        ],
      ],
    );

    Widget button = Container(
      key: const Key('app_button_container'),
      width: widget.width,
      height: buttonConfig.height,
      margin: widget.margin,
      child: widget.type == AppButtonType.glass
          ? _buildGlassButton(buttonContent, buttonConfig, isEnabled)
          : _buildRegularButton(buttonContent, buttonConfig, isEnabled),
    );

    return AnimatedBuilder(
      key: const Key('app_button_animated_builder'),
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          key: const Key('app_button_transform'),
          scale: _scaleAnimation.value,
          child: button,
        );
      },
    );
  }

  Widget _buildGlassButton(
      Widget content, _ButtonConfig config, bool isEnabled) {
    return GlassCard(
      key: const Key('app_button_glass_card'),
      padding: config.padding,
      margin: EdgeInsets.zero,
      borderRadius: config.borderRadius,
      blur: 12,
      opacity: 0.1,
      borderColor: config.borderColor,
      borderWidth: 1.5,
      onTap: isEnabled ? widget.onPressed : null,
      enabled: isEnabled,
      child: content,
    );
  }

  Widget _buildRegularButton(
      Widget content, _ButtonConfig config, bool isEnabled) {
    return GestureDetector(
      key: const Key('app_button_gesture_detector'),
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isEnabled ? widget.onPressed : null,
      child: Container(
        key: const Key('app_button_regular_container'),
        padding: config.padding,
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(config.borderRadius),
          border: config.borderColor != null
              ? Border.all(color: config.borderColor!, width: 1.5)
              : null,
          boxShadow: widget.type == AppButtonType.contained && isEnabled
              ? [
                  BoxShadow(
                    color: config.backgroundColor!.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  const BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
          gradient: widget.type == AppButtonType.contained
              ? LinearGradient(
                  colors: [
                    config.backgroundColor!,
                    config.backgroundColor!.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
        ),
        child: content,
      ),
    );
  }

  _ButtonConfig _getButtonConfig() {
    switch (widget.size) {
      case AppButtonSize.small:
        return _getSmallButtonConfig();
      case AppButtonSize.medium:
        return _getMediumButtonConfig();
      case AppButtonSize.large:
        return _getLargeButtonConfig();
    }
  }

  _ButtonConfig _getSmallButtonConfig() {
    switch (widget.type) {
      case AppButtonType.contained:
        return _ButtonConfig(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.buttonSmall,
          textColor: AppColors.textPrimary,
          backgroundColor: AppColors.primaryAction,
          borderRadius: 8,
          iconSize: 16,
          spacing: 6,
        );
      case AppButtonType.outlined:
        return _ButtonConfig(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.buttonSmall,
          textColor: AppColors.primaryAction,
          backgroundColor: Colors.transparent,
          borderColor: AppColors.primaryAction,
          borderRadius: 8,
          iconSize: 16,
          spacing: 6,
        );
      case AppButtonType.text:
        return _ButtonConfig(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: AppTextStyles.buttonSmall,
          textColor: AppColors.primaryAction,
          backgroundColor: Colors.transparent,
          borderRadius: 8,
          iconSize: 16,
          spacing: 6,
        );
      case AppButtonType.glass:
        return _ButtonConfig(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.buttonSmall,
          textColor: AppColors.textPrimary,
          backgroundColor: Colors.transparent,
          borderColor: AppColors.glassBorder,
          borderRadius: 8,
          iconSize: 16,
          spacing: 6,
        );
    }
  }

  _ButtonConfig _getMediumButtonConfig() {
    switch (widget.type) {
      case AppButtonType.contained:
        return _ButtonConfig(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTextStyles.buttonMedium,
          textColor: AppColors.textPrimary,
          backgroundColor: AppColors.primaryAction,
          borderRadius: 12,
          iconSize: 20,
          spacing: 8,
        );
      case AppButtonType.outlined:
        return _ButtonConfig(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTextStyles.buttonMedium,
          textColor: AppColors.primaryAction,
          backgroundColor: Colors.transparent,
          borderColor: AppColors.primaryAction,
          borderRadius: 12,
          iconSize: 20,
          spacing: 8,
        );
      case AppButtonType.text:
        return _ButtonConfig(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTextStyles.buttonMedium,
          textColor: AppColors.primaryAction,
          backgroundColor: Colors.transparent,
          borderRadius: 12,
          iconSize: 20,
          spacing: 8,
        );
      case AppButtonType.glass:
        return _ButtonConfig(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTextStyles.buttonMedium,
          textColor: AppColors.textPrimary,
          backgroundColor: Colors.transparent,
          borderColor: AppColors.glassBorder,
          borderRadius: 12,
          iconSize: 20,
          spacing: 8,
        );
    }
  }

  _ButtonConfig _getLargeButtonConfig() {
    switch (widget.type) {
      case AppButtonType.contained:
        return _ButtonConfig(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: AppTextStyles.buttonLarge,
          textColor: AppColors.textPrimary,
          backgroundColor: AppColors.primaryAction,
          borderRadius: 16,
          iconSize: 24,
          spacing: 10,
        );
      case AppButtonType.outlined:
        return _ButtonConfig(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: AppTextStyles.buttonLarge,
          textColor: AppColors.primaryAction,
          backgroundColor: Colors.transparent,
          borderColor: AppColors.primaryAction,
          borderRadius: 16,
          iconSize: 24,
          spacing: 10,
        );
      case AppButtonType.text:
        return _ButtonConfig(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: AppTextStyles.buttonLarge,
          textColor: AppColors.primaryAction,
          backgroundColor: Colors.transparent,
          borderRadius: 16,
          iconSize: 24,
          spacing: 10,
        );
      case AppButtonType.glass:
        return _ButtonConfig(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: AppTextStyles.buttonLarge,
          textColor: AppColors.textPrimary,
          backgroundColor: Colors.transparent,
          borderColor: AppColors.glassBorder,
          borderRadius: 16,
          iconSize: 24,
          spacing: 10,
        );
    }
  }
}

class _ButtonConfig {
  final double height;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final Color textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double iconSize;
  final double spacing;

  _ButtonConfig({
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.textColor,
    this.backgroundColor,
    this.borderColor,
    required this.borderRadius,
    required this.iconSize,
    required this.spacing,
  });
}

enum AppButtonType {
  contained,
  outlined,
  text,
  glass,
}

enum AppButtonSize {
  small,
  medium,
  large,
}