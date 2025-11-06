import 'package:flutter/material.dart';

/// Creates a subtle dim overlay behind tutorial tooltips
/// Much simpler than the complex spotlight effect - just slightly darkens the background
class TutorialSpotlight extends StatefulWidget {
  final Widget child;
  final Color backdropColor;

  const TutorialSpotlight({
    super.key,
    required this.child,
    this.backdropColor = const Color(0x59000000), // 35% opacity black
  });

  @override
  State<TutorialSpotlight> createState() => _TutorialSpotlightState();
}

class _TutorialSpotlightState extends State<TutorialSpotlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Simple dim backdrop
        FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: widget.backdropColor,
          ),
        ),
        // Tooltip content
        widget.child,
      ],
    );
  }
}
