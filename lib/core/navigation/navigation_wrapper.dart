import 'package:flutter/material.dart';
import 'glass_bottom_nav.dart';

class NavigationWrapper extends StatelessWidget {
  final Widget child;

  const NavigationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: const GlassBottomNav(),
    );
  }
}

class NavigationGuard extends StatelessWidget {
  final Widget child;
  final bool requiresAuth;

  const NavigationGuard({
    super.key,
    required this.child,
    this.requiresAuth = false,
  });

  @override
  Widget build(BuildContext context) {
    // Add authentication checks here if needed
    if (requiresAuth) {
      // Check authentication state
      // For now, just return the child
    }

    return child;
  }
}