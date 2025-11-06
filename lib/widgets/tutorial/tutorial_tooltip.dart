import 'package:flutter/material.dart';
import 'dart:ui';
import 'tutorial_steps.dart';

/// Compact tooltip with correct arrow direction
class TutorialTooltip extends StatefulWidget {
  final TutorialStep step;
  final VoidCallback? onDismiss;
  final bool arrowPointsUp; // TRUE = ▲ arrow points UP (tooltip below target)

  const TutorialTooltip({
    super.key,
    required this.step,
    this.onDismiss,
    required this.arrowPointsUp,
  });

  @override
  State<TutorialTooltip> createState() => _TutorialTooltipState();
}

class _TutorialTooltipState extends State<TutorialTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(
      begin: widget.arrowPointsUp ? 8 : -8,
      end: 0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TutorialTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arrow at top pointing UP
            if (widget.arrowPointsUp) _buildArrow(),

            // Tooltip body
            _buildTooltipBody(),

            // Arrow at bottom pointing DOWN
            if (!widget.arrowPointsUp) _buildArrow(),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow() {
    return CustomPaint(
      size: const Size(20, 10),
      painter: _ArrowPainter(pointsUp: widget.arrowPointsUp),
    );
  }

  Widget _buildTooltipBody() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200), // Compact
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.38), // Stronger
                  Colors.white.withValues(alpha: 0.28),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55), // Stronger
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(12), // Compact
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                // Description
                Text(
                  widget.step.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.94),
                  ),
                ),
                const SizedBox(height: 10),
                // Button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00D1FF),
                            Color(0xFF0099FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D1FF).withValues(alpha: 0.55),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Arrow painter
class _ArrowPainter extends CustomPainter {
  final bool pointsUp;

  _ArrowPainter({required this.pointsUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();

    if (pointsUp) {
      // ▲ Arrow pointing UP (tooltip below target)
      path.moveTo(size.width / 2, 0); // Top point
      path.lineTo(size.width, size.height); // Bottom right
      path.lineTo(0, size.height); // Bottom left
    } else {
      // ▼ Arrow pointing DOWN (tooltip above target)
      path.moveTo(0, 0); // Top left
      path.lineTo(size.width, 0); // Top right
      path.lineTo(size.width / 2, size.height); // Bottom point
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pulsing indicator on target
class PulsingIndicator extends StatefulWidget {
  final Offset position;

  const PulsingIndicator({super.key, required this.position});

  @override
  State<PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00D1FF)
                        .withValues(alpha: _opacityAnimation.value),
                    width: 2.5,
                  ),
                ),
              ),
            ),
            // Center dot
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D1FF),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D1FF).withValues(alpha: 0.7),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
