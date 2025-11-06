import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../services/tutorial_service.dart';
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
  }

  void _closeTutorial() async {
    developer.log('❌ Closing tutorial', name: 'TutorialOverlay');
    setState(() {
      _showingTutorial = false;
    });
    widget.onTutorialComplete?.call();
  }

  void _nextStep() async {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      await TutorialService.saveCurrentStep(_currentStepIndex);
      developer.log('➡️  Step $_currentStepIndex', name: 'TutorialOverlay');
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
    return Stack(
      children: [
        widget.child,
        if (_showingTutorial) _buildTutorialOverlay(),
      ],
    );
  }

  Widget _buildTutorialOverlay() {
    final currentStep = _steps[_currentStepIndex];

    return Material(
      type: MaterialType.transparency,
      child: TutorialSpotlight(
        child: _buildTooltipPositioned(currentStep),
      ),
    );
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

    // Target center for pulsing indicator
    final targetCenter = Offset(
      targetPosition.dx + targetSize.width / 2,
      targetPosition.dy + targetSize.height / 2,
    );

    // Get positioning based on step ID
    final pos = _getPositioning(step.id, targetPosition, targetSize, screenSize);

    // Use Stack with explicit z-index ordering via order of children
    // Later children in Stack render on top, ensuring tutorial content is above nav bars
    return Stack(
      children: [
        // Tooltip positioned first (renders below indicator)
        Positioned(
          left: pos.left,
          right: pos.right,
          top: pos.top,
          bottom: pos.bottom,
          child: TutorialTooltip(
            step: step,
            onDismiss: _nextStep,
            arrowPointsUp: pos.arrowPointsUp,
          ),
        ),

        // Pulsing indicator on top (renders above everything including nav bars)
        Positioned(
          left: targetCenter.dx - 10, // Center the 20px indicator
          top: targetCenter.dy - 10,
          child: PulsingIndicator(position: targetCenter),
        ),
      ],
    );
  }

  _TooltipPos _getPositioning(String stepId, Offset targetPos, Size targetSize, Size screenSize) {
    const sidePadding = 20.0;

    switch (stepId) {
      case 'nfc_fab':
        // FAB in center - tooltip ABOVE with proper spacing (40px to clear FAB)
        return _TooltipPos(
          left: sidePadding,
          right: sidePadding,
          bottom: screenSize.height - targetPos.dy + 40,
          arrowPointsUp: false, // Arrow points DOWN to target
        );

      case 'mode_switch':
        // Text above FAB - position tooltip at TOP of screen to avoid blocking UI
        return _TooltipPos(
          left: sidePadding,
          right: sidePadding,
          top: 80, // Position at top of screen with safe area padding
          arrowPointsUp: false, // Arrow points DOWN to target
        );

      case 'share_options':
        // Button below FAB - tooltip BELOW it
        return _TooltipPos(
          left: sidePadding,
          right: sidePadding,
          top: targetPos.dy + targetSize.height + 16,
          arrowPointsUp: true, // Arrow points UP to target
        );

      case 'profile_tab':
        // Bottom nav - tooltip well ABOVE with proper spacing (80px)
        return _TooltipPos(
          left: sidePadding,
          right: sidePadding,
          bottom: screenSize.height - targetPos.dy + 80,
          arrowPointsUp: false, // Arrow points DOWN to target
        );

      default:
        return _TooltipPos(
          left: sidePadding,
          right: sidePadding,
          top: targetPos.dy + targetSize.height + 16,
          arrowPointsUp: true,
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
