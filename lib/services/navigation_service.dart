import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../models/unified_models.dart';
import '../screens/contact_detail_screen.dart';

/// Global navigation service for handling navigation from anywhere in the app
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Get the current navigator state
  static NavigatorState? get navigator => navigatorKey.currentState;

  /// Get the current context
  static BuildContext? get context => navigatorKey.currentContext;

  /// Navigate to a new route
  static Future<T?> push<T extends Object?>(Route<T> route) {
    return navigator!.push(route);
  }

  /// Navigate to a new route by name
  static Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return navigator!.pushNamed(routeName, arguments: arguments);
  }

  /// Replace current route
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    Route<T> newRoute, {
    TO? result,
  }) {
    return navigator!.pushReplacement(newRoute, result: result);
  }

  /// Replace current route by name
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return navigator!.pushReplacementNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  /// Pop current route
  static void pop<T extends Object?>([T? result]) {
    return navigator!.pop(result);
  }

  /// Pop until a specific route
  static void popUntil(RoutePredicate predicate) {
    return navigator!.popUntil(predicate);
  }

  /// Navigate to contact detail screen
  static Future<void> navigateToContactDetail(ReceivedContact receivedContact) async {
    print('🧭 Navigate to contact detail: ${receivedContact.contact.name}');

    if (navigator != null) {
      await navigator!.push(
        MaterialPageRoute(
          builder: (context) => ContactDetailScreen(receivedContact: receivedContact),
        ),
      );
    }
  }

  /// Navigate to received cards list screen
  static Future<void> navigateToReceivedCards() async {
    print('🧭 Navigate to received cards list');

    // TODO: Implement actual navigation
    // if (navigator != null) {
    //   await navigator!.pushNamed('/received-cards');
    // }
  }

  /// Navigate to home screen
  static Future<void> navigateToHome() async {
    print('🧭 Navigate to home');

    // TODO: Implement actual navigation
    // if (navigator != null) {
    //   await navigator!.pushNamedAndRemoveUntil(
    //     '/home',
    //     (route) => false,
    //   );
    // }
  }

  /// Show dialog from anywhere in the app
  static Future<T?> showAppDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final currentContext = context;
    if (currentContext == null) return Future.value(null);

    return showDialog<T>(
      context: currentContext,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show snackbar from anywhere in the app
  static void showSnackBar(String message) {
    final currentContext = context;
    if (currentContext == null) return;

    final messenger = ScaffoldMessenger.of(currentContext);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success message
  static void showSuccess(String message) {
    final currentContext = context;
    if (currentContext == null) return;

    final messenger = ScaffoldMessenger.of(currentContext);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error message
  static void showError(String message) {
    final currentContext = context;
    if (currentContext == null) return;

    final messenger = ScaffoldMessenger.of(currentContext);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}