import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../services/tutorial_service.dart';
import '../../utils/responsive_helper.dart';
import 'tutorial_steps.dart';
import 'tutorial_spotlight.dart';
import 'tutorial_tooltip.dart';

/// Main tutorial overlay with correct positioning
class TutorialOverlay extends StatefulWidget {
  final Widget child;
  final bool showTutorial;
  final VoidCallback? onTutorialComplete;

  const TutorialOverlay({
    super.key,
    required this.child,
    this.showTutorial = false,
    this.onTutorialComplete,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();

  static void show(BuildContext context) {
    final state = context.findAncestorStateOfType<_TutorialOverlayState>();
    state?._startTutorial();
  }

  static void hide(BuildContext context) {
    final state = context.findAncestorStateOfType<_TutorialOverlayState>();
    state?._closeTutorial();
  }
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  bool _showingTutorial = false;
  int _currentStepIndex = 0;
  List<TutorialStep> _steps = [];
  OverlayEntry? _indicatorOverlayEntry; // For rendering pulsing indicator above everything
  OverlayEntry? _tutorialOverlayEntry; // For rendering tutorial UI in root overlay

  @override
  void initState() {
    super.initState();
    _steps = TutorialSteps.getAllSteps();

    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTutorial();
      });
    }
  }

  void _startTutorial() async {
    developer.log('🎓 Starting tutorial', name: 'TutorialOverlay');
    final savedStep = await TutorialService.getCurrentStep();
    setState(() {
      _showingTutorial = true;
      _currentStepIndex = savedStep;
    });
    _showIndicatorOverlay(); // Show pulsing indicator in root overlay
    _showTutorialInRootOverlay(); // Show tutorial UI in root overlay
  }

  void _closeTutorial() async {
    developer.log('❌ Closing tutorial', name: 'TutorialOverlay');
    _removeIndicatorOverlay(); // Remove pulsing indicator overlay
    _removeTutorialOverlay(); // Remove tutorial UI overlay
    setState(() {
      _showingTutorial = false;
    });
    widget.onTutorialComplete?.call();
  }

  @override
  void dispose() {
    _removeIndicatorOverlay();
    _removeTutorialOverlay();
    super.dispose();
  }

  /// Show pulsing indicator in root overlay (above all Scaffold elements)
  void _showIndicatorOverlay() {
    _removeIndicatorOverlay(); // Remove any existing overlay first

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final currentStep = _steps[_currentStepIndex];
      final targetKey = currentStep.targetKey;

      if (targetKey?.currentContext == null) {
        developer.log('⚠️  Target not found for indicator: ${currentStep.id}', name: 'TutorialOverlay');
        return;
      }

      final renderBox = targetKey!.currentContext!.findRenderObject() as RenderBox;
      final targetSize = renderBox.size;
      final targetPosition = renderBox.localToGlobal(Offset.zero);

      final targetCenter = Offset(
        targetPosition.dx + targetSize.width / 2,
        targetPosition.dy + targetSize.height / 2,
      );

      _indicatorOverlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: targetCenter.dx - 10, // Center the 20px indicator
          top: targetCenter.dy - 10,
          child: PulsingIndicator(position: targetCenter),
        ),
      );

      Overlay.of(context).insert(_indicatorOverlayEntry!);
    });
  }

  /// Remove pulsing indicator from root overlay
  void _removeIndicatorOverlay() {
    _indicatorOverlayEntry?.remove();
    _indicatorOverlayEntry = null;
  }

  /// Show tutorial UI in root overlay (above everything including nav bar)
  void _showTutorialInRootOverlay() {
    _removeTutorialOverlay(); // Remove any existing

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _tutorialOverlayEntry = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: TutorialSpotlight(
            child: _buildTooltipPositioned(_steps[_currentStepIndex]),
          ),
        ),
      );

      // Insert into ROOT overlay (above everything including nav bar)
      Overlay.of(context, rootOverlay: true).insert(_tutorialOverlayEntry!);
    });
  }

  /// Remove tutorial UI from root overlay
  void _removeTutorialOverlay() {
    _tutorialOverlayEntry?.remove();
    _tutorialOverlayEntry = null;
  }

  void _nextStep() async {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      await TutorialService.saveCurrentStep(_currentStepIndex);
      developer.log('➡️  Step $_currentStepIndex', name: 'TutorialOverlay');
      _showIndicatorOverlay(); // Update indicator position for new step
      _showTutorialInRootOverlay(); // Update tutorial UI for new step
    } else {
      _completeTutorial();
    }
  }

  void _completeTutorial() async {
    developer.log('✅ Tutorial completed!', name: 'TutorialOverlay');
    await TutorialService.markTutorialCompleted();
    _closeTutorial();
  }

  @override
  Widget build(BuildContext context) {
    // Tutorial UI is now rendered in root overlay, not in this widget tree
    return widget.child;
  }

  Widget _buildTooltipPositioned(TutorialStep step) {
    final targetKey = step.targetKey;
    if (targetKey?.currentContext == null) {
      developer.log('⚠️  Target not found: ${step.id}', name: 'TutorialOverlay');
      return Center(
        child: TutorialTooltip(
          step: step,
          onDismiss: _nextStep,
          arrowPointsUp: false,
        ),
      );
    }

    final renderBox = targetKey!.currentContext!.findRenderObject() as RenderBox;
    final targetSize = renderBox.size;
    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    developer.log(
      '📍 ${step.id}: pos(${targetPosition.dx.toInt()},${targetPosition.dy.toInt()}) '
      'size(${targetSize.width.toInt()}x${targetSize.height.toInt()})',
      name: 'Tutorial',
    );

    // Get positioning based on step ID
    final pos = _getPositioning(step.id, targetPosition, targetSize, screenSize);

    // Tooltip only - pulsing indicator is now rendered in root overlay for proper z-index
    return Positioned(
      left: pos.left,
      right: pos.right,
      top: pos.top,
      bottom: pos.bottom,
      child: TutorialTooltip(
        step: step,
        onDismiss: _nextStep,
        arrowPointsUp: pos.arrowPointsUp,
      ),
    );
  }

  _TooltipPos _getPositioning(String stepId, Offset targetPos, Size targetSize, Size screenSize) {
    // Responsive side padding (20-28px based on screen)
    final sidePadding = ResponsiveHelper.spacing(context, 20.0);

    // Responsive gap from target (20-32px based on screen)
    final minGapFromTarget = ResponsiveHelper.spacing(context, 24.0);

    // Safe area insets
    final safeAreaTop = MediaQuery.of(context).padding.top + 12; // +12px buffer
    const navBarHeight = 80.0; // Bottom nav bar height
    final safeAreaBottom = MediaQuery.of(context).padding.bottom + navBarHeight + 16; // +16px buffer

    // Calculate target center and screen center
    final targetCenterY = targetPos.dy + (targetSize.height / 2);
    final screenCenterY = screenSize.height / 2;

    // Smart positioning: if target in top half → tooltip BELOW, else → tooltip ABOVE
    final isTargetInTopHalf = targetCenterY < screenCenterY;

    if (isTargetInTopHalf) {
      // Tooltip BELOW target (arrow points UP ▲)
      // Ensure tooltip has space and doesn't go off bottom
      final topPos = targetPos.dy + targetSize.height + minGapFromTarget;
      final maxBottom = screenSize.height - safeAreaBottom;

      return _TooltipPos(
        left: sidePadding,
        right: sidePadding,
        top: topPos.clamp(safeAreaTop, maxBottom - 200), // Min 200px for tooltip height
        arrowPointsUp: true,
      );
    } else {
      // Tooltip ABOVE target (arrow points DOWN ▼)
      // Ensure tooltip has space and doesn't go into status bar
      final bottomPos = screenSize.height - targetPos.dy + minGapFromTarget;

      return _TooltipPos(
        left: sidePadding,
        right: sidePadding,
        bottom: bottomPos.clamp(safeAreaBottom, screenSize.height - safeAreaTop - 200),
        arrowPointsUp: false,
      );
    }
  }
}

class _TooltipPos {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final bool arrowPointsUp;

  _TooltipPos({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.arrowPointsUp,
  });
}
