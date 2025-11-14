/// Common State Widgets
///
/// Reusable widgets for loading, error, and empty states
/// Provides consistent UX across the app
library;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Loading state widget
class LoadingState extends StatelessWidget {
  final String? message;
  final double? size;

  const LoadingState({
    super.key,
    this.message,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state widget
class ErrorState extends StatelessWidget {
  final String? title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon = Icons.error_outline,
  });

  /// Factory for network errors
  factory ErrorState.network({
    VoidCallback? onRetry,
  }) {
    return ErrorState(
      title: 'Connection Problem',
      message: 'Unable to connect. Please check your internet connection.',
      actionText: 'Retry',
      onAction: onRetry,
      icon: Icons.wifi_off,
    );
  }

  /// Factory for timeout errors
  factory ErrorState.timeout({
    VoidCallback? onRetry,
  }) {
    return ErrorState(
      title: 'Request Timeout',
      message: 'The request took too long. Please try again.',
      actionText: 'Retry',
      onAction: onRetry,
      icon: Icons.access_time,
    );
  }

  /// Factory for permission errors
  factory ErrorState.permission({
    String? message,
  }) {
    return ErrorState(
      title: 'Access Denied',
      message: message ?? "You don't have permission to access this.",
      icon: Icons.lock_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 24),
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final String? title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData icon;

  const EmptyState({
    super.key,
    this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  /// Factory for empty list
  factory EmptyState.noItems({
    required String itemName,
    VoidCallback? onCreate,
  }) {
    return EmptyState(
      title: 'No $itemName Yet',
      message: 'Get started by creating your first $itemName.',
      actionText: 'Create $itemName',
      onAction: onCreate,
      icon: Icons.add_circle_outline,
    );
  }

  /// Factory for no search results
  factory EmptyState.noResults({
    String? query,
  }) {
    return EmptyState(
      title: 'No Results Found',
      message: query != null
          ? 'No results for "$query". Try a different search.'
          : 'No results found. Try adjusting your filters.',
      icon: Icons.search_off,
    );
  }

  /// Factory for no analytics
  factory EmptyState.noAnalytics() {
    return const EmptyState(
      title: 'No Analytics Yet',
      message: 'Share your profile to start tracking views and interactions.',
      icon: Icons.insights_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Async data builder with loading/error/empty states
class AsyncDataBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool Function(T data)? isEmpty;

  const AsyncDataBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              const LoadingState(message: 'Loading...');
        }

        // Error
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ??
              ErrorState(
                message: 'Something went wrong. Please try again.',
              );
        }

        // No data
        if (!snapshot.hasData) {
          return emptyBuilder?.call(context) ??
              const EmptyState(
                message: 'No data available',
              );
        }

        final data = snapshot.data!;

        // Check if empty
        if (isEmpty?.call(data) ?? false) {
          return emptyBuilder?.call(context) ??
              const EmptyState(
                message: 'No data available',
              );
        }

        // Success - build with data
        return builder(context, data);
      },
    );
  }
}

/// Inline loading indicator (for buttons, etc.)
class InlineLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const InlineLoading({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
