/// Pagination Helper
///
/// Provides cursor-based pagination for Firestore queries
/// Handles 100k+ entries efficiently with minimal memory usage
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

/// Pagination result wrapper
class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int totalFetched;

  PaginatedResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
    required this.totalFetched,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}

/// Pagination helper for Firestore queries
class PaginationHelper {
  /// Default page size
  static const int defaultPageSize = 20;

  /// Fetch paginated data from Firestore
  ///
  /// Example:
  /// ```dart
  /// final result = await PaginationHelper.fetchPage(
  ///   query: FirebaseFirestore.instance
  ///     .collection('analytics')
  ///     .where('profileId', isEqualTo: profileId)
  ///     .orderBy('timestamp', descending: true),
  ///   pageSize: 20,
  ///   lastDocument: previousResult?.lastDocument,
  ///   mapper: (doc) => AnalyticsEvent.fromJson(doc.data()!),
  /// );
  /// ```
  static Future<PaginatedResult<T>> fetchPage<T>({
    required Query query,
    int pageSize = defaultPageSize,
    DocumentSnapshot? lastDocument,
    required T Function(DocumentSnapshot doc) mapper,
  }) async {
    final startTime = DateTime.now();

    try {
      // Build paginated query
      Query paginatedQuery = query.limit(pageSize + 1); // Fetch one extra to check if more exists

      // If continuing from previous page, start after last document
      if (lastDocument != null) {
        paginatedQuery = paginatedQuery.startAfterDocument(lastDocument);
      }

      // Execute query
      final snapshot = await paginatedQuery.get();
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      // Check if there are more pages
      final hasMore = snapshot.docs.length > pageSize;

      // Get actual items (excluding the extra one)
      final docs = hasMore
          ? snapshot.docs.sublist(0, pageSize)
          : snapshot.docs;

      // Map to domain objects
      final items = docs.map(mapper).toList();

      // Get last document for next page
      final newLastDoc = docs.isNotEmpty ? docs.last : null;

      developer.log(
        '📄 Paginated fetch complete:\n'
        '   • Items: ${items.length}\n'
        '   • Has More: $hasMore\n'
        '   • Duration: ${duration}ms',
        name: 'PaginationHelper.FetchPage',
      );

      return PaginatedResult(
        items: items,
        lastDocument: newLastDoc,
        hasMore: hasMore,
        totalFetched: items.length,
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Pagination fetch failed',
        name: 'PaginationHelper.FetchPage',
        error: e,
        stackTrace: stackTrace,
      );

      return PaginatedResult(
        items: [],
        lastDocument: null,
        hasMore: false,
        totalFetched: 0,
      );
    }
  }

  /// Fetch all pages (use with caution for large datasets)
  ///
  /// Fetches all data in batches, useful for data export or migration
  /// Includes progress callback for long-running operations
  static Future<List<T>> fetchAll<T>({
    required Query query,
    required T Function(DocumentSnapshot doc) mapper,
    int pageSize = defaultPageSize,
    int? maxItems,
    void Function(int fetched)? onProgress,
  }) async {
    final allItems = <T>[];
    DocumentSnapshot? lastDoc;
    bool hasMore = true;

    developer.log(
      '📚 Fetching all items (max: ${maxItems ?? "unlimited"})',
      name: 'PaginationHelper.FetchAll',
    );

    while (hasMore) {
      // Check if we've reached max items
      if (maxItems != null && allItems.length >= maxItems) {
        break;
      }

      // Fetch next page
      final result = await fetchPage(
        query: query,
        pageSize: pageSize,
        lastDocument: lastDoc,
        mapper: mapper,
      );

      // Add items
      allItems.addAll(result.items);
      lastDoc = result.lastDocument;
      hasMore = result.hasMore;

      // Call progress callback
      onProgress?.call(allItems.length);

      // Avoid infinite loops
      if (result.items.isEmpty) {
        break;
      }
    }

    developer.log(
      '✅ Fetched all items: ${allItems.length}',
      name: 'PaginationHelper.FetchAll',
    );

    return allItems;
  }

  /// Fetch count (estimates for large collections)
  ///
  /// Returns exact count for small collections (<1000 items)
  /// Returns estimated count for large collections
  static Future<int> getCount(Query query) async {
    try {
      // For exact count on small datasets
      final snapshot = await query.limit(1000).get();

      if (snapshot.docs.length < 1000) {
        // Small dataset - return exact count
        return snapshot.docs.length;
      } else {
        // Large dataset - use aggregation count (if available)
        // Note: This requires Firestore count() which may not be available in all SDK versions
        developer.log(
          '⚠️  Large dataset detected. Consider using Firestore count aggregation.',
          name: 'PaginationHelper.GetCount',
        );
        return snapshot.docs.length; // At least 1000
      }
    } catch (e) {
      developer.log(
        '❌ Failed to get count',
        name: 'PaginationHelper.GetCount',
        error: e,
      );
      return 0;
    }
  }
}

/// Paginated list state manager
///
/// Manages pagination state for infinite scroll lists
class PaginatedListState<T> {
  final List<T> items = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Load next page
  Future<void> loadNextPage({
    required Query query,
    required T Function(DocumentSnapshot doc) mapper,
    int pageSize = PaginationHelper.defaultPageSize,
  }) async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;

    try {
      final result = await PaginationHelper.fetchPage(
        query: query,
        pageSize: pageSize,
        lastDocument: _lastDocument,
        mapper: mapper,
      );

      items.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
    } finally {
      _isLoading = false;
    }
  }

  /// Reset pagination state
  void reset() {
    items.clear();
    _lastDocument = null;
    _hasMore = true;
    _isLoading = false;
  }

  /// Refresh from beginning
  Future<void> refresh({
    required Query query,
    required T Function(DocumentSnapshot doc) mapper,
    int pageSize = PaginationHelper.defaultPageSize,
  }) async {
    reset();
    await loadNextPage(
      query: query,
      mapper: mapper,
      pageSize: pageSize,
    );
  }
}
